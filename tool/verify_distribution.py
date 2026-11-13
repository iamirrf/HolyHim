#!/usr/bin/env python3
"""Verify an explicitly supplied exported IPA; never build, upload or log in.

The report contains public app/signing identifiers and privacy declarations,
not provisioning profiles, certificates, credentials or account sessions.
Local verification is distinct from Apple's upload/processing acceptance.
"""
import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path, PurePosixPath
import plistlib
import re
import shutil
import stat
import sys
import tempfile
import zipfile
import zlib

from verify_archive import (
    ROOT, BUNDLE, TEAM, PROJECT, GOOGLE_APP, inspect_privacy, load_plist, run, sha,
)
from release_gate import production_gate_disabled


def ipa_sha(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def extract(ipa, destination):
    """Extract validated regular files only, with bounded total expansion."""
    with zipfile.ZipFile(ipa) as archive:
        entries = archive.infolist()
        if len(entries) > 50000 or sum(row.file_size for row in entries) > 2 * 1024**3:
            raise ValueError('IPA exceeds the bounded verification extraction size.')
        names = set()
        for row in entries:
            name = row.filename
            parts = name.rstrip('/').split('/')
            kind = stat.S_IFMT(row.external_attr >> 16)
            if (not name or '\\' in name or PurePosixPath(name).is_absolute()
                    or any(part in ('', '.', '..') for part in parts)
                    or ':' in parts[0] or kind not in (0, stat.S_IFREG, stat.S_IFDIR)
                    or row.flag_bits & 1 or row.file_size > 1024**3):
                raise ValueError('IPA contains an unsafe, encrypted or unsupported ZIP entry.')
            key = name.rstrip('/').casefold()
            if key in names:
                raise ValueError('IPA contains duplicate or case-colliding ZIP entries.')
            names.add(key)
        for row in entries:
            target = destination.joinpath(*PurePosixPath(row.filename).parts)
            if row.is_dir():
                target.mkdir(parents=True, exist_ok=True, mode=0o700)
                continue
            target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
            with archive.open(row) as source, target.open('xb') as output:
                shutil.copyfileobj(source, output, length=1024 * 1024)
            mode = (row.external_attr >> 16) & 0o777
            target.chmod((mode or 0o644) & ~0o022)


def manifest_inventory(privacy):
    """Compare parsed declarations; Xcode may re-encode plist bytes on export."""
    return sorted(({
        key: row[key] for key in (
            'path', 'tracking', 'trackingDomains', 'collectedDataTypes', 'accessedAPITypes')
    } for row in privacy['manifests']), key=lambda row: row['path'])


def audit(ipa, output, archive_report):
    report = {
        'checkedAt': dt.datetime.now(dt.timezone.utc).isoformat(),
        'ipa': str(ipa), 'status': 'failed', 'checks': {}, 'failures': [],
        'scope': 'Actual exported IPA identity, distribution signing and bundled privacy declarations; not Apple processing acceptance.',
    }

    def check(name, passed):
        report['checks'][name] = bool(passed)
        if not passed and name not in report['failures']:
            report['failures'].append(name)

    try:
        check('production_paywall_gate_disabled', production_gate_disabled(ROOT))
        check('explicit_ipa_file', ipa.is_file() and ipa.suffix.lower() == '.ipa')
        if not report['checks']['explicit_ipa_file']:
            raise ValueError('Supply the actual exported .ipa file explicitly.')
        report['ipaSha256'] = ipa_sha(ipa)
        report['ipaBytes'] = ipa.stat().st_size
        with tempfile.TemporaryDirectory(prefix='holyhim-distribution-') as temp:
            root = Path(temp)
            extract(ipa, root)
            check('safe_zip_extraction', True)
            apps = sorted((root / 'Payload').glob('*.app'))
            check('one_payload_application', len(apps) == 1 and apps[0].is_dir())
            if not report['checks']['one_payload_application']:
                raise ValueError('IPA must contain exactly one direct Payload/*.app application.')
            app = apps[0]
            info = load_plist(app / 'Info.plist')
            source_version = re.search(r'^version:\s*([^+\s]+)\+(\d+)',
                                       (ROOT / 'pubspec.yaml').read_text(), re.MULTILINE)
            if source_version is None:
                raise ValueError('pubspec.yaml has no Flutter version and build number.')
            for key, expected in (
                ('CFBundleIdentifier', BUNDLE), ('CFBundleDisplayName', 'HolyHim'),
                ('CFBundleShortVersionString', source_version.group(1)),
                ('CFBundleVersion', source_version.group(2)),
                ('UIDeviceFamily', [1]), ('ITSAppUsesNonExemptEncryption', False),
            ):
                check(key, key in info and (info[key] is False
                    if key == 'ITSAppUsesNonExemptEncryption' else info[key] == expected))
            report['application'] = {key: info.get(key) for key in (
                'CFBundleIdentifier', 'CFBundleDisplayName', 'CFBundleShortVersionString',
                'CFBundleVersion', 'UIDeviceFamily', 'ITSAppUsesNonExemptEncryption',
                'MinimumOSVersion', 'DTSDKName', 'DTXcode')}
            check('compiled_asset_catalog', (app / 'Assets.car').is_file())
            check('compiled_launch_storyboard', (app / 'Base.lproj/LaunchScreen.storyboardc').is_dir())
            firebase_path = app / 'GoogleService-Info.plist'
            check('bundled_firebase_config', firebase_path.is_file())
            if firebase_path.is_file():
                firebase = load_plist(firebase_path)
                report['firebase'] = {key: firebase.get(key) for key in (
                    'PROJECT_ID', 'GOOGLE_APP_ID', 'BUNDLE_ID')}
                check('firebase_project', firebase.get('PROJECT_ID') == PROJECT)
                check('firebase_app_id', firebase.get('GOOGLE_APP_ID') == GOOGLE_APP)
                check('firebase_bundle_id', firebase.get('BUNDLE_ID') == BUNDLE)
                check('firebase_config_matches_source', firebase == load_plist(
                    ROOT / 'ios/Runner/GoogleService-Info.plist'))
            privacy_path = app / 'PrivacyInfo.xcprivacy'
            check('root_privacy_manifest', privacy_path.is_file())
            if privacy_path.is_file():
                check('root_privacy_matches_source', load_plist(privacy_path) == load_plist(
                    ROOT / 'ios/Runner/PrivacyInfo.xcprivacy'))
            signature = run('/usr/bin/codesign', '--verify', '--deep', '--strict', str(app))
            check('codesign_verify_deep_strict', signature.returncode == 0)
            details = run('/usr/bin/codesign', '-dvv', str(app))
            details_text = (details.stdout + details.stderr).decode(errors='replace')
            team = re.search(r'^TeamIdentifier=(.+)$', details_text, re.MULTILINE)
            check('codesign_team', details.returncode == 0 and team is not None
                  and team.group(1) == TEAM)
            signed = run('/usr/bin/codesign', '-d', '--entitlements', ':-', str(app))
            check('entitlements_read', signed.returncode == 0)
            entitlements = plistlib.loads(signed.stdout)
            check('entitlement_application_id', entitlements.get('application-identifier') == TEAM + '.' + BUNDLE)
            check('entitlement_team', entitlements.get('com.apple.developer.team-identifier') == TEAM)
            check('apple_signin_entitlement', entitlements.get('com.apple.developer.applesignin') == ['Default'])
            check('distribution_debugger_disabled', entitlements.get('get-task-allow') is False)
            authorities = re.findall(r'^Authority=(.+)$', details_text, re.MULTILINE)
            distribution_authority = next((value for value in authorities
                if value.startswith(('Apple Distribution:', 'iPhone Distribution:'))), None)
            check('distribution_signing_authority', distribution_authority is not None)
            report['signing'] = {
                'teamIdentifier': team.group(1) if team else None,
                'distributionAuthorityPresent': distribution_authority is not None,
                'entitlements': {key: entitlements.get(key) for key in (
                    'application-identifier', 'com.apple.developer.team-identifier',
                    'com.apple.developer.applesignin', 'get-task-allow')},
            }
            baseline = json.loads((ROOT / 'store/metadata/privacy_labels.json').read_text())
            report['privacy'] = inspect_privacy(app, baseline, check)
            check('passed_archive_report_present', archive_report.is_file())
            if archive_report.is_file():
                archived = json.loads(archive_report.read_text())
                check('archive_report_passed', archived.get('status') == 'passed')
                check('privacy_inventory_matches_archive', manifest_inventory(report['privacy'])
                      == manifest_inventory(archived['privacy']))
                check('application_identity_matches_archive', all(
                    value == archived['application'].get(key)
                    for key, value in report['application'].items()))
                report['archiveComparison'] = {
                    'report': str(archive_report), 'reportSha256': sha(archive_report),
                    'manifestCount': archived['privacy']['manifestCount'],
                }
            report['sourceHashes'] = {str(path.relative_to(ROOT)): sha(path) for path in (
                ROOT / 'ios/Runner/GoogleService-Info.plist',
                ROOT / 'ios/Runner/PrivacyInfo.xcprivacy',
                ROOT / 'store/metadata/privacy_labels.json')}
        report['status'] = 'passed' if not report['failures'] else 'failed'
    except (OSError, ValueError, KeyError, TypeError, zipfile.BadZipFile, zlib.error,
            plistlib.InvalidFileException) as error:
        report['error'] = str(error)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2) + '\n')
    print(f"Distribution verification {report['status']}: {output}")
    if report['failures']:
        print('Failed checks: ' + ', '.join(report['failures']))
    if 'error' in report:
        print(report['error'])
    return 0 if report['status'] == 'passed' else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('ipa', type=Path, help='Explicit actual exported IPA path')
    parser.add_argument('--output', type=Path,
                        default=ROOT / 'store/distribution-verification.json')
    parser.add_argument('--archive-report', type=Path,
                        default=ROOT / 'store/archive-verification.json')
    args = parser.parse_args()
    return audit(args.ipa.resolve(), args.output.resolve(), args.archive_report.resolve())


if __name__ == '__main__':
    sys.exit(main())
