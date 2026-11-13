#!/usr/bin/env python3
"""Create or complete HolyHim's own Google Cloud and Firebase project.

Idempotent: each step checks the live state first and only adds what is
missing. It mirrors HolyHer's production layout (Firestore and Storage in
us-central1, a three-role runtime service account, two RevenueCat secrets)
without reading or changing anything in HolyHer's project.

Uses the owner's existing gcloud login (config/cloud.json "account"); access
tokens stay in memory. Public Firebase app configuration is written to
ios/Runner/GoogleService-Info.plist and config/firebase-web.json.

  python3 tool/bootstrap_cloud.py            # run every step
  python3 tool/bootstrap_cloud.py --status   # read-only report
"""
from __future__ import annotations

import argparse
import base64
import json
import secrets
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CLOUD = json.loads((ROOT / 'config/cloud.json').read_text())
PROJECT = CLOUD['projectId']
ACCOUNT = CLOUD['account']
BILLING = CLOUD['billingAccountId']
REGION = CLOUD.get('region', 'us-central1')
BUNDLE = 'com.holyhim.app'
RUNTIME = PROJECT.split('-')[0] + '-runtime'
RUNTIME_EMAIL = f'{RUNTIME}@{PROJECT}.iam.gserviceaccount.com'
RUNTIME_ROLES = ['roles/datastore.user', 'roles/eventarc.eventReceiver', 'roles/firebaseauth.admin']
SERVICES = [
    'firebase.googleapis.com', 'firestore.googleapis.com', 'identitytoolkit.googleapis.com',
    'securetoken.googleapis.com', 'firebaserules.googleapis.com', 'firebasestorage.googleapis.com',
    'storage.googleapis.com', 'firebasehosting.googleapis.com', 'cloudfunctions.googleapis.com',
    'cloudbuild.googleapis.com', 'artifactregistry.googleapis.com', 'run.googleapis.com',
    'eventarc.googleapis.com', 'pubsub.googleapis.com', 'secretmanager.googleapis.com',
    'logging.googleapis.com', 'iam.googleapis.com', 'iamcredentials.googleapis.com',
    'cloudresourcemanager.googleapis.com', 'serviceusage.googleapis.com',
    'firebaseinstallations.googleapis.com', 'fcm.googleapis.com', 'cloudbilling.googleapis.com',
]


def gcloud(*args: str, check: bool = True, data: str | None = None) -> subprocess.CompletedProcess:
    result = subprocess.run(['gcloud', *args, f'--account={ACCOUNT}', '--verbosity=error', '--quiet'],
                            capture_output=True, text=True, input=data)
    if check and result.returncode:
        raise SystemExit(f"gcloud {' '.join(args[:3])} failed: {result.stderr.strip()[:600]}")
    return result


_token: str | None = None


def token() -> str:
    global _token
    if _token is None:
        _token = gcloud('auth', 'print-access-token').stdout.strip()
    return _token


def api(method: str, url: str, body: dict | None = None, ok: tuple[int, ...] = ()) -> dict:
    request = urllib.request.Request(
        url, method=method, data=None if body is None else json.dumps(body).encode(),
        headers={'Authorization': 'Bearer ' + token(), 'Content-Type': 'application/json',
                 'x-goog-user-project': PROJECT})
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            raw = response.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as error:
        if error.code in ok:
            return {'_status': error.code}
        raise SystemExit(f'{method} {url} -> HTTP {error.code}: {error.read().decode()[:600]}')


def wait(operation: dict, base: str) -> dict:
    while not operation.get('done'):
        time.sleep(2)
        operation = api('GET', f"{base}/{operation['name']}")
    if 'error' in operation:
        raise SystemExit(f"Operation failed: {operation['error']}")
    return operation.get('response', {})


def step(name: str) -> None:
    print(f'• {name}', flush=True)


