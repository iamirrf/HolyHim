#!/usr/bin/env python3
"""Review and act on community reports for HolyHim, as the project owner.

Apple requires that reports are acted on within 24 hours. Run `list` once a
day; it shows every open report with the reported text. Then hide, remove or
ban, and close the report.

  python3 tool/moderation.py list
  python3 tool/moderation.py hide POST_ID [--reply REPLY_ID]
  python3 tool/moderation.py restore POST_ID [--reply REPLY_ID]
  python3 tool/moderation.py remove POST_ID [--reply REPLY_ID]
  python3 tool/moderation.py ban UID [--reason TEXT]
  python3 tool/moderation.py close REPORT_ID [REPORT_ID ...]

Uses the owner's gcloud login (iamirrf1@gmail.com) against the production
project; the token stays in memory. Nothing runs without a command.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import subprocess
import sys
import urllib.error
import urllib.request

PROJECT = 'holyhim-app-production'
ACCOUNT = 'iamirrf1@gmail.com'
BASE = f'https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents'


def token() -> str:
    return subprocess.run(['gcloud', 'auth', 'print-access-token', f'--account={ACCOUNT}'],
                          check=True, capture_output=True, text=True).stdout.strip()


class Client:
    def __init__(self) -> None:
        self.headers = {'Authorization': 'Bearer ' + token(), 'Content-Type': 'application/json',
                        'x-goog-user-project': PROJECT}

    def call(self, method: str, url: str, body: dict | None = None) -> dict:
        data = None if body is None else json.dumps(body).encode()
        request = urllib.request.Request(url, data=data, headers=self.headers, method=method)
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                text = response.read().decode()
                return json.loads(text) if text else {}
        except urllib.error.HTTPError as error:
            if error.code == 404:
                return {}
            raise SystemExit(f'{method} {url} failed: {error.code} {error.read().decode()[:300]}')

    def query(self, collection: str, field: str, op: str, value: dict, parent: str = '') -> list[dict]:
        body = {'structuredQuery': {'from': [{'collectionId': collection}], 'where': {
            'fieldFilter': {'field': {'fieldPath': field}, 'op': op, 'value': value}}, 'limit': 500}}
        rows = self.call('POST', f'{BASE}{parent}:runQuery', body)
        return [row['document'] for row in rows if 'document' in row]

    def patch(self, path: str, fields: dict) -> None:
        mask = '&'.join(f'updateMask.fieldPaths={key}' for key in fields)
        self.call('PATCH', f'{BASE}/{path}?{mask}', {'fields': fields})

    def delete(self, path: str) -> None:
        self.call('DELETE', f'{BASE}/{path}')

    def get(self, path: str) -> dict:
        return self.call('GET', f'{BASE}/{path}')


def plain(fields: dict) -> dict:
    out = {}
    for key, value in fields.items():
        kind, raw = next(iter(value.items()))
        out[key] = int(raw) if kind == 'integerValue' else raw
    return out


def target(post: str, reply: str | None) -> str:
    return f'posts/{post}/comments/{reply}' if reply else f'posts/{post}'


def cmd_list(c: Client, _: argparse.Namespace) -> None:
    rows = c.query('reports', 'status', 'EQUAL', {'stringValue': 'open'})
    if not rows:
        print('No open reports.')
        return
    for doc in sorted(rows, key=lambda d: d.get('createTime', '')):
        r = plain(doc['fields'])
        rid = doc['name'].rsplit('/', 1)[1]
        where = f"post {r.get('postId')}" + (f" reply {r['commentId']}" if r.get('commentId') else '')
        print(f"{rid}\n  {r.get('createdAt', doc.get('createTime'))}  reason: {r.get('reason')}  {where}\n"
              f"  author: {r.get('authorName')} ({r.get('authorId')})  reporter: {r.get('reporter')}\n"
              f"  text: {str(r.get('text', ''))[:300]}\n")


def cmd_hide(c: Client, a: argparse.Namespace, hidden: bool = True) -> None:
    c.patch(target(a.post, a.reply), {'hidden': {'booleanValue': hidden}})
    print(('Hidden: ' if hidden else 'Restored: ') + target(a.post, a.reply))


def cmd_remove(c: Client, a: argparse.Namespace) -> None:
    if a.reply:
        c.delete(target(a.post, a.reply))
        post = c.get(f'posts/{a.post}')
        if post:
            count = max(0, int(post['fields'].get('comments', {}).get('integerValue', '1')) - 1)
            c.patch(f'posts/{a.post}', {'comments': {'integerValue': str(count)}})
    else:
        for reply in c.query('comments', 'hidden', 'IN', {'arrayValue': {'values': [
                {'booleanValue': True}, {'booleanValue': False}]}}, parent=f'/posts/{a.post}'):
            c.delete(reply['name'].split('/documents/', 1)[1])
        c.delete(f'posts/{a.post}')
    print('Removed: ' + target(a.post, a.reply))


def cmd_ban(c: Client, a: argparse.Namespace) -> None:
    now = dt.datetime.now(dt.timezone.utc).isoformat().replace('+00:00', 'Z')
    c.patch(f'bans/{a.uid}', {'reason': {'stringValue': a.reason}, 'createdAt': {'timestampValue': now}})
    hidden = 0
    for post in c.query('posts', 'authorId', 'EQUAL', {'stringValue': a.uid}):
        c.patch(post['name'].split('/documents/', 1)[1], {'hidden': {'booleanValue': True}})
        hidden += 1
    c.delete(f'members/{a.uid}')
    print(f'Banned {a.uid}: card removed, {hidden} posts hidden. They can no longer post, reply or rejoin.')


def cmd_close(c: Client, a: argparse.Namespace) -> None:
    for rid in a.reports:
        c.patch(f'reports/{rid}', {'status': {'stringValue': 'closed'}})
        print('Closed: ' + rid)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest='command', required=True)
    sub.add_parser('list')
    for name in ('hide', 'restore', 'remove'):
        p = sub.add_parser(name)
        p.add_argument('post')
        p.add_argument('--reply')
    p = sub.add_parser('ban')
    p.add_argument('uid')
    p.add_argument('--reason', default='Broke the community rules')
    p = sub.add_parser('close')
    p.add_argument('reports', nargs='+')
    args = parser.parse_args()
    client = Client()
    {'list': cmd_list, 'hide': cmd_hide, 'restore': lambda c, a: cmd_hide(c, a, False),
     'remove': cmd_remove, 'ban': cmd_ban, 'close': cmd_close}[args.command](client, args)
    return 0


if __name__ == '__main__':
    sys.exit(main())
