#!/usr/bin/env python3
"""Import a HolyHer-only Apple Sign In key without creating a local key copy.

The owner creates the Sign in with Apple key and Services ID in Apple's portal.
This script uses the documented GCP Secret Manager and Identity Platform APIs;
it never attempts an undocumented Apple key-creation request.

https://cloud.google.com/identity-platform/docs/reference/rest/v2/projects.defaultSupportedIdpConfigs
https://cloud.google.com/identity-platform/docs/reference/rest/v2/projects.defaultSupportedIdpConfigs/patch
https://cloud.google.com/sdk/gcloud/reference/secrets/versions/add
"""

from __future__ import annotations

import argparse
import base64
import hmac
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import stat
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request


ROOT = Path(__file__).resolve().parents[1]
PROJECT = "holyher-app-production"
ACCOUNT = "iamirrf1@gmail.com"
TEAM_ID = "DU9D6TAM58"
BUNDLE_ID = "com.holyher.app"
DEFAULT_SERVICE_ID = "com.holyher.app.signin"
IDP_NAME = f"projects/{PROJECT}/defaultSupportedIdpConfigs/apple.com"
IDP_URL = f"https://identitytoolkit.googleapis.com/admin/v2/{IDP_NAME}"
SECRET_BASE = f"https://secretmanager.googleapis.com/v1/projects/{PROJECT}/secrets"


class SetupError(Exception):
    """An intentionally non-sensitive error suitable for Terminal output."""


class ApiError(SetupError):
    def __init__(self, operation: str, status: int):
        self.status = status
        super().__init__(f"{operation} returned HTTP {status}. No response body or secret was logged.")


def cloud_config() -> dict:
    try:
        config = json.loads((ROOT / "config/cloud.json").read_text())
        ios = plistlib.loads((ROOT / "ios/Runner/GoogleService-Info.plist").read_bytes())
    except (OSError, ValueError, plistlib.InvalidFileException):
        raise SetupError("Could not read the public HolyHer cloud/iOS configuration.") from None
    if config.get("projectId") != PROJECT or config.get("account") != ACCOUNT:
        raise SetupError("Cloud configuration must select holyher-app-production and iamirrf1@gmail.com.")
    if config.get("ownerVerified") is not True:
        raise SetupError("The Google project owner must be verified in config/cloud.json first.")
    if ios.get("PROJECT_ID") != PROJECT or ios.get("BUNDLE_ID") != BUNDLE_ID:
        raise SetupError("The native Firebase configuration does not match HolyHer production.")
    return config


def run_gcloud(arguments: list[str], data: bytes | None = None) -> bytes:
    if shutil.which("gcloud") is None:
        raise SetupError("Install/authenticate the Google Cloud CLI before importing this key.")
    environment = os.environ.copy()
    # Explicitly prevent an inherited HTTP/debug setting from recording payloads.
    environment["CLOUDSDK_CORE_LOG_HTTP"] = "false"
    environment["CLOUDSDK_CORE_VERBOSITY"] = "error"
    environment["CLOUDSDK_CORE_DISABLE_FILE_LOGGING"] = "true"
    command = ["gcloud", *arguments, f"--account={ACCOUNT}", f"--project={PROJECT}",
               "--quiet", "--verbosity=error", "--no-log-http"]
    try:
        result = subprocess.run(command, input=data, capture_output=True,
                                env=environment, timeout=180, check=False)
    except (OSError, subprocess.TimeoutExpired):
        raise SetupError("The Google Cloud CLI did not complete. Check its owner login and network.") from None
    if result.returncode != 0:
        # gcloud diagnostics can include request bodies; never forward them.
        raise SetupError("Google Cloud rejected the operation. Check the selected owner's login, project billing, and Secret Manager permissions; no CLI diagnostics were logged.")
    return result.stdout


class GoogleApi:
    def __init__(self):
        self.token = run_gcloud(["auth", "print-access-token"]).decode().strip()
        if not self.token or any(char.isspace() for char in self.token):
            raise SetupError("Google Cloud did not return a valid owner access token.")

    def request(self, method: str, url: str, operation: str, body: dict | None = None) -> dict:
        request = urllib.request.Request(
            url, method=method,
            data=None if body is None else json.dumps(body).encode(),
            headers={"Authorization": f"Bearer {self.token}",
                     "Content-Type": "application/json", "x-goog-user-project": PROJECT},
        )
        try:
            with urllib.request.urlopen(request, timeout=45) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            # Do not read/print a response that might echo the signing key.
            raise ApiError(operation, error.code) from None
        except (urllib.error.URLError, TimeoutError, ValueError):
            raise SetupError(f"{operation} did not return a valid response. No payload was logged.") from None


