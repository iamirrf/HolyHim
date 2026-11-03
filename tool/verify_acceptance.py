"""Validate requirement coverage; --release checks acceptance without granting it."""
import argparse
import hashlib
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--release', action='store_true')
args = p.parse_args()
checklist = json.loads((ROOT / 'store/rebuild-acceptance.json').read_text())
source = (ROOT / checklist['source']).read_bytes()
assert hashlib.sha256(source).hexdigest() == checklist['sourceSha256'], 'Acceptance source changed; reconcile requirements.'
lines = source.decode().splitlines()
requirements = checklist['requirements']
assert len({row['id'] for row in requirements}) == len(requirements)
assert {gate['id'] for gate in checklist['gates']} == set(range(1, 17))
reference = json.loads((ROOT / 'store/cognein-source-manifest.json').read_text())
reference_root = Path(reference['repository'])
for row in requirements:
    for field in ['reference', 'destinations', 'requiredBehavior', 'states', 'adaptiveBehavior', 'accessibility', 'verification', 'status']:
        assert row.get(field), f"{row['id']}: missing {field}"
    assert row['status'] in checklist['statuses']
    original = lines[row['sourceLine'] - 1]
    assert row['requirement'] in original or (original.startswith('|') and all(part.strip() in original for part in row['requirement'].split(': '))), row['id']
    for path in row['destinations']:
        assert (ROOT / path).exists(), f"{row['id']}: missing destination {path}"
    for path in row['reference']['cogneinFiles']:
        assert (reference_root / path).is_file(), f'Missing reference {path}'
    if row['status'] in ['locally verified', 'accepted']:
        assert row['verification']['evidence'], f"{row['id']}: no evidence"
    for evidence in row['verification']['evidence']:
        assert (ROOT / evidence).exists(), f'Missing evidence {evidence}'
# Every bullet and numbered action in the supplied plan must remain represented.
covered = {row['sourceLine'] for row in requirements}
import re
for number, line in enumerate(lines, 1):
    if line.startswith('- ') or re.match(r'^\d+\. ', line):
        assert number in covered, f'Untracked requirement at line {number}'
editorial = json.loads((ROOT / 'content/editorial-status.json').read_text())
allowed = {'not drafted', 'drafted', 'structurally validated', 'editorially reviewed', 'revised', 'accepted'}
for kind, count in [('lessons', 365), ('questions', 730), ('units', 73)]:
    assert len(editorial[kind]) == count, f'{kind}: incomplete editorial ledger'
    for entry in editorial[kind]:
        assert entry['status'] in allowed
        if entry['status'] in {'editorially reviewed', 'revised', 'accepted'}:
            assert entry['reviewer'], f'{kind}: reviewer missing'
        if entry['status'] == 'accepted':
            assert entry['acceptedAt'], f'{kind}: acceptance date missing'
assert [entry['day'] for entry in editorial['lessons']] == list(range(1, 366))
assert [entry['unit'] for entry in editorial['units']] == list(range(1, 74))
assert [entry['id'] for entry in editorial['questions']] == [f'day-{day:03}-q{q}' for day in range(1,366) for q in (1,2)]
print(f"{len(requirements)} requirements, 16 gates, 15 shared states: structure verified.")
print(dict(Counter(row['status'] for row in requirements)))
if args.release:
    outstanding = [row['id'] for row in requirements if row['status'] != 'accepted']
    gates = [gate['id'] for gate in checklist['gates'] if gate['status'] != 'accepted']
    assert not outstanding and not gates, f'Release blocked: {len(outstanding)} requirements and {len(gates)} gates not accepted.'
    content = json.loads((ROOT / 'content/teaching.json').read_text())
    assert len(content['lessons']) == 365 and sum(len(lesson['questions']) for lesson in content['lessons']) == 730
    editorial = json.loads((ROOT / 'content/editorial-status.json').read_text())
    for kind, count in [('lessons', 365), ('questions', 730), ('units', 73)]:
        assert len(editorial[kind]) == count
        assert all(row['status'] == 'accepted' and row['reviewer'] and row['acceptedAt'] for row in editorial[kind]), f'{kind}: editorial acceptance missing'
    print('Full acceptance gate passed.')
