#!/usr/bin/env python3
"""Fail when HolyHim would ship with a placeholder or with HolyHer's identity.

Two things are checked, and both must hold before a build, deploy or upload:

1. No shipping file holds a `REPLACE_WITH_` placeholder, an all-zero Firebase
   project number, or an identifier that belongs to HolyHer (its Firebase
   project, RevenueCat objects, App Store ID, bundle ID or product IDs).
2. HolyHim's own identifiers agree with each other: the Google sign-in client
   in Info.plist matches GoogleService-Info.plist, the RevenueCat IDs in
   config/ are real and are the ones the server and the setup scripts use.

  python3 tool/check_identity.py        # exit 1 and list every problem

`tool/release_gate.py` runs this, and `verify_archive.py` and `verify_distribution.py`
record it as the check `identity_is_holyhim`.
"""
from __future__ import annotations

import json
import plistlib
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# Compiled into the app, served by Firebase, or deployed as rules and functions.
# HolyHer may not be named here at all.
APP = ('lib/', 'ios/', 'android/', 'web/', 'public/', 'functions/', 'config/', 'assets/',
       'pubspec.yaml', 'firebase.json', 'firebase.emulators.json', 'firestore.rules', 'storage.rules')
# Release tooling and store material. Prose may mention HolyHer (the sync
# script, the note to App Review); its identifiers may not appear.
TOOLING = ('tool/', 'store/')
SKIP = (
    'tool/sync_upstream.py',      # writes placeholders on purpose when HolyHim has no value yet
    'tool/check_identity.py', 'tool/tests/',
    'web/vendor/', 'ios/Pods/', 'functions/node_modules/', 'public/app/',
    # HolyHer's Oct 30 lifetime-purchase plan, renamed. Never run for HolyHim and
    # read by nothing; the membership catalog replaces both in the release phase.
    'store/iap-catalog.json', 'store/iap-plan.json',
)

PLACEHOLDER = re.compile(r'REPLACE_WITH_|(?<![0-9A-Za-z])0{12}(?![0-9A-Za-z])')
HER_NAME = re.compile(r'holyher', re.I)
# HolyHer's Firebase project number, RevenueCat project, app, entitlements
# (lifetime and member), offering and product, its App Store ID, and anything
# shaped like its bundle, project or product IDs.
HER_IDS = re.compile(
    r'746503857955|proj802af471|app294eba1272|entl62ead602f6|entlf63e788b71|ofrng6294cec645|prodcb08dff1bb'
    r'|6828594137|com\.holyher|holyher[-_]', re.I)
REVENUECAT_SHAPES = {'projectId': r'proj[0-9a-f]{6,}', 'appId': r'app[0-9a-f]{6,}', 'entitlementId': r'entl[0-9a-f]{6,}',
                     'offeringId': r'ofrng[0-9a-f]{6,}', 'productId': r'prod[0-9a-f]{6,}'}


def under(path: str, rules: tuple[str, ...]) -> bool:
    return any(path.startswith(rule) if rule.endswith('/') else path == rule for rule in rules)


def shipping_files(root: Path) -> list[str]:
    """Tracked files plus new ones not ignored, so a file is checked before its first commit."""
    listed = subprocess.run(['git', 'ls-files', '-co', '--exclude-standard'], cwd=root, capture_output=True, text=True)
    if listed.returncode:
        raise SystemExit(f'check_identity: cannot list files: {listed.stderr.strip()}')
    return [path for path in listed.stdout.splitlines()
            if under(path, APP + TOOLING) and not under(path, SKIP) and (root / path).is_file()]


def her_live_values(root: Path) -> list[str]:
    """HolyHer's current identifiers, read from its last commit when it sits beside HolyHim.

    Catches values the fixed list above does not know, such as its API keys.
    Read-only: `git show` on HolyHer, nothing written.
    """
    her = root.parent / 'HolyHer'
    if not (her / '.git').exists():
        return []
    sys.path.insert(0, str(root / 'tool'))
    from sync_upstream import identity_values, show
    try:
        theirs = identity_values(lambda path: show(her, 'HEAD', path))
        ours = identity_values(lambda path: (root / path).read_bytes() if (root / path).exists() else None)
    except (OSError, ValueError):
        return []
    return sorted({value for name, value in theirs.items() if len(value) >= 8 and ours.get(name) != value})