def ensure_project() -> None:
    step(f'project {PROJECT}')
    if gcloud('projects', 'describe', PROJECT, '--format=value(lifecycleState)', check=False).returncode:
        gcloud('projects', 'create', PROJECT, '--name=HolyHim')
    linked = gcloud('billing', 'projects', 'describe', PROJECT, '--format=value(billingAccountName)').stdout
    if BILLING not in linked:
        gcloud('billing', 'projects', 'link', PROJECT, f'--billing-account={BILLING}')


def ensure_services() -> None:
    step('APIs')
    enabled = set(gcloud('services', 'list', '--enabled', f'--project={PROJECT}',
                         '--format=value(config.name)').stdout.split())
    missing = [s for s in SERVICES if s not in enabled]
    for start in range(0, len(missing), 15):
        gcloud('services', 'enable', *missing[start:start + 15], f'--project={PROJECT}')


def ensure_firebase() -> None:
    step('Firebase')
    base = 'https://firebase.googleapis.com/v1beta1'
    if api('GET', f'{base}/projects/{PROJECT}', ok=(403, 404)).get('_status'):
        wait(api('POST', f'{base}/projects/{PROJECT}:addFirebase', {}), base)


def ensure_firestore() -> None:
    step(f'Firestore in {REGION}')
    found = gcloud('firestore', 'databases', 'list', f'--project={PROJECT}', '--format=value(name)').stdout
    if '(default)' not in found:
        gcloud('firestore', 'databases', 'create', f'--location={REGION}', '--type=firestore-native',
               f'--project={PROJECT}')


def ensure_storage() -> None:
    step('Storage bucket')
    base = f'https://firebasestorage.googleapis.com/v1beta/projects/{PROJECT}'
    if api('GET', f'{base}/buckets/{PROJECT}.firebasestorage.app', ok=(404,)).get('_status'):
        api('POST', f'{base}/defaultBucket', {'location': REGION})


def ensure_runtime_account() -> None:
    step(f'runtime service account {RUNTIME_EMAIL}')
    if gcloud('iam', 'service-accounts', 'describe', RUNTIME_EMAIL, f'--project={PROJECT}', check=False).returncode:
        gcloud('iam', 'service-accounts', 'create', RUNTIME, '--display-name=HolyHim functions runtime',
               f'--project={PROJECT}')
    for role in RUNTIME_ROLES:
        gcloud('projects', 'add-iam-policy-binding', PROJECT, f'--member=serviceAccount:{RUNTIME_EMAIL}',
               f'--role={role}', '--condition=None', '--format=none')


def ensure_apps() -> None:
    step('iOS and web apps')
    base = 'https://firebase.googleapis.com/v1beta1'
    ios = [a for a in api('GET', f'{base}/projects/{PROJECT}/iosApps').get('apps', []) if a.get('bundleId') == BUNDLE]
    app = ios[0] if ios else wait(api('POST', f'{base}/projects/{PROJECT}/iosApps',
                                      {'bundleId': BUNDLE, 'displayName': 'HolyHim iOS'}), base)
    config = api('GET', f"{base}/projects/{PROJECT}/iosApps/{app['appId']}/config")
    (ROOT / 'ios/Runner/GoogleService-Info.plist').write_bytes(base64.b64decode(config['configFileContents']))
    web = [a for a in api('GET', f'{base}/projects/{PROJECT}/webApps').get('apps', [])
           if a.get('displayName') == 'HolyHim Web']
    web_app = web[0] if web else wait(api('POST', f'{base}/projects/{PROJECT}/webApps',
                                          {'displayName': 'HolyHim Web'}), base)
    web_config = api('GET', f"{base}/projects/{PROJECT}/webApps/{web_app['appId']}/config")
    web_config['authDomain'] = f'{PROJECT}.web.app'
    (ROOT / 'config/firebase-web.json').write_text(json.dumps(web_config, indent=2) + '\n')
    cloud = json.loads((ROOT / 'config/cloud.json').read_text())
    cloud['firebaseIosAppId'] = app['appId']
    (ROOT / 'config/cloud.json').write_text(json.dumps(cloud, indent=2) + '\n')