def read_key(path: str, key_id: str) -> bytes:
    original = Path(path).expanduser()
    if original.is_symlink():
        raise SetupError("Provide the original downloaded .p8 file, not a symbolic link.")
    resolved = original.resolve()
    if resolved.is_relative_to(ROOT) or resolved.is_relative_to(ROOT.parent / "evolve.ai"):
        raise SetupError("Keep Apple private keys outside both app repositories before importing.")
    if resolved.suffix.lower() != ".p8":
        raise SetupError("Provide Apple's downloaded .p8 signing key.")
    filename_id = re.fullmatch(r"AuthKey_([A-Z0-9]{10})\.p8", resolved.name)
    if filename_id and filename_id.group(1) != key_id:
        raise SetupError("The supplied key ID does not match the downloaded key's filename.")
    try:
        descriptor = os.open(resolved, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
        with os.fdopen(descriptor, "rb") as key_file:
            info = os.fstat(key_file.fileno())
            if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or not 100 <= info.st_size <= 4096:
                raise SetupError("The key must be a small, regular .p8 file owned by the current user.")
            os.fchmod(key_file.fileno(), 0o600)
            key = key_file.read(4097)
    except OSError:
        raise SetupError("The downloaded .p8 file could not be read securely.") from None
    if re.fullmatch(rb"-----BEGIN PRIVATE KEY-----\r?\n[A-Za-z0-9+/=\r\n]+-----END PRIVATE KEY-----\s*", key) is None:
        raise SetupError("The file is not an unencrypted PKCS#8 private key downloaded from Apple.")
    # Validate an EC P-256 key without ever printing its private components.
    try:
        checked = subprocess.run(["/usr/bin/openssl", "pkey", "-pubout", "-outform", "DER"],
                                 input=key, capture_output=True, timeout=15, check=False)
    except (OSError, subprocess.TimeoutExpired):
        raise SetupError("OpenSSL could not validate the signing key.") from None
    p256_public_prefix = bytes.fromhex("3059301306072a8648ce3d020106082a8648ce3d03010703420004")
    if checked.returncode != 0 or len(checked.stdout) != 91 or not checked.stdout.startswith(p256_public_prefix):
        raise SetupError("Apple Sign In requires a valid EC P-256 private key.")
    return key.strip() + b"\n"


def safe_provider(provider: dict) -> dict:
    apple = provider.get("appleSignInConfig", {})
    flow = apple.get("codeFlowConfig", {})
    return {"enabled": provider.get("enabled", False), "serviceId": provider.get("clientId", ""),
            "teamId": flow.get("teamId", ""), "keyId": flow.get("keyId", ""),
            "bundleIds": apple.get("bundleIds", []), "privateKeyPresent": bool(flow.get("privateKey"))}


def check_existing(provider: dict, service_id: str, key_id: str, replace_key: bool) -> None:
    existing = safe_provider(provider)
    if existing["serviceId"] not in ("", BUNDLE_ID, service_id):
        raise SetupError("The Apple provider uses another Services ID; resolve it before this HolyHer-only import.")
    if set(existing["bundleIds"]) - {BUNDLE_ID}:
        raise SetupError("The Apple provider includes other apps. This importer will not change a shared provider.")
    if existing["teamId"] not in ("", TEAM_ID):
        raise SetupError("The Apple provider belongs to another developer team.")
    if existing["keyId"] not in ("", key_id) and not replace_key:
        raise SetupError("Another signing key is already configured. Use --replace-key only for an intentional HolyHer key rotation.")


def backup_key(api: GoogleApi, key: bytes, key_id: str) -> tuple[str, bool]:
    secret_id = f"holyher-apple-sign-in-{key_id.lower()}"
    secret_url = f"{SECRET_BASE}/{secret_id}"
    expected_labels = {"app": "holyher", "purpose": "apple-sign-in", "key-id": key_id.lower(),
                       "team-id": TEAM_ID.lower(), "managed-by": "holyher-setup"}
    run_gcloud(["services", "enable", "secretmanager.googleapis.com"])
    try:
        secret = api.request("GET", secret_url, "Read the scoped secret metadata")
    except ApiError as error:
        if error.status != 404:
            raise
        secret = api.request("POST", SECRET_BASE + "?" + urllib.parse.urlencode({"secretId": secret_id}),
                             "Create the scoped signing-key backup",
                             {"replication": {"automatic": {}}, "labels": expected_labels})
    if any(secret.get("labels", {}).get(name) != value for name, value in expected_labels.items()):
        raise SetupError("A secret with this name exists without the expected HolyHer ownership labels.")
    try:
        latest = api.request("GET", secret_url + "/versions/latest:access", "Verify the existing key backup")
        stored = base64.b64decode(latest["payload"]["data"], validate=True)
        if hmac.compare_digest(stored, key):
            return latest["name"], False
        raise SetupError("A different private key is already backed up under this immutable Apple key ID. Check the downloaded file/key ID; the backup and Firebase were not changed.")
    except ApiError as error:
        if error.status != 404:
            raise
    except (KeyError, ValueError):
        raise SetupError("Secret Manager returned an invalid backup payload; nothing was sent to Firebase.") from None
    # Official --data-file=- reads the key from stdin, never argv or a temp file.
    raw_name = run_gcloud(["secrets", "versions", "add", secret_id, "--data-file=-", "--format=value(name)"], key)
    version_name = raw_name.decode().strip()
    match = re.fullmatch(r"projects/([a-z0-9-]+)/secrets/" + re.escape(secret_id) + r"/versions/([0-9]+)", version_name)
    if not match:
        raise SetupError("Secret Manager did not confirm a scoped secret version; Firebase was not changed.")
    version_url = f"{secret_url}/versions/{match.group(2)}:access"
    saved = api.request("GET", version_url, "Verify the new key backup")
    try:
        verified = hmac.compare_digest(base64.b64decode(saved["payload"]["data"], validate=True), key)
    except (KeyError, ValueError):
        verified = False
    if not verified:
        raise SetupError("The signing-key backup did not match; Firebase was not changed.")
    return version_name, True


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--p8", help="Owner-downloaded HolyHer-only Sign in with Apple key outside the repo")
    parser.add_argument("--key-id", help="Ten-character Apple key ID")
    parser.add_argument("--service-id", default=DEFAULT_SERVICE_ID, help=f"Configured Apple Services ID (default {DEFAULT_SERVICE_ID})")
    parser.add_argument("--replace-key", action="store_true", help="Allow an intentional rotation of an existing HolyHer signing key")
    parser.add_argument("--dry-run", action="store_true", help="Validate the local key/configuration and show the public plan; no network or upload")
    parser.add_argument("--verify", action="store_true", help="Read the provider's non-secret setup status; no key import")
    parser.add_argument("--check", action="store_true", help="Check public local project configuration only")
    args = parser.parse_args(argv)
    cloud_config()
    if args.service_id == BUNDLE_ID or re.fullmatch(r"com\.holyher\.[A-Za-z0-9.-]+", args.service_id) is None:
        raise SetupError("Use the separately registered HolyHer Services ID, not the native bundle ID.")
    plan = {"projectId": PROJECT, "account": ACCOUNT, "teamId": TEAM_ID, "serviceId": args.service_id,
            "bundleIds": [BUNDLE_ID], "returnUrl": f"https://{PROJECT}.firebaseapp.com/__/auth/handler"}
    if args.check:
        print(json.dumps({**plan, "configurationMatches": True, "gcloudAvailable": shutil.which("gcloud") is not None}, indent=2))
        return 0
    if args.verify:
        if args.p8 or args.key_id or args.dry_run or args.replace_key:
            parser.error("--verify cannot be combined with key-import options")
        provider = GoogleApi().request("GET", IDP_URL, "Read the Apple provider")
        print(json.dumps({"projectId": PROJECT, **safe_provider(provider)}, indent=2))
        return 0
    if not args.p8 or not args.key_id or re.fullmatch(r"[A-Z0-9]{10}", args.key_id) is None:
        parser.error("Import requires --p8 PATH and a ten-character --key-id KEYID")
    key = read_key(args.p8, args.key_id)
    if args.dry_run:
        print(json.dumps({**plan, "keyId": args.key_id, "keyValid": True, "uploaded": False,
                          "secretId": f"holyher-apple-sign-in-{args.key_id.lower()}"}, indent=2))
        return 0
    api = GoogleApi()
    provider = api.request("GET", IDP_URL, "Read the existing Apple provider")
    check_existing(provider, args.service_id, args.key_id, args.replace_key)
    secret_name, created = backup_key(api, key, args.key_id)
    body = {"name": IDP_NAME, "enabled": True, "clientId": args.service_id,
            "appleSignInConfig": {"codeFlowConfig": {"teamId": TEAM_ID, "keyId": args.key_id,
                                                     "privateKey": key.decode("ascii")},
                                  "bundleIds": [BUNDLE_ID]}}
    patch_url = IDP_URL + "?" + urllib.parse.urlencode({"updateMask": "enabled,clientId,appleSignInConfig"})
    api.request("PATCH", patch_url, "Configure the Apple provider's code flow", body)
    readback = api.request("GET", IDP_URL, "Read back the Apple provider configuration")
    status = safe_provider(readback)
    if not (status["enabled"] is True and status["serviceId"] == args.service_id and status["teamId"] == TEAM_ID
            and status["keyId"] == args.key_id and status["bundleIds"] == [BUNDLE_ID]):
        raise SetupError("Firebase's non-secret configuration read-back did not match. The scoped Secret Manager backup is retained.")
    returned_key = readback.get("appleSignInConfig", {}).get("codeFlowConfig", {}).get("privateKey")
    if returned_key and not hmac.compare_digest(returned_key.encode().strip(), key.strip()):
        raise SetupError("Firebase's signing-key read-back did not match. The scoped backup is retained.")
    print(json.dumps({"projectId": PROJECT, "configured": True, **status,
                      "secretVersion": secret_name, "newBackupVersion": created,
                      "deviceVerificationRequired": "Apple sign in, reauthentication, and account deletion/token revocation"}, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except SetupError as error:
        print(f"Apple Sign In setup: {error}", file=sys.stderr)
        raise SystemExit(1) from None
    except KeyboardInterrupt:
        print("Apple Sign In setup interrupted; no credentials were printed.", file=sys.stderr)
        raise SystemExit(130) from None
    except Exception:
        # Avoid an unhandled exception exposing a response/request containing p8.
        print("Apple Sign In setup stopped unexpectedly. No secret payload or traceback was printed.", file=sys.stderr)
        raise SystemExit(1) from None