def scan(root: Path, paths: list[str], her_values: list[str] = ()) -> list[str]:
    problems = []
    for path in paths:
        data = (root / path).read_bytes()
        if b'\0' in data[:8192]:
            continue
        text = data.decode('utf-8', errors='replace')
        for number, line in enumerate(text.splitlines(), 1):
            found = PLACEHOLDER.search(line)
            if found:
                problems.append(f'{path}:{number}: placeholder {found.group(0)!r}')
            found = HER_IDS.search(line) or (HER_NAME.search(line) if under(path, APP) else None)
            if found:
                problems.append(f'{path}:{number}: HolyHer identifier {found.group(0)!r}')
            elif any(value in line for value in her_values):
                problems.append(f'{path}:{number}: a value from HolyHer\'s current configuration')
    return problems


def consistency(root: Path) -> list[str]:
    """HolyHim's identifiers must be real and must agree across every file that states them."""
    problems = []

    def text(path: str) -> str:
        file = root / path
        return file.read_text(errors='replace') if file.is_file() else ''

    def expect(condition: bool, message: str) -> None:
        if not condition:
            problems.append(message)

    try:
        google = plistlib.loads((root / 'ios/Runner/GoogleService-Info.plist').read_bytes())
        info = plistlib.loads((root / 'ios/Runner/Info.plist').read_bytes())
        cloud = json.loads(text('config/cloud.json'))
        release = json.loads(text('config/release.json'))
        revenuecat = json.loads(text('config/revenuecat.json'))
        public_key = json.loads(text('config/revenuecat-public.json')).get('iosPublicApiKey', '')
    except (OSError, ValueError, plistlib.InvalidFileException) as error:
        return [f'identity files unreadable: {error}']

    schemes = [scheme for entry in info.get('CFBundleURLTypes', []) for scheme in entry.get('CFBundleURLSchemes', [])]
    expect(info.get('GIDClientID') == google.get('CLIENT_ID'),
           'ios/Runner/Info.plist: GIDClientID is not the client in GoogleService-Info.plist (Google sign-in would fail)')
    expect(google.get('REVERSED_CLIENT_ID') in schemes,
           'ios/Runner/Info.plist: the Google sign-in URL scheme is not the one in GoogleService-Info.plist')
    expect(google.get('BUNDLE_ID') == release.get('bundleId'), 'GoogleService-Info.plist: bundle ID differs from config/release.json')
    expect(google.get('PROJECT_ID') == cloud.get('projectId') == release.get('firebaseProject'),
           'Firebase project differs between GoogleService-Info.plist, config/cloud.json and config/release.json')
    expect(google.get('GOOGLE_APP_ID') == cloud.get('firebaseIosAppId'),
           'config/cloud.json: firebaseIosAppId differs from GoogleService-Info.plist')
    for path in ('tool/verify_archive.py', 'lib/firebase_options.dart'):
        expect(str(google.get('GOOGLE_APP_ID')) in text(path), f'{path}: does not hold the Firebase iOS app ID')

    for key, shape in REVENUECAT_SHAPES.items():
        expect(re.fullmatch(shape, str(revenuecat.get(key, ''))) is not None,
               f'config/revenuecat.json: {key} is not a RevenueCat ID ({revenuecat.get(key)!r})')
    project, app, entitlement = (str(revenuecat.get(key, '')) for key in ('projectId', 'appId', 'entitlementId'))
    for path, values in (('functions/billing.js', (project, entitlement)), ('tool/connect_apple.sh', (project, app)),
                         ('tool/connect_revenuecat_backend.py', (project,))):
        for value in values:
            expect(bool(value) and value in text(path), f'{path}: does not use {value or "the RevenueCat ID"} from config/revenuecat.json')
    expect(public_key.startswith('appl_') and public_key in text('lib/services/billing_config.dart'),
           'lib/services/billing_config.dart: RevenueCat public key differs from config/revenuecat-public.json')
    return problems


def problems(root: Path = ROOT) -> list[str]:
    return scan(root, shipping_files(root), her_live_values(root)) + consistency(root)


if __name__ == '__main__':
    found = problems()
    if found:
        print('\n'.join(found))
        raise SystemExit(f'Identity check failed: {len(found)} problem(s). HolyHim must not ship like this.')
    print(f'Identity check passed: {len(shipping_files(ROOT))} shipping files, no placeholders, nothing of HolyHer\'s.')