def ensure_auth() -> None:
    step('Authentication (email, authorized domains)')
    base = 'https://identitytoolkit.googleapis.com'
    if api('GET', f'{base}/admin/v2/projects/{PROJECT}/config', ok=(400, 404)).get('_status'):
        api('POST', f'{base}/v2/projects/{PROJECT}/identityPlatform:initializeAuth', {})
    api('PATCH', f'{base}/admin/v2/projects/{PROJECT}/config?updateMask='
                 'signIn.email.enabled,signIn.email.passwordRequired,authorizedDomains,emailPrivacyConfig',
        {'signIn': {'email': {'enabled': True, 'passwordRequired': True}},
         'authorizedDomains': [f'{PROJECT}.firebaseapp.com', f'{PROJECT}.web.app', 'localhost'],
         'emailPrivacyConfig': {'enableImprovedEmailPrivacy': True}})
    apple = api('GET', f'{base}/admin/v2/projects/{PROJECT}/defaultSupportedIdpConfigs/apple.com', ok=(404,))
    if apple.get('_status') == 404:
        api('POST', f'{base}/admin/v2/projects/{PROJECT}/defaultSupportedIdpConfigs?idpId=apple.com',
            {'enabled': True, 'appleSignInConfig': {'bundleIds': [BUNDLE]}})


def ensure_secrets() -> None:
    step('function secrets')
    names = set(gcloud('secrets', 'list', f'--project={PROJECT}', '--format=value(name)').stdout.split())
    if 'REVENUECAT_WEBHOOK_SECRET' not in names:
        gcloud('secrets', 'create', 'REVENUECAT_WEBHOOK_SECRET', '--replication-policy=automatic', f'--project={PROJECT}')
        gcloud('secrets', 'versions', 'add', 'REVENUECAT_WEBHOOK_SECRET', '--data-file=-', f'--project={PROJECT}',
               data=secrets.token_urlsafe(32))
    for name in ['REVENUECAT_WEBHOOK_SECRET', 'REVENUECAT_SECRET_API_KEY']:
        if name in names or name == 'REVENUECAT_WEBHOOK_SECRET':
            gcloud('secrets', 'add-iam-policy-binding', name, f'--member=serviceAccount:{RUNTIME_EMAIL}',
                   '--role=roles/secretmanager.secretAccessor', f'--project={PROJECT}', '--format=none', check=False)


def status() -> None:
    describe = gcloud('projects', 'describe', PROJECT, '--format=value(lifecycleState,projectNumber)', check=False)
    print('project:', describe.stdout.strip() or 'missing')
    if describe.returncode:
        return
    print('billing:', gcloud('billing', 'projects', 'describe', PROJECT, '--format=value(billingEnabled)').stdout.strip())
    print('firestore:', gcloud('firestore', 'databases', 'list', f'--project={PROJECT}',
                               '--format=value(locationId)', check=False).stdout.strip() or 'missing')
    print('secrets:', ' '.join(gcloud('secrets', 'list', f'--project={PROJECT}', '--format=value(name)',
                                      check=False).stdout.split()) or 'none')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--status', action='store_true')
    args = parser.parse_args()
    if 'REPLACE' in PROJECT + ACCOUNT + BILLING:
        sys.exit('config/cloud.json still holds placeholders for project, account or billing.')
    if args.status:
        status()
        return
    for run in [ensure_project, ensure_services, ensure_firebase, ensure_firestore, ensure_storage,
                ensure_runtime_account, ensure_apps, ensure_auth, ensure_secrets]:
        run()
    print('Done. Next: python3 tool/configure_firebase.py, then resync identifiers (tool/sync_upstream.py).')


if __name__ == '__main__':
    main()
