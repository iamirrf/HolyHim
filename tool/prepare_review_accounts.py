"""Create retained App Review accounts; keep credentials only in Secret Manager.

This helper never grants access, starts a journey, sends email, resets a password,
changes IAM, or uploads credentials to Apple. Its console/status output contains
no password, token or Firebase UID. Re-running validates recognized accounts.
"""
from __future__ import annotations
import datetime
import json
import plistlib
import secrets
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = 'holyher-app-production'
ACCOUNT = 'iamirrf1@gmail.com'
BUNDLE = 'com.holyher.app'
ROLES = ('onboarding', 'journey')
AUTH = 'https://identitytoolkit.googleapis.com/v1/'
DOCUMENTS = 'https://firestore.googleapis.com/v1/projects/' + PROJECT + '/databases/(default)/documents/'
STATUS_PATH = ROOT / 'store/reviewer-account-status.json'


def cloud(*arguments):
    return subprocess.run(['gcloud', *arguments, '--project=' + PROJECT,
        '--account=' + ACCOUNT, '--no-log-http', '--verbosity=error'],
        capture_output=True, text=True)


def http(method, url, body=None, token=None, allow_missing=False):
    headers = {'Content-Type': 'application/json'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
        headers['x-goog-user-project'] = PROJECT
    request = urllib.request.Request(url, method=method, headers=headers,
        data=None if body is None else json.dumps(body).encode())
    try:
        with urllib.request.urlopen(request, timeout=45) as response:
            raw = response.read()
    except urllib.error.HTTPError as error:
        if allow_missing and error.code == 404:
            return None
        # Never emit response bodies, request bodies, credentials or UIDs.
        raise RuntimeError('Firebase request failed with HTTP ' + str(error.code)) from None
    return json.loads(raw) if raw else {}


def secret_name(role):
    return 'HOLYHER_APP_REVIEW_' + role.upper()


def email_for(role):
    return 'appreview-' + role + '@holyher.example'


def labels_for(role):
    return {'app': 'holyher', 'purpose': 'app-review-' + role,
            'managed_by': 'holyher-release', 'schema': 'v1'}


def lookup(admin, **selector):
    response = http('POST', AUTH + 'projects/' + PROJECT + '/accounts:lookup', selector, admin)
    users = response.get('users', [])
    if len(users) > 1:
        raise RuntimeError('Review account lookup is ambiguous; no account was changed')
    return users[0] if users else None


def read_secret(role):
    """Return (exists, recognized credential JSON or None for an empty secret)."""
    name = secret_name(role)
    result = cloud('secrets', 'describe', name, '--format=json')
    if result.returncode:
        # Distinguish a genuinely absent secret from permission/network errors.
        listing = cloud('secrets', 'list', '--filter=name:' + name, '--format=json')
        if listing.returncode:
            raise RuntimeError('Secret Manager metadata could not be inspected')
        if any(item['name'].rsplit('/', 1)[-1] == name for item in json.loads(listing.stdout)):
            raise RuntimeError('Existing review secret could not be inspected')
        return False, None
    metadata = json.loads(result.stdout)
    if any(metadata.get('labels', {}).get(key) != value for key, value in labels_for(role).items()):
        raise RuntimeError('Existing secret has unrecognized ownership labels; left untouched')
    policy = cloud('secrets', 'get-iam-policy', name, '--format=json')
    if policy.returncode:
        raise RuntimeError('Review secret IAM could not be inspected')
    # These are owner-only setup secrets: no explicit data-reader grants to a
    # runtime/service identity. Project ownership supplies the owner's access.
    for binding in json.loads(policy.stdout).get('bindings', []):
        if binding.get('role') == 'roles/secretmanager.secretAccessor' and any(
                member != 'user:' + ACCOUNT for member in binding.get('members', [])):
            raise RuntimeError('Review secret has an unexpected explicit reader; left untouched')
    versions = cloud('secrets', 'versions', 'list', name, '--format=json')
    if versions.returncode:
        raise RuntimeError('Review secret versions could not be inspected')
    if not json.loads(versions.stdout):
        return True, None
    saved = cloud('secrets', 'versions', 'access', 'latest', '--secret=' + name)
    if saved.returncode:
        raise RuntimeError('Existing review credential version could not be read')
    try:
        credential = json.loads(saved.stdout)
    except (TypeError, ValueError):
        raise RuntimeError('Existing review credentials have an unrecognized format') from None
    expected = {'schema': 1, 'projectId': PROJECT, 'bundleId': BUNDLE,
                'purpose': 'holyher-app-review', 'role': role, 'email': email_for(role)}
    if any(credential.get(key) != value for key, value in expected.items()):
        raise RuntimeError('Existing review credentials target a different app/account; left untouched')
    if not isinstance(credential.get('uid'), str) or not credential['uid']:
        raise RuntimeError('Existing review credentials lack their recognized account identity')
    if not isinstance(credential.get('password'), str) or len(credential['password']) < 32:
        raise RuntimeError('Existing review credentials fail the password format check; no reset attempted')
    return True, credential


def create_secret(role):
    label_text = ','.join(key + '=' + value for key, value in labels_for(role).items())
    result = cloud('secrets', 'create', secret_name(role), '--replication-policy=automatic', '--labels=' + label_text)
    if result.returncode:
        raise RuntimeError('Review secret container could not be created; no account was created')
    # No IAM update is performed; no runtime identity receives secret access.


def save_credential(role, credential):
    payload = json.dumps(credential, sort_keys=True, separators=(',', ':'))
    result = subprocess.run(['gcloud', 'secrets', 'versions', 'add', secret_name(role),
        '--data-file=-', '--project=' + PROJECT, '--account=' + ACCOUNT,
        '--no-log-http', '--verbosity=error'], input=payload, capture_output=True, text=True)
    # A command can fail after an accepted write. Re-read in memory before
    # deciding whether rollback is required; never print the version payload.
    readback = cloud('secrets', 'versions', 'access', 'latest', '--secret=' + secret_name(role))
    if readback.returncode == 0:
        try:
            if json.loads(readback.stdout) == credential:
                return True
        except ValueError:
            pass
    if result.returncode == 0:
        # The successful write preserves credentials even if read-back is
        # temporarily unavailable. Retain the account and let re-run verify it.
        raise RuntimeError('Credential write succeeded but read-back could not be verified; retained recognized account')
    return False


def rollback_new_user(admin, uid, id_token, api_key):
    for attempt in range(3):
        try:
            http('POST', AUTH + 'projects/' + PROJECT + '/accounts:delete', {'localId': uid}, admin)
            if lookup(admin, localId=[uid]) is None:
                return
        except Exception:
            try:
                http('POST', AUTH + 'accounts:delete?key=' + urllib.parse.quote(api_key), {'idToken': id_token})
                if lookup(admin, localId=[uid]) is None:
                    return
            except Exception:
                pass
        if attempt < 2:
            time.sleep(1)
    raise RuntimeError('New review account cleanup could not be confirmed; inspect the reserved review email before retrying')


def prepare_one(role, admin, api_key):
    exists, credential = read_secret(role)
    existing_email = lookup(admin, email=[email_for(role)])
    created = False
    if credential:
        existing_uid = lookup(admin, localId=[credential['uid']])
        if (not existing_email or not existing_uid
                or existing_email.get('localId') != credential['uid']
                or existing_uid.get('email') != email_for(role)):
            raise RuntimeError('Saved review credentials do not match the existing account; nothing reset or deleted')
        if existing_uid.get('disabled'):
            raise RuntimeError('Recognized review account is disabled; nothing reset or deleted')
    else:
        if existing_email:
            raise RuntimeError('Reserved review email already belongs to an unrecognized user; left untouched')
        if not exists:
            create_secret(role)
        password = secrets.token_urlsafe(36)
        signup = http('POST', AUTH + 'accounts:signUp?key=' + urllib.parse.quote(api_key),
            {'email': email_for(role), 'password': password, 'returnSecureToken': True})
        credential = {'schema': 1, 'projectId': PROJECT, 'bundleId': BUNDLE,
            'purpose': 'holyher-app-review', 'role': role, 'email': email_for(role),
            'uid': signup['localId'], 'password': password,
            'createdAt': datetime.datetime.now(datetime.timezone.utc).isoformat()}
        if not save_credential(role, credential):
            rollback_new_user(admin, signup['localId'], signup['idToken'], api_key)
            raise RuntimeError('Credential saving failed; only the newly created review user was removed')
        created = True
    signed = http('POST', AUTH + 'accounts:signInWithPassword?key=' + urllib.parse.quote(api_key),
        {'email': credential['email'], 'password': credential['password'], 'returnSecureToken': True})
    if signed.get('localId') != credential['uid']:
        raise RuntimeError('Review sign-in returned an unexpected identity')
    user = lookup(admin, localId=[credential['uid']])
    if not user or user.get('email') != credential['email'] or user.get('disabled'):
        raise RuntimeError('Review account read-back did not match')
    entitlement = http('GET', DOCUMENTS + 'users/' + credential['uid'] + '/private/entitlement', token=admin, allow_missing=True)
    journey = http('GET', DOCUMENTS + 'users/' + credential['uid'] + '/private/journey', token=admin, allow_missing=True)
    active = bool(entitlement and entitlement.get('fields', {}).get('active', {}).get('booleanValue') is True)
    return {'role': role, 'email': email_for(role), 'secretName': secret_name(role),
        'credentialStoredAndVerified': True, 'actualSignInVerified': True,
        'createdThisRun': created, 'emailVerified': user.get('emailVerified', False),
        'workingMailboxProvided': False, 'runtimeSecretAccessGranted': False,
        'paidAccessObserved': active, 'journeyObserved': journey is not None,
        'readyForCredentialUpload': True,
        'readyForPaidJourneyReview': False,
        'remainingGates': ['Upload credentials through the authenticated Apple owner session.',
            'Confirm email/password sign-in on the signed iPhone/iPad app.',
            'Complete a real Apple sandbox lifetime purchase and verify restore.',
            'Start the journey through the normal paid app flow and verify lesson completion/sync.']}


def main():
    config = json.loads((ROOT / 'config/cloud.json').read_text())
    native = plistlib.loads((ROOT / 'ios/Runner/GoogleService-Info.plist').read_bytes())
    if config['projectId'] != PROJECT or config['account'] != ACCOUNT or native['PROJECT_ID'] != PROJECT or native['BUNDLE_ID'] != BUNDLE:
        raise RuntimeError('Review setup project, owner or native bundle mismatch')
    token_result = cloud('auth', 'print-access-token')
    if token_result.returncode:
        raise RuntimeError('The intended Google owner account is not authenticated')
    admin = token_result.stdout.strip()
    policy = http('POST', 'https://cloudresourcemanager.googleapis.com/v1/projects/' + PROJECT + ':getIamPolicy', {}, admin)
    owners = {member for binding in policy.get('bindings', []) if binding.get('role') == 'roles/owner' for member in binding.get('members', [])}
    if owners != {'user:' + ACCOUNT}:
        raise RuntimeError('Review account setup requires the verified HolyHer project owner')
    report = {'verifiedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'projectId': PROJECT, 'ownerAccount': ACCOUNT, 'bundleId': BUNDLE,
        'accounts': [], 'credentialsUploadedToApple': False,
        'accessGrantedByHelper': False, 'journeyCreatedByHelper': False,
        'notes': ['These are reserved Firebase email/password test identities, not email inboxes.',
            'No email verification or inbox availability is claimed.',
            'Credentials remain only in labeled Google Secret Manager versions; the helper changes no IAM bindings.',
            'The journey-role account has no fabricated entitlement or journey. Paid acceptance remains required.']}
    failed = False
    for role in ROLES:
        try:
            status = prepare_one(role, admin, native['API_KEY'])
            report['accounts'].append(status)
            print('PASS:', role, 'review account sign-in and Secret Manager read-back verified.', flush=True)
        except Exception as error:
            # Error messages are controlled and contain no payloads or UIDs.
            report['accounts'].append({'role': role, 'email': email_for(role),
                'readyForCredentialUpload': False, 'error': str(error)})
            print('STOP:', role + ':', str(error), flush=True)
            failed = True
    STATUS_PATH.write_text(json.dumps(report, indent=2) + '\n')
    print('Sanitized reviewer status written. Paid access and journey acceptance remain release gates.', flush=True)
    return 1 if failed else 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception as error:
        print('STOP:', str(error), file=sys.stderr)
        sys.exit(1)
