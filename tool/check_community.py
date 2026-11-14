#!/usr/bin/env python3
"""Exercise the live Brothers community end to end with two disposable
accounts, then remove every trace of them.

Join, a refused card write, a moderated post, a refused unclean post, an Amen
from a non-member (refused) and a member (accepted), a reply, a report, a
block, an edit and a refused edit, deleting a reply, leaving, and deleting an
account. Tokens and passwords stay in memory; the report holds check names
and outcomes only.

  python3 tool/check_community.py
"""
from __future__ import annotations

import datetime
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
PROJECT = 'holyhim-app-production'
ACCOUNT = 'iamirrf1@gmail.com'
FUNCTIONS = f'https://us-central1-{PROJECT}.cloudfunctions.net/'
DOCS = f'https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents'
AUTH = 'https://identitytoolkit.googleapis.com/v1/'
checks: list[dict] = []


def call(method, url, body=None, token=None, admin=False):
    headers = {'Content-Type': 'application/json'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    if admin:
        headers['x-goog-user-project'] = PROJECT
    req = urllib.request.Request(url, method=method, headers=headers,
                                 data=None if body is None else json.dumps(body).encode())
    try:
        with urllib.request.urlopen(req, timeout=90) as r:
            status, data = r.status, r.read()
    except urllib.error.HTTPError as e:
        status, data = e.code, e.read()
    try:
        payload = json.loads(data) if data else {}
    except json.JSONDecodeError:
        payload = {}
    return status, payload


def ok(name):
    checks.append({'check': name, 'passed': True})
    print('PASS:', name, flush=True)


def fn(name, data, token):
    return call('POST', FUNCTIONS + name, {'data': data}, token)


def fields(d):
    def v(x):
        if isinstance(x, bool):
            return {'booleanValue': x}
        if isinstance(x, int):
            return {'integerValue': str(x)}
        if isinstance(x, list):
            return {'arrayValue': {'values': [v(i) for i in x]}}
        if isinstance(x, datetime.datetime):
            return {'timestampValue': x.isoformat().replace('+00:00', 'Z')}
        return {'stringValue': x}
    return {k: v(x) for k, x in d.items()}


def patch(path, data, token, mask=None, admin=False):
    query = '' if not mask else '?' + '&'.join('updateMask.fieldPaths=' + m for m in mask)
    return call('PATCH', f'{DOCS}/{path}{query}', {'fields': fields(data)}, token, admin)


def get(path, token, admin=False):
    return call('GET', f'{DOCS}/{path}', token=token, admin=admin)


def main() -> int:
    native = plistlib.loads((ROOT / 'ios/Runner/GoogleService-Info.plist').read_bytes())
    assert native['PROJECT_ID'] == PROJECT
    key = native['API_KEY']
    admin = subprocess.check_output(['gcloud', 'auth', 'print-access-token', '--account=' + ACCOUNT], text=True).strip()
    users = []
    created_reports: list[str] = []
    failure = None
    try:
        for _ in range(2):
            status, r = call('POST', AUTH + 'accounts:signUp?key=' + key, {
                'email': 'qa-' + uuid.uuid4().hex + '@holyhim.example',
                'password': secrets.token_urlsafe(24), 'returnSecureToken': True})
            assert status == 200, status
            users.append({'uid': r['localId'], 'token': r['idToken'], 'deleted': False})
        a, b = users
        ok('Two disposable accounts')
        now = datetime.datetime.now(datetime.timezone.utc)
        card = {'name': 'QA Brother', 'metal': 'silver', 'photo': '', 'streak': 0, 'best': 0, 'days': 0,
                'medal': '', 'agreedAt': now, 'joinedAt': now, 'updatedAt': now}
        assert patch(f"members/{a['uid']}", card, b['token'])[0] == 403
        assert patch(f"members/{a['uid']}", card, a['token'])[0] == 200
        ok('Joining writes only your own card')

        status, r = fn('communityPost', {'text': 'Disposable QA post. Praying for the brothers.', 'kind': 'prayer'}, a['token'])
        assert status == 200, (status, r)
        post = r['result']['id']
        status, _ = fn('communityPost', {'text': 'this is sh1t', 'kind': 'word'}, a['token'])
        assert status == 400, status
        status, _ = fn('communityPost', {'text': 'Not a member yet', 'kind': 'word'}, b['token'])
        assert status == 400, status
        ok('Server posts clean text for members and refuses unclean text and non-members')

        assert patch(f'posts/{post}', {'amens': 1, 'amenBy': [b['uid']]}, b['token'], ['amens', 'amenBy'])[0] == 403
        assert patch(f"members/{b['uid']}", {**card, 'name': 'QA Brother Two'}, b['token'])[0] == 200
        assert patch(f'posts/{post}', {'amens': 1, 'amenBy': [b['uid']]}, b['token'], ['amens', 'amenBy'])[0] == 200
        assert patch(f'posts/{post}', {'text': 'changed'}, b['token'], ['text'])[0] == 403
        ok('Amen needs membership and can change nothing else')

        status, r = fn('communityComment', {'postId': post, 'text': 'Praying with you, brother.'}, b['token'])
        assert status == 200, (status, r)
        reply = r['result']['id']
        _, p = get(f'posts/{post}', admin, admin=True)
        assert p['fields']['comments']['integerValue'] == '1'
        ok('Reply counted on the post')

        status, r = fn('communityReport', {'postId': post, 'reason': 'spam'}, b['token'])
        assert status == 200, (status, r)
        created_reports.append(f"{post}_{b['uid']}")
        _, rep = get(f'reports/{post}_' + b['uid'], admin, admin=True)
        assert rep['fields']['status']['stringValue'] == 'open'
        assert get(f'reports/{post}_' + b['uid'], b['token'])[0] == 403
        ok('Report stored for review and private from members')

        assert patch(f"users/{b['uid']}/social/hidden", {'users': [a['uid']], 'posts': [post]}, b['token'])[0] == 200
        assert get(f"users/{b['uid']}/social/hidden", a['token'])[0] == 403
        ok('Block list saved and private')

        assert fn('communityEdit', {'postId': post, 'text': 'Edited by QA.'}, a['token'])[0] == 200
        assert fn('communityEdit', {'postId': post, 'text': 'Not yours.'}, b['token'])[0] == 403
        ok('Only the author edits')

        assert fn('communityDelete', {'postId': post, 'commentId': reply}, a['token'])[0] == 200
        _, p = get(f'posts/{post}', admin, admin=True)
        assert p['fields']['comments']['integerValue'] == '0'
        ok("Post author removes a reply and the count follows")

        assert fn('communityLeave', {}, a['token'])[0] == 200
        assert get(f"members/{a['uid']}", admin, admin=True)[0] == 404
        assert get(f'posts/{post}', admin, admin=True)[0] == 404
        ok('Leaving deletes the card and posts')

        assert fn('deleteAccount', {}, b['token'])[0] == 200
        b['deleted'] = True
        assert get(f"members/{b['uid']}", admin, admin=True)[0] == 404
        assert get(f"users/{b['uid']}", admin, admin=True)[0] == 404
        ok('Deleting an account deletes the community card too')
    except Exception as error:  # noqa: BLE001
        failure = repr(error)
        checks.append({'check': 'Community verification completed', 'passed': False, 'error': failure})
        print('FAIL:', failure, flush=True)
    finally:
        for user in users:
            uid = user['uid']
            for path in (f'members/{uid}', f'users/{uid}/social/hidden', f'communityRates/{uid}',
                         f'users/{uid}', f'deletionGuards/{uid}'):
                call('DELETE', f'{DOCS}/{path}', token=admin, admin=True)
            if not user['deleted']:
                call('POST', f'{AUTH}projects/{PROJECT}/accounts:delete', {'localId': uid}, admin, admin=True)
        for rid in created_reports:
            call('DELETE', f'{DOCS}/reports/{rid}', token=admin, admin=True)
        print('Cleanup done: disposable accounts, cards, reports and rate counters removed.')
    report = {'verifiedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'project': PROJECT,
              'checks': checks, 'passed': failure is None}
    (ROOT / 'store/community-check.json').write_text(json.dumps(report, indent=2) + '\n')
    return 0 if failure is None else 1


if __name__ == '__main__':
    sys.exit(main())
