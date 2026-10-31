"""Exercise production auth/rules/functions using disposable QA data, then remove it.

No paid entitlement is ever fabricated. All identifiers, passwords and bearer tokens
remain in memory; the written report contains only check names and outcomes.
"""
from __future__ import annotations
import argparse
import concurrent.futures
import datetime
import hashlib
import json
import plistlib
import secrets
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = 'holyher-app-production'
ACCOUNT = 'iamirrf1@gmail.com'
WEBSITE = 'https://holyher-app-production.web.app'
FUNCTIONS = 'https://us-central1-' + PROJECT + '.cloudfunctions.net/'
DOCUMENTS = 'https://firestore.googleapis.com/v1/projects/' + PROJECT + '/databases/(default)/documents'
AUTH = 'https://identitytoolkit.googleapis.com/v1/accounts:'
users = []
checks = []
cleanup = []


def request(method, url, body=None, token=None, expected=200, admin=False, as_text=False):
    headers = {'Content-Type': 'application/json'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    if admin:
        headers['x-goog-user-project'] = PROJECT
    req = urllib.request.Request(url, method=method,
        data=None if body is None else json.dumps(body).encode(), headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=90) as response:
            status, data = response.status, response.read()
    except urllib.error.HTTPError as error:
        status, data = error.code, error.read()
    if status != expected:
        # Response bodies can contain credential payloads. Report status only.
        raise RuntimeError(f'{method} {urllib.parse.urlparse(url).path}: HTTP {status}, expected {expected}')
    if as_text:
        return data.decode()
    return json.loads(data) if data else {}


def passed(name):
    checks.append({'check': name, 'passed': True})
    print('PASS:', name, flush=True)


def callable_(name, data=None, token=None, expected=200):
    return request('POST', FUNCTIONS + name, {'data': data or {}}, token, expected)


def doc(path, token, expected=200):
    return request('GET', DOCUMENTS + '/' + path, token=token, expected=expected, admin=True)


def delete_doc(path, token, update_time=None):
    url = DOCUMENTS + '/' + path
    if update_time:
        url += '?currentDocument.updateTime=' + urllib.parse.quote(update_time, safe='')
    return request('DELETE', url, token=token, admin=True)


def collection(name, token):
    result = request('GET', DOCUMENTS + '/' + name + '?pageSize=1000', token=token, admin=True)
    if result.get('nextPageToken'):
        raise RuntimeError('QA refuses incomplete collection snapshot')
    return {item['name'].split('/documents/', 1)[1]: item for item in result.get('documents', [])}


def expect_error(response, status):
    if response.get('error', {}).get('status') != status:
        raise RuntimeError('Unexpected callable error category')


def verify_transport():
    """Read-only post-deploy probes; preserve earlier full acceptance evidence."""
    report_path = ROOT / 'store/live-cloud-verification.json'
    report = json.loads(report_path.read_text())
    assert report['projectId'] == PROJECT and report['ownerAccount'] == ACCOUNT
    refreshed = []

    def record(name):
        refreshed.append({'check': name, 'passed': True})
        print('PASS:', name, flush=True)

    def verify_binding(service):
        result = subprocess.run(['gcloud', 'run', 'services', 'get-iam-policy', service,
            '--region=us-central1', '--project=' + PROJECT, '--account=' + ACCOUNT,
            '--format=json'], check=True, capture_output=True, text=True)
        policy = json.loads(result.stdout)
        assert any(binding['role'] == 'roles/run.invoker' and 'allUsers' in binding.get('members', [])
                   for binding in policy.get('bindings', [])), 'Missing scoped transport invoker binding'
        return service

    failure = None
    services = []
    try:
        admin = subprocess.check_output(['gcloud', 'auth', 'print-access-token', '--account=' + ACCOUNT], text=True).strip()
        policy = request('POST', 'https://cloudresourcemanager.googleapis.com/v1/projects/' + PROJECT + ':getIamPolicy', {}, admin, admin=True)
        owners = {member for binding in policy.get('bindings', []) if binding['role'] == 'roles/owner'
                  for member in binding.get('members', [])}
        assert owners == {'user:' + ACCOUNT}
        record('Sole owner remains iamirrf1@gmail.com')
        for route in ('/', '/privacy', '/terms', '/support'):
            page = request('GET', WEBSITE + route, as_text=True)
            assert '<html' in page.lower() and 'holyher' in page.lower()
            if route == '/':
                assert 'Planned for November 15, 2026' in page
            record('Final deployed website route ' + route)
        assert 'error' in request('GET', WEBSITE + '/api/support', expected=405)
        request('POST', WEBSITE + '/api/support', {'email': 'invalid', 'message': 'short'}, expected=400)
        record('Final support handler is reachable and rejects invalid input')
        for endpoint in ('syncAccess', 'startJourney', 'getJourney', 'completeLesson', 'markActive', 'deleteAccount'):
            expect_error(callable_(endpoint, expected=401), 'UNAUTHENTICATED')
            record('Final callable ' + endpoint + ' rejects unauthenticated access')
        for token in (None, 'qa-invalid-secret'):
            request('POST', FUNCTIONS + 'revenuecatWebhook', {'event': {'id': 'qa-invalid-auth'}},
                    token=token, expected=401, as_text=True)
        record('Final billing webhook rejects missing and invalid authorization')
        names = ['syncaccess', 'startjourney', 'getjourney', 'completelesson', 'markactive',
                 'revenuecatwebhook', 'deleteaccount', 'supportrequest']
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            services = list(pool.map(verify_binding, names))
        record('All eight final service-specific public transport bindings read back')
    except Exception as error:
        failure = str(error)
        refreshed.append({'check': 'Final transport verification completed', 'passed': False, 'error': failure})
        print('FAIL:', failure, flush=True)
    report.setdefault('transportReverification', []).append({
        'verifiedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'checks': refreshed, 'verifiedServiceBindings': services,
        'sideEffects': 'Read-only IAM/owner inspection and rejected HTTP requests; no accounts or support messages created.'})
    report_path.write_text(json.dumps(report, indent=2) + '\n')
    return 1 if failure else 0


def main():
    config = json.loads((ROOT / 'config/cloud.json').read_text())
    native = plistlib.loads((ROOT / 'ios/Runner/GoogleService-Info.plist').read_bytes())
    assert config['projectId'] == native['PROJECT_ID'] == PROJECT
    assert config['account'] == ACCOUNT
    api_key = native['API_KEY']
    admin = subprocess.check_output(['gcloud', 'auth', 'print-access-token', '--account=' + ACCOUNT], text=True).strip()
    owner_policy = request('POST', 'https://cloudresourcemanager.googleapis.com/v1/projects/' + PROJECT + ':getIamPolicy', {}, admin, admin=True)
    owners = {member for binding in owner_policy.get('bindings', []) if binding['role'] == 'roles/owner' for member in binding.get('members', [])}
    assert owners == {'user:' + ACCOUNT}
    passed('Production project and sole owner match iamirrf1@gmail.com')
    support_email = 'qa-' + uuid.uuid4().hex + '@holyher.example'
    failure = None
    try:
        for route in ('/', '/privacy', '/terms', '/support'):
            page = request('GET', WEBSITE + route, as_text=True)
            assert '<html' in page.lower() and 'holyher' in page.lower()
            passed('Public website route ' + route)
        response = request('GET', WEBSITE + '/api/support', expected=405)
        assert 'error' in response
        request('POST', WEBSITE + '/api/support', {'email': 'invalid', 'message': 'short'}, expected=400)
        passed('Support endpoint rejects invalid method and form')
        response = request('POST', WEBSITE + '/api/support', {
            'email': support_email,
            'message': 'Automated HolyHer release verification. Disposable QA request; safely remove after read-back.',
            'website': ''})
        assert response == {'received': True}
        saved_requests = collection('supportRequests', admin)
        owned = {name: item for name, item in saved_requests.items() if item.get('fields', {}).get('email', {}).get('stringValue') == support_email}
        assert len(owned) == 1
        passed('Support form stores a real request in the correct project')

        for _ in range(2):
            result = request('POST', AUTH + 'signUp?key=' + api_key, {
                'email': 'qa-' + uuid.uuid4().hex + '@holyher.example',
                'password': secrets.token_urlsafe(24), 'returnSecureToken': True})
            users.append({'uid': result['localId'], 'token': result['idToken'], 'deleted': False})
        a, b = users
        passed('Production email/password sign-up')
        profile = {'name': {'stringValue': 'Cloud QA'}, 'familiarity': {'stringValue': 'new'},
            'focus': {'stringValue': 'peace'}, 'obstacle': {'stringValue': 'busy'},
            'reminderMinutes': {'nullValue': None}, 'onboardingComplete': {'booleanValue': False},
            'haptics': {'booleanValue': True}, 'onboardingStep': {'integerValue': '0'}}
        path = DOCUMENTS + '/users/' + a['uid']
        request('PATCH', path, {'fields': profile}, a['token'])
        saved = request('GET', path, token=a['token'])
        assert saved['fields']['name']['stringValue'] == 'Cloud QA'
        passed('Owner profile save and read-back')
        request('GET', path, token=b['token'], expected=403)
        request('GET', path, expected=403)
        request('PATCH', path + '/private/entitlement', {'fields': {'active': {'booleanValue': True}}}, a['token'], expected=403)
        invalid = dict(profile)
        invalid['focus'] = {'stringValue': 'invalid'}
        request('PATCH', path, {'fields': invalid}, a['token'], expected=403)
        passed('Rules reject cross-account/anonymous reads, paid access writes and invalid profiles')

        for endpoint in ('syncAccess', 'startJourney', 'getJourney', 'completeLesson', 'markActive', 'deleteAccount'):
            expect_error(callable_(endpoint, expected=401), 'UNAUTHENTICATED')
        passed('All six protected callables reject unauthenticated access')
        access = callable_('syncAccess', token=a['token'])
        assert access['result'] == {'active': False}
        access_doc = doc('users/' + a['uid'] + '/private/entitlement', admin)
        assert access_doc['fields']['active']['booleanValue'] is False
        passed('Live RevenueCat reconciliation confirms unpaid access is false')
        assert callable_('getJourney', token=a['token'])['result'] == {'started': False}
        passed('Unpaid account has no started journey')
        assert callable_('markActive', token=a['token'])['result'] == {'activeDays': []}
        passed('Activity callable cannot create activity before a journey starts')
        expect_error(callable_('startJourney', {'timeZone': 'America/New_York'}, a['token'], 403), 'PERMISSION_DENIED')
        expect_error(callable_('completeLesson', {'day': 1}, a['token'], 403), 'PERMISSION_DENIED')
        passed('Unpaid account cannot start or complete a lesson')
        request('POST', FUNCTIONS + 'revenuecatWebhook', {'event': {'id': 'qa-invalid-auth'}}, expected=401, as_text=True)
        request('POST', FUNCTIONS + 'revenuecatWebhook', {'event': {'id': 'qa-invalid-auth'}}, token='qa-invalid-secret', expected=401, as_text=True)
        passed('Billing webhook rejects missing and invalid authorization')
        result = callable_('deleteAccount', token=a['token'])
        assert result['result'] == {'deleted': True}
        a['deleted'] = True
        doc('users/' + a['uid'], admin, expected=404)
        doc('users/' + a['uid'] + '/private/entitlement', admin, expected=404)
        lookup = request('POST', 'https://identitytoolkit.googleapis.com/v1/projects/' + PROJECT + '/accounts:lookup', {'localId': [a['uid']]}, admin, admin=True)
        assert not lookup.get('users')
        tombstone = doc('accountStates/' + hashlib.sha256(a['uid'].encode()).hexdigest(), admin)
        assert tombstone['fields']['deleting']['booleanValue'] is True
        passed('Recent-auth account deletion removes Firebase user, profile and private access data')
    except Exception as error:
        failure = str(error)
        checks.append({'check': 'Live verification completed', 'passed': False, 'error': failure})
        print('FAIL:', failure, flush=True)
    finally:
        for user in users:
            uid = user['uid']
            try:
                children = collection('users/' + uid + '/private', admin)
                for name, value in children.items():
                    delete_doc(name, admin, value.get('updateTime'))
                delete_doc('users/' + uid, admin)
                delete_doc('accountStates/' + hashlib.sha256(uid.encode()).hexdigest(), admin)
                if not user['deleted']:
                    request('POST', 'https://identitytoolkit.googleapis.com/v1/projects/' + PROJECT + '/accounts:delete', {'localId': uid}, admin, admin=True)
                cleanup.append({'kind': 'disposable_account', 'removed': True})
            except Exception as error:
                cleanup.append({'kind': 'disposable_account', 'removed': False, 'error': str(error)})
        try:
            for name, value in collection('supportRequests', admin).items():
                if value.get('fields', {}).get('email', {}).get('stringValue') == support_email:
                    delete_doc(name, admin, value.get('updateTime'))
                    cleanup.append({'kind': 'disposable_support_request', 'removed': True})
            # The hourly counter can be shared with genuine requests from this
            # network. Preserve it and let its configured TTL expire naturally.
        except Exception as error:
            cleanup.append({'kind': 'support_qa', 'removed': False, 'error': str(error)})
        report = {'verifiedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
            'projectId': PROJECT, 'ownerAccount': ACCOUNT, 'website': WEBSITE,
            'checks': checks, 'cleanup': cleanup,
            'deploymentCorrection': {
                'reason': 'The initial deployment left all eight Cloud Run services without invoker bindings, causing transport-level HTTP 403.',
                'change': 'Added roles/run.invoker for allUsers on the eight HolyHer function services only.',
                'applicationAuthorization': 'Firebase callable authentication, server purchase checks, webhook authorization and Firestore rules remain enforced.'},
            'limitations': ['No paid entitlement was fabricated.', 'The shared hourly support rate counter is retained until its configured TTL; it contains no email/message.', 'A real Apple sandbox purchase, restore, refund and native identity sign-in still require device acceptance.']}
        (ROOT / 'store/live-cloud-verification.json').write_text(json.dumps(report, indent=2) + '\n')
        print('Sanitized verification report written; QA cleanup:', 'complete' if all(item['removed'] for item in cleanup) else 'requires attention', flush=True)
    return 1 if failure or not all(item['removed'] for item in cleanup) else 0


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--verify-transport', action='store_true',
                        help='Read-only post-deploy checks appended to the existing full verification report.')
    args = parser.parse_args()
    sys.exit(verify_transport() if args.verify_transport else main())
