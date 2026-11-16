#!/usr/bin/env python3
"""Inspect a completed HolyHim archive, never substitute source files for it.

This records signing, identity and bundled privacy declarations. It does not
claim App Store validation, live provider acceptance or runtime data auditing.
Run only after xcodebuild archive has completed successfully.
"""
import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path
import plistlib
import re
import subprocess
import sys
from release_gate import production_gate_disabled
from check_identity import problems as identity_problems

ROOT = Path(__file__).resolve().parents[1]
BUNDLE = 'com.holyhim.app'
TEAM = 'DU9D6TAM58'
PROJECT = 'holyhim-app-production'
GOOGLE_APP = '1:924772723375:ios:e77948fc5cf114955d425a'
CATEGORIES = {
    'Name': 'Name', 'EmailAddress': 'Email Address',
    'PhoneNumber': 'Phone Number', 'CoarseLocation': 'Coarse Location',
    'SensitiveInfo': 'Sensitive Info', 'UserID': 'User ID',
    'DeviceID': 'Device ID', 'PurchaseHistory': 'Purchase History',
    'ProductInteraction': 'Product Interaction', 'OtherUsageData': 'Other Usage Data',
    'CustomerSupport': 'Customer Support', 'OtherDataTypes': 'Other Data Types',
    'OtherDiagnosticData': 'Other Diagnostic Data',
    'PhotosorVideos': 'Photos or Videos',
}
PURPOSES = {
    'AppFunctionality': 'App Functionality',
    'ProductPersonalization': 'Product Personalization', 'Analytics': 'Analytics',
}
ACCESSED_APIS = {
    'NSPrivacyAccessedAPICategoryFileTimestamp',
    'NSPrivacyAccessedAPICategorySystemBootTime',
    'NSPrivacyAccessedAPICategoryDiskSpace',
    'NSPrivacyAccessedAPICategoryActiveKeyboards',
    'NSPrivacyAccessedAPICategoryUserDefaults',
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_plist(path):
    with path.open('rb') as stream:
        return plistlib.load(stream)


def run(*args):
    return subprocess.run(args, capture_output=True)


def prefixed(value, prefix, mapping):
    if not isinstance(value, str) or not value.startswith(prefix):
        raise ValueError('Unknown privacy identifier: ' + str(value))
    suffix = value[len(prefix):]
    if suffix not in mapping:
        raise ValueError('Unreviewed privacy identifier: ' + value)
    return mapping[suffix]


def inspect_privacy(app, baseline, check):
    collected, accessed, inventory = {}, {}, []
    manifests = sorted(app.rglob('PrivacyInfo.xcprivacy'))
    check('privacy_manifests_present', bool(manifests))
    for path in manifests:
        data = load_plist(path)
        relative = path.relative_to(app).as_posix()
        check('no_tracking:' + relative,
              not data.get('NSPrivacyTracking', False)
              and not data.get('NSPrivacyTrackingDomains', []))
        inventory.append({
            'path': relative, 'sha256': sha(path),
            'tracking': data.get('NSPrivacyTracking', False),
            'trackingDomains': data.get('NSPrivacyTrackingDomains', []),
            'collectedDataTypes': data.get('NSPrivacyCollectedDataTypes', []),
            'accessedAPITypes': data.get('NSPrivacyAccessedAPITypes', []),
        })
        for row in data.get('NSPrivacyCollectedDataTypes', []):
            name = prefixed(row['NSPrivacyCollectedDataType'],
                            'NSPrivacyCollectedDataType', CATEGORIES)
            item = collected.setdefault(name, {
                'linkedToUser': False, 'usedForTracking': False,
                'purposes': set(), 'sources': set(),
            })
            item['linkedToUser'] |= bool(row.get('NSPrivacyCollectedDataTypeLinked', False))
            item['usedForTracking'] |= bool(row.get('NSPrivacyCollectedDataTypeTracking', False))
            item['sources'].add(relative)
            for purpose in row.get('NSPrivacyCollectedDataTypePurposes', []):
                item['purposes'].add(prefixed(purpose,
                    'NSPrivacyCollectedDataTypePurpose', PURPOSES))
        for row in data.get('NSPrivacyAccessedAPITypes', []):
            kind = row['NSPrivacyAccessedAPIType']
            check('known_accessed_api:' + kind, kind in ACCESSED_APIS)
            reasons = row.get('NSPrivacyAccessedAPITypeReasons', [])
            check('accessed_api_reasons:' + relative + ':' + kind,
                  bool(reasons) and all(isinstance(reason, str)
                    and re.fullmatch(r'[0-9A-F]{4}\.\d+', reason) for reason in reasons))
            item = accessed.setdefault(kind, {'reasons': set(), 'sources': set()})
            item['reasons'].update(reasons)
            item['sources'].add(relative)
    expected = {row['type']: row for row in baseline['dataTypes']}
    check('baseline_has_no_tracking', not baseline.get('dataUsedForTracking', False))
    for name, row in collected.items():
        target = expected.get(name)
        check('category_disclosed:' + name, target is not None)
        check('category_no_tracking:' + name, not row['usedForTracking'])
        if target is not None:
            check('purposes_disclosed:' + name,
                  row['purposes'].issubset(set(target['purposes'])))
            check('linkage_disclosed:' + name,
                  not row['linkedToUser'] or target['linkedToUser'])
            check('baseline_category_no_tracking:' + name,
                  not target['usedForTracking'])
    for mapping in (collected, accessed):
        for row in mapping.values():
            for key, value in row.items():
                if isinstance(value, set):
                    row[key] = sorted(value)
    return {'manifestCount': len(manifests), 'manifests': inventory,
            'combinedCollectedData': dict(sorted(collected.items())),
            'combinedAccessedAPIs': dict(sorted(accessed.items())),
            'qualification': 'Bundled declarations only; not a runtime data-use audit or Apple validation.'}


def audit(archive, output):
    report = {
        'checkedAt': dt.datetime.now(dt.timezone.utc).isoformat(),
        'archive': str(archive), 'status': 'failed',
        'scope': 'Completed archive identity, signing and combined bundled privacy declarations.',
        'checks': {}, 'failures': [],
    }

    def check(name, passed):
        report['checks'][name] = bool(passed)
        if not passed and name not in report['failures']:
            report['failures'].append(name)

    try:
        check('production_paywall_gate_disabled', production_gate_disabled(ROOT))
        check('identity_is_holyhim', not identity_problems(ROOT))
        check('archive_directory', archive.is_dir() and archive.suffix == '.xcarchive')
        check('archive_metadata', (archive / 'Info.plist').is_file())
        apps = sorted((archive / 'Products/Applications').glob('*.app'))
        check('one_archived_application', len(apps) == 1)
        if not all(report['checks'].values()):
            raise ValueError('A complete .xcarchive is required; wait for successful xcodebuild completion.')
        app = apps[0]
        info = load_plist(app / 'Info.plist')
        cloud_path = app / 'GoogleService-Info.plist'
        privacy_path = app / 'PrivacyInfo.xcprivacy'
        check('bundled_firebase_config', cloud_path.is_file())
        check('root_privacy_manifest', privacy_path.is_file())
        for key, expected in [('CFBundleIdentifier', BUNDLE),
                              ('CFBundleDisplayName', 'HolyHim'),
                              ('CFBundleShortVersionString', re.search(r'^version:\s*([^+\s]+)', (ROOT/'pubspec.yaml').read_text(),re.M)[1]),
                              ('CFBundleVersion', re.search(r'^version:\s*[^+]+\+(\d+)', (ROOT/'pubspec.yaml').read_text(),re.M)[1]), ('UIDeviceFamily', [1]),
                              ('ITSAppUsesNonExemptEncryption', False)]:
            check(key, info.get(key) == expected)
        check('compiled_asset_catalog', (app / 'Assets.car').is_file())
        widget = app / 'PlugIns/HolyHimWidget.appex'
        widget_info = load_plist(widget / 'Info.plist') if (widget / 'Info.plist').is_file() else {}
        check('widget_embedded', widget.is_dir())
        check('widget_version_matches', widget_info.get('CFBundleVersion') == info.get('CFBundleVersion')
              and widget_info.get('CFBundleShortVersionString') == info.get('CFBundleShortVersionString'))
        check('widget_verse_catalog', (widget / 'WidgetVerses.json').is_file())
        check('compiled_launch_storyboard', (app / 'Base.lproj/LaunchScreen.storyboardc').is_dir())
        report['application'] = {key: info.get(key) for key in (
            'CFBundleIdentifier', 'CFBundleDisplayName', 'CFBundleShortVersionString', 'CFBundleVersion',
            'ITSAppUsesNonExemptEncryption',
            'UIDeviceFamily', 'MinimumOSVersion', 'DTSDKName', 'DTXcode')}
        report['application']['bytes'] = sum(path.stat().st_size for path in app.rglob('*') if path.is_file())
        report['sourceHashes'] = {str(path.relative_to(ROOT)): sha(path) for path in (
            ROOT / 'ios/Runner/PrivacyInfo.xcprivacy',
            ROOT / 'ios/Runner/GoogleService-Info.plist',
            ROOT / 'ios/Podfile.lock', ROOT / 'store/metadata/privacy_labels.json',
            ROOT / 'config/release.json', ROOT / 'config/cloud.json')}
        if cloud_path.is_file():
            firebase = load_plist(cloud_path)
            report['firebase'] = {key: firebase.get(key) for key in (
                'PROJECT_ID', 'GOOGLE_APP_ID', 'BUNDLE_ID')}
            check('firebase_project', firebase.get('PROJECT_ID') == PROJECT)
            check('firebase_app_id', firebase.get('GOOGLE_APP_ID') == GOOGLE_APP)
            check('firebase_bundle_id', firebase.get('BUNDLE_ID') == BUNDLE)
            check('firebase_config_matches_source',
                  firebase == load_plist(ROOT / 'ios/Runner/GoogleService-Info.plist'))
        if privacy_path.is_file():
            check('root_privacy_matches_source', load_plist(privacy_path)
                  == load_plist(ROOT / 'ios/Runner/PrivacyInfo.xcprivacy'))
        signature = run('/usr/bin/codesign', '--verify', '--deep', '--strict', str(app))
        check('codesign_verify_deep_strict', signature.returncode == 0)
        details = run('/usr/bin/codesign', '-dvv', str(app))
        details_text = (details.stdout + details.stderr).decode(errors='replace')
        team = re.search(r'^TeamIdentifier=(.+)$', details_text, re.MULTILINE)
        check('codesign_team', details.returncode == 0 and team is not None
              and team.group(1) == TEAM)
        entitlement_result = run('/usr/bin/codesign', '-d', '--entitlements', ':-', str(app))
        check('entitlements_read', entitlement_result.returncode == 0)
        entitlements = plistlib.loads(entitlement_result.stdout)
        safe_keys = ('application-identifier', 'com.apple.developer.team-identifier',
                     'com.apple.developer.applesignin', 'get-task-allow')
        report['signing'] = {
            'teamIdentifier': team.group(1) if team else None,
            'entitlements': {key: entitlements.get(key) for key in safe_keys},
            'debuggerAllowed': bool(entitlements.get('get-task-allow', False)),
            'qualification': 'Archive signing is not proof of distribution export or App Store validation.',
        }
        check('entitlement_application_id', entitlements.get('application-identifier') == TEAM + '.' + BUNDLE)
        check('entitlement_team', entitlements.get('com.apple.developer.team-identifier') == TEAM)
        check('apple_signin_entitlement',
              entitlements.get('com.apple.developer.applesignin') == ['Default'])
        baseline = json.loads((ROOT / 'store/metadata/privacy_labels.json').read_text())
        report['privacy'] = inspect_privacy(app, baseline, check)
        report['status'] = 'passed' if not report['failures'] else 'failed'
    except (OSError, ValueError, KeyError, TypeError, plistlib.InvalidFileException) as error:
        report['error'] = str(error)
        report['status'] = 'failed'
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2) + '\n')
    print(f"Archive verification {report['status']}: {output}")
    if report['failures']:
        print('Failed checks: ' + ', '.join(report['failures']))
    if 'error' in report:
        print(report['error'])
    return 0 if report['status'] == 'passed' else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', nargs='?', type=Path,
                        default=ROOT / 'build/ios/archive/HolyHim.xcarchive')
    parser.add_argument('--output', type=Path,
                        default=ROOT / 'store/archive-verification.json')
    args = parser.parse_args()
    return audit(args.archive.resolve(), args.output.resolve())


if __name__ == '__main__':
    sys.exit(main())
