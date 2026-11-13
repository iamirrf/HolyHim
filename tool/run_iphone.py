#!/usr/bin/env python3
"""Build and run HolyHim on the paired physical iPhone over localNetwork only.

Uses devicectl's versioned JSON interface, never its human-readable stdout.
Raw device responses live only in an automatically removed temporary directory.
No uninstall, device reset, DDI modification, Simulator or deployment action is
part of this helper. Run --help or the mocked tests without touching a device.
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
from typing import Callable

ROOT = Path(__file__).resolve().parents[1]
BUNDLE_ID = "com.holyhim.app"
DEFAULT_HOST = "Amirs-iPhone.coredevice.local"
GIB = 1024 ** 3


@dataclass(frozen=True)
class AppVersion:
    name: str
    build: str


class RunFailure(Exception):
    """An actionable error containing only information safe for a run report."""

    def __init__(self, reason: str, *, codes: list[int] | None = None,
                 domains: list[str] | None = None):
        super().__init__(reason)
        self.reason = reason
        self.codes = codes or []
        self.domains = domains or []


def current_version(root: Path) -> AppVersion:
    text = (root / "pubspec.yaml").read_text(encoding="utf-8")
    match = re.search(
        r"^version:\s*['\"]?(\d+\.\d+\.\d+)\+(\d+)['\"]?\s*(?:#.*)?$",
        text, re.MULTILINE)
    if not match:
        raise RunFailure("pubspec.yaml must declare an iOS version and build, such as 2.0.0+5.")
    return AppVersion(match.group(1), str(int(match.group(2))))


def validate_app(app: Path, version: AppVersion) -> None:
    try:
        with (app / "Info.plist").open("rb") as stream:
            info = plistlib.load(stream)
    except (OSError, ValueError, plistlib.InvalidFileException):
        raise RunFailure("The physical-device .app is missing or has an unreadable Info.plist. Build it first.") from None
    if info.get("CFBundleIdentifier") != BUNDLE_ID or info.get("CFBundlePackageType") != "APPL":
        raise RunFailure("The supplied .app is not the production HolyHim application.")
    actual = (str(info.get("CFBundleShortVersionString", "")), str(info.get("CFBundleVersion", "")))
    if actual != (version.name, version.build):
        raise RunFailure(
            f"Cached app version {actual[0] or '?'} ({actual[1] or '?'}) does not match "
            f"pubspec {version.name} ({version.build}). Rebuild without --skip-build.")
    platforms = info.get("CFBundleSupportedPlatforms", [])
    if not isinstance(platforms, list) or "iPhoneOS" not in platforms or "iPhoneSimulator" in platforms:
        raise RunFailure("The .app must be built for the physical iPhone (iPhoneOS).")
    executable = info.get("CFBundleExecutable")
    if not isinstance(executable, str) or Path(executable).name != executable or not (app / executable).is_file():
        raise RunFailure("The physical-device .app has no valid executable.")
    if (app / "Frameworks/App.framework/flutter_assets/kernel_blob.bin").exists():
        raise RunFailure("The cached app is a debug build. Rebuild in profile mode for a direct physical-device launch.")


def validate_chapter_assets(app: Path, root: Path) -> int:
    """Reject a signed build if a chapter image is absent or differs from the source manifest."""
    try:
        manifest = json.loads((root / "art/chapter-manifest.json").read_text())
        chapters = manifest["chapters"]
    except (OSError, ValueError, KeyError, TypeError):
        raise RunFailure("The chapter manifest is unavailable or invalid; the iPhone build cannot be verified.") from None
    if len(chapters) != 73 or manifest.get("packagedAssets") != 292:
        raise RunFailure("The chapter manifest is incomplete; all 292 assets are required for this build.")
    bundle = app / "Frameworks/App.framework/flutter_assets"
    count = 0
    for chapter in chapters:
        assets = chapter.get("assets")
        if not isinstance(assets, dict) or len(assets) != 4:
            raise RunFailure("The chapter manifest has an incomplete image set.")
        for asset in assets.values():
            relative = asset.get("path")
            if not isinstance(relative, str) or not relative.startswith("assets/art/chapters/"):
                raise RunFailure("The chapter manifest has an invalid bundle path.")
            path = bundle / relative
            if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != asset.get("sha256"):
                raise RunFailure("The signed iPhone app is missing or has changed chapter artwork. Rebuild before installation.")
            count += 1
    return count


def error_metadata(value: object) -> tuple[list[int], list[str]]:
    """Retain codes/domains, never raw descriptions, IDs, serials or audit data."""
    codes: list[int] = []
    domains: list[str] = []

    def visit(node: object, depth: int = 0) -> None:
        if depth > 20:
            return
        if isinstance(node, dict):
            code = node.get("code")
            domain = node.get("domain")
            if type(code) is int and code not in codes:
                codes.append(code)
            if isinstance(domain, str) and re.fullmatch(r"[A-Za-z0-9._-]{1,128}", domain) and domain not in domains:
                domains.append(domain)
            for child in node.values():
                if isinstance(child, (dict, list)):
                    visit(child, depth + 1)
        elif isinstance(node, list):
            for child in node:
                visit(child, depth + 1)

    visit(value)
    return codes, domains


def command_failure(stage: str, payload: object | None = None) -> RunFailure:
    codes, domains = error_metadata(payload)
    if any(code in (12040, 12010) for code in codes):
        reason = ("The iPhone's developer services could not start (Developer Disk Image). "
                  "Keep the phone unlocked and resolve the device prompt or Xcode/device OS compatibility. "
                  "No device reset or DDI change was attempted.")
    else:
        suffix = f" Error codes: {', '.join(map(str, codes))}." if codes else ""
        reason = f"devicectl {stage} failed.{suffix} Keep the iPhone unlocked and check its device-side prompts."
    return RunFailure(reason, codes=codes, domains=domains)


class IPhoneRunner:
    def __init__(self, root: Path = ROOT, *,
                 run: Callable[..., subprocess.CompletedProcess] = subprocess.run,
                 disk_usage: Callable = shutil.disk_usage,
                 progress: Callable[[str], None] = print):
        self.root = root.resolve()
        self.run = run
        self.disk_usage = disk_usage
        self.progress = progress
        self.identifier: str | None = None
        self.report: dict = {
            "attemptedAt": datetime.now(timezone.utc).isoformat(),
            "status": "failed", "bundleId": BUNDLE_ID,
            "built": False, "installed": False, "processStarted": False,
            "verifiedWirelessLaunch": False,
        }

    def _command(self, arguments: list[str], timeout: float) -> subprocess.CompletedProcess:
        try:
            return self.run(arguments, cwd=self.root, capture_output=True,
                            text=True, timeout=timeout, check=False)
        except subprocess.TimeoutExpired:
            raise RunFailure("The command timed out. Check the unlocked iPhone and its wireless connection before retrying.") from None
        except OSError:
            raise RunFailure("A required local tool could not start. Check the installed Xcode and Flutter command-line tools.") from None

    def _device(self, arguments: list[str], timeout: int) -> dict:
        with tempfile.TemporaryDirectory(prefix="holyhim-iphone-") as folder:
            output = Path(folder) / "result.json"
            command = ["xcrun", "devicectl", "--quiet", "--timeout", str(timeout),
                       "--json-output", str(output), *arguments]
            result = self._command(command, timeout + 10)
            try:
                if output.stat().st_size > 1024 ** 2:
                    raise ValueError("Unexpected device response size")
                payload = json.loads(output.read_text(encoding="utf-8"))
            except (OSError, ValueError):
                raise RunFailure("devicectl did not return supported JSON. No device operation is being assumed successful.") from None
            if not isinstance(payload, dict):
                raise RunFailure("devicectl returned an unsupported JSON result.")
            if result.returncode or payload.get("error") or payload.get("info", {}).get("outcome") != "success":
                raise command_failure(self.report.get("stage", "command"), payload.get("error"))
            value = payload.get("result")
            if not isinstance(value, dict):
                raise RunFailure("devicectl returned no supported command result.")
            return value

    def wireless(self, selector: str, timeout: int) -> str:
        inventory = self._device(["list", "devices"], timeout)
        devices = inventory.get("devices")
        if not isinstance(devices, list):
            raise RunFailure("devicectl did not return a device inventory. The wireless destination cannot be verified.")
        matches = [device for device in devices
                   if isinstance(device, dict)
                   and isinstance(device.get("connectionProperties"), dict)
                   and (device.get("identifier") == selector
                        or selector in device["connectionProperties"].get("localHostnames", [])
                        or selector in device["connectionProperties"].get("potentialHostnames", []))]
        if len(matches) != 1:
            raise RunFailure("The selected iPhone was not uniquely identified in the devicectl inventory.")
        details = matches[0]
        connection = details.get("connectionProperties", {})
        hardware = details.get("hardwareProperties", {})
        properties = details.get("deviceProperties", {})
        if not all(isinstance(item, dict) for item in (connection, hardware, properties)):
            raise RunFailure("The device's transport and hardware could not be verified.")
        transport = connection.get("transportType")
        if transport in ("localNetwork", "wired", "usb", "USB"):
            self.report["transport"] = transport
        if transport != "localNetwork":
            raise RunFailure("Wireless-only rule: devicectl must report transportType localNetwork. USB and unknown transports are refused.")
        if connection.get("tunnelState") != "connected":
            raise RunFailure("The iPhone's wireless tunnel is not connected. Keep it unlocked and available on the local network.")
        if (str(hardware.get("platform", "")).casefold() != "ios"
                or str(hardware.get("deviceType", "")).casefold() != "iphone"
                or hardware.get("reality") != "physical"):
            raise RunFailure("The selected destination is not a verified physical iPhone.")
        if connection.get("pairingState") != "paired":
            raise RunFailure("The iPhone is not paired with this Mac. Resolve the pairing prompt on the phone.")
        if properties.get("developerModeStatus") != "enabled":
            raise RunFailure("Developer Mode is not enabled on the iPhone. Resolve the device-side setting before retrying.")
        identifier = details.get("identifier")
        if not isinstance(identifier, str) or not identifier:
            raise RunFailure("devicectl did not identify the physical iPhone.")
        if self.identifier is not None and identifier != self.identifier:
            raise RunFailure("The selected device changed during the run. No fallback destination will be used.")
        self.identifier = identifier
        return identifier

    def _same_device(self, result: dict) -> None:
        if result.get("deviceIdentifier") != self.identifier:
            raise RunFailure("The command result did not match the verified physical iPhone.")

    def execute(self, *, device: str = DEFAULT_HOST, app: Path | None = None,
                skip_build: bool = False, mode: str = "profile", timeout: int = 60,
                min_free_gb: float = 6) -> dict:
        self.report["stage"] = "preflight"
        version = current_version(self.root)
        self.report.update(version=version.name, build=version.build, mode=mode)
        app = (app or self.root / "build/ios/iphoneos/Runner.app").resolve()
        if skip_build:
            validate_app(app, version)  # Reject a stale cache before touching a device.
            self.report["chapterAssetsVerified"] = validate_chapter_assets(app, self.root)
        identifier = self.wireless(device, timeout)
        self.report["stage"] = "unlock check"
        lock = self._device(["device", "info", "lockState", "--device", identifier], timeout)
        self._same_device(lock)
        if lock.get("passcodeRequired") is True or lock.get("unlockedSinceBoot") is False:
            raise RunFailure("Unlock the iPhone with its passcode after restarting, then retry wirelessly.")
        if not skip_build:
            self.report["stage"] = "build"
            if self.disk_usage(self.root).free < min_free_gb * GIB:
                raise RunFailure(f"At least {min_free_gb:g} GiB of free space is required before this physical-device build. No cache or user data was deleted.")
            self.progress(f"Building HolyHim {version.name} ({version.build}) for the physical iPhone ({mode})…")
            build = self._command(["flutter", "build", "ios", f"--{mode}",
                                   "--target", "lib/main.dart", "--build-name", version.name,
                                   "--build-number", version.build], 3600)
            if build.returncode:
                raise RunFailure("The physical-device Flutter build failed. No app was installed or launched; resolve the local build/signing error before retrying.")
            self.report["built"] = True
        self.report["stage"] = "app validation"
        validate_app(app, version)
        self.report["chapterAssetsVerified"] = validate_chapter_assets(app, self.root)
        signature = self._command(["codesign", "--verify", "--deep", "--strict", str(app)], 60)
        if signature.returncode:
            raise RunFailure("The app's local code signature could not be verified. Rebuild with the existing development signing configuration.")
        self.report["stage"] = "install transport check"
        self.wireless(identifier, timeout)
        self.report["stage"] = "install"
        self.progress("Installing the current HolyHim app wirelessly, preserving its existing app data…")
        installed = self._device(["device", "install", "app", "--device", identifier, str(app)], timeout)
        self._same_device(installed)
        applications = installed.get("installedApplications", [])
        if not isinstance(applications, list) or not any(isinstance(row, dict) and row.get("bundleID") == BUNDLE_ID for row in applications):
            raise RunFailure("devicectl did not confirm installation of the HolyHim bundle.")
        self.report["installed"] = True
        self.report["stage"] = "launch transport check"
        self.wireless(identifier, timeout)
        self.report["stage"] = "launch"
        launched = self._device(["device", "process", "launch", "--device", identifier,
                                 "--activate", BUNDLE_ID], timeout)
        self._same_device(launched)
        pid = launched.get("process", {}).get("processIdentifier")
        if type(pid) is not int or pid <= 0 or launched.get("launchOptions", {}).get("startStopped") is True:
            raise RunFailure("devicectl did not confirm a running HolyHim process. The app is not being reported as launched.")
        self.report["processStarted"] = True
        self.report["processIdentifier"] = pid
        self.report["stage"] = "post-launch transport check"
        self.wireless(identifier, timeout)
        self.report.update(status="launched", verifiedWirelessLaunch=True, stage="complete")
        return self.report


def parser() -> argparse.ArgumentParser:
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument("--device", default=os.environ.get("HOLYHIM_IPHONE_HOST", DEFAULT_HOST),
                     help="Known paired iPhone hostname/name/identifier; transport and physical identity are verified.")
    cli.add_argument("--skip-build", action="store_true", help="Use a current-version signed physical .app; stale builds are rejected.")
    cli.add_argument("--app", type=Path, help="Existing .app path; valid only with --skip-build.")
    cli.add_argument("--mode", choices=("profile", "release"), default="profile")
    cli.add_argument("--timeout", type=int, default=60, help="Each devicectl command's time limit in seconds (default: 60).")
    cli.add_argument("--min-free-gb", type=float, default=6, help="Free space required before building (default: 6 GiB).")
    cli.add_argument("--report", type=Path, default=ROOT / "store/iphone-run.json", help="Minimal result JSON; raw device records are not retained.")
    return cli


def main(argv: list[str] | None = None) -> int:
    cli = parser()
    args = cli.parse_args(argv)
    if args.app is not None and not args.skip_build:
        cli.error("--app requires --skip-build; a normal run always builds the current project.")
    if args.timeout < 1 or not math.isfinite(args.min_free_gb) or args.min_free_gb < 0:
        cli.error("--timeout must be positive and --min-free-gb must be finite and nonnegative.")
    runner = IPhoneRunner()
    try:
        report = runner.execute(device=args.device, app=args.app, skip_build=args.skip_build,
                                mode=args.mode, timeout=args.timeout, min_free_gb=args.min_free_gb)
    except RunFailure as error:
        report = runner.report
        report["failure"] = {"reason": error.reason}
        if error.codes:
            report["failure"]["codes"] = error.codes
        if error.domains:
            report["failure"]["domains"] = error.domains
        print(error.reason, file=sys.stderr)
        exit_code = 1
    else:
        print(f"HolyHim {report['version']} ({report['build']}) launched wirelessly on the iPhone (PID {report['processIdentifier']}).")
        exit_code = 0
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
