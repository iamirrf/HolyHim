#!/usr/bin/env python3
"""Import a committed HolyHer revision into HolyHim, renamed, without touching HolyHer.

HolyHim runs on HolyHer's engine with its own brand, words, art and cloud
identity. This script reads one *committed* HolyHer revision with
`git archive` (never its uncommitted work, never writing to that repository),
renames HolyHer to HolyHim in paths and text, swaps HolyHer's cloud and
billing identifiers for HolyHim's, and records the result as a new commit on
the branch `upstream/holyher-renamed`. Merge that branch into `redesign/v2`
to pick up HolyHer's fixes, then rerun the generators (see README.md).

Paths HolyHim owns (OWNED) are never part of a sync, so its lessons, art,
voice, icons, store material, website and cloud identity are never overwritten.
HolyHer's Circle (EXCLUDED) never arrives: HolyHim has Brothers.
`--seed` copies the renamed HolyHer version of chosen owned paths into the
working tree once, as a starting point.

  python3 tool/sync_upstream.py                    # import HolyHer redesign/v2
  python3 tool/sync_upstream.py --commit 5ccc9bc   # import one revision
  python3 tool/sync_upstream.py --seed content     # seed an owned path
  python3 tool/sync_upstream.py --check            # report, change nothing
"""
from __future__ import annotations

import argparse
import io
import json
import os
import plistlib
import re
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BRANCH = 'upstream/holyher-renamed'

# Owned by HolyHim. Matched against renamed paths: a trailing slash means the
# whole folder, anything else is an exact file, `*` matches within a segment.
OWNED = (
    'AGENTS.md', 'README.md', 'DELIVERY.md', 'HolyHim_AppIcon_Set.zip', '.kilo/',
    'art/', 'assets/art/', 'assets/artwork/', 'assets/brand/',
    'config/', 'content/', 'docs/', 'store/', 'public/',
    'ios/Runner/GoogleService-Info.plist',
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/',
    'ios/Runner/Assets.xcassets/LaunchImage.imageset/',
    'ios/Runner/Assets.xcassets/LaunchBackground.imageset/',
    'ios/HolyHimWidget/Art/', 'ios/HolyHimWidget/WidgetVerses.json',
    'android/app/src/main/res/mipmap-*/',
    'lib/firebase_options.dart', 'lib/services/billing_config.dart',
    'lib/data/lessons.g.dart', 'lib/data/chapters.g.dart', 'tool/build_chapters.py', 'lib/design/art_catalog.dart',
    'lib/design/chapter_catalog.g.dart',
    'test/fixtures/',
    'tool/verify_site.cjs',  # tests HolyHim's own public/ pages
    # HolyHim's own voice, music, app icons and the words that carry its brand.
    'assets/audio/', 'assets/icons/',
    'ios/Runner/Assets.xcassets/AppIcon-*.appiconset/',
    'lib/services/app_icon.dart', 'lib/domain/milestones.dart',
    'lib/features/onboarding/onboarding_copy.dart', 'lib/features/onboarding/onboarding_moods.dart',
)
# Never needed in HolyHim even as a seed: HolyHer's art masters alone are
# about 470 MB, and its release evidence would be false for HolyHim.
NEVER_READ = ('art', 'store/screenshots', 'store/redesign-v3', 'HolyHer_AppIcon_Set.zip',
              'assets/audio',  # about 175 MB of HolyHer's narrator and music
              'store/voice-samples', 'store/creative')
# HolyHer's Circle. HolyHim has Brothers (lib/features/community, functions/community.js)
# in its place, so these never enter the import, not even as a seed.
EXCLUDED = ('lib/features/circle/', 'lib/services/circle.dart', 'functions/circle.js',
            'functions/test/circle.test.js', 'tool/render/circle_test.dart')
# Identifiers HolyHer states only in code. HolyHim's values come from
# config/revenuecat.json (memberEntitlementId) and config/release.json (appStoreId).
HER_CODE_ONLY = {'revenueCatMemberEntitlement': 'entlf63e788b71', 'appStoreId': '6828594137'}
# No value yet is a real state for these: the app shares its website until
# Apple assigns an App Store ID. They become empty, never a placeholder.
EMPTY_UNTIL_ASSIGNED = ('appStoreId',)

NAME = [('HOLYHER', 'HOLYHIM'), ('HolyHer', 'HolyHim'), ('Holyher', 'Holyhim'), ('holyHer', 'holyHim'),
        ('holyher', 'holyhim')]


def matches(path: str, rules: tuple[str, ...]) -> bool:
    for rule in rules:
        pattern = re.escape(rule).replace(r'\*', '[^/]*')
        if rule.endswith('/'):
            if re.match(pattern, path):
                return True
        elif re.fullmatch(pattern, path):
            return True
    return False


def owned(path: str) -> bool:
    return matches(path, OWNED)


def rename(text: str) -> str:
    for old, new in NAME:
        text = text.replace(old, new)
    return text


def git(*args: str, cwd: Path = ROOT, env: dict | None = None, data: bytes | None = None) -> bytes:
    result = subprocess.run(['git', *args], cwd=cwd, env=env, input=data, capture_output=True)
    if result.returncode:
        raise SystemExit(f"git {' '.join(args)} failed: {result.stderr.decode(errors='replace').strip()}")
    return result.stdout


def show(her: Path, sha: str, path: str) -> bytes | None:
    result = subprocess.run(['git', 'show', f'{sha}:{path}'], cwd=her, capture_output=True)
    return result.stdout if result.returncode == 0 else None


def identity_values(read) -> dict[str, str]:
    """Cloud and billing identifiers that differ between the two apps."""
    values: dict[str, str] = {}

    def from_json(path: str, keys: dict[str, str]) -> None:
        raw = read(path)
        if not raw:
            return
        data = json.loads(raw)
        for key, name in keys.items():
            if isinstance(data.get(key), str) and data[key]:
                values[name] = data[key]

    from_json('config/revenuecat.json', {'projectId': 'revenueCatProject', 'appId': 'revenueCatApp',
                                         'entitlementId': 'revenueCatEntitlement',
                                         'memberEntitlementId': 'revenueCatMemberEntitlement',
                                         'offeringId': 'revenueCatOffering', 'productId': 'revenueCatProduct'})
    from_json('config/revenuecat-public.json', {'iosPublicApiKey': 'revenueCatPublicKey'})
    from_json('config/cloud.json', {'firebaseIosAppId': 'firebaseIosApp'})
    from_json('config/release.json', {'appStoreId': 'appStoreId'})
    from_json('config/firebase-web.json', {'appId': 'firebaseWebApp', 'apiKey': 'firebaseWebApiKey'})
    raw = read('ios/Runner/GoogleService-Info.plist')
    if raw:
        plist = plistlib.loads(raw)
        for key, name in {'REVERSED_CLIENT_ID': 'googleReversedClient', 'CLIENT_ID': 'googleClient',
                          'API_KEY': 'firebaseIosApiKey', 'GOOGLE_APP_ID': 'firebaseIosApp',
                          'GCM_SENDER_ID': 'projectNumber'}.items():
            if isinstance(plist.get(key), str) and plist[key]:
                values[name] = plist[key]
    return values


def identity_map(her: Path, sha: str) -> list[tuple[str, str]]:
    theirs = {**HER_CODE_ONLY, **identity_values(lambda p: show(her, sha, p))}

    def ours_read(path: str) -> bytes | None:
        file = ROOT / path
        return file.read_bytes() if file.exists() else None

    ours = identity_values(ours_read)
    pairs = []
    for name, literal in theirs.items():
        if len(literal) < 8:
            continue
        replacement = ours.get(name) or ('' if name in EMPTY_UNTIL_ASSIGNED else
                                         f'REPLACE_WITH_HOLYHIM_{re.sub(r"(?<!^)(?=[A-Z])", "_", name).upper()}')
        if replacement != literal:
            pairs.append((literal, replacement))
    # Longest first, so client IDs are replaced before the project number inside them.
    return sorted(pairs, key=lambda pair: -len(pair[0]))


def transform(data: bytes, identity: list[tuple[str, str]]) -> bytes:
    if b'\0' in data[:8192]:
        return data
    try:
        text = data.decode('utf-8')
    except UnicodeDecodeError:
        return data
    text = rename(text)
    for old, new in identity:
        text = text.replace(old, new)
    return text.encode('utf-8')


def snapshot(her: Path, sha: str) -> tarfile.TarFile:
    pathspecs = ['.', *[f':(exclude){p}' for p in NEVER_READ]]
    raw = subprocess.run(['git', 'archive', '--format=tar', sha, '--', *pathspecs], cwd=her, capture_output=True)
    if raw.returncode:
        raise SystemExit('git archive failed: ' + raw.stderr.decode(errors='replace'))
    return tarfile.open(fileobj=io.BytesIO(raw.stdout))


def residue(text_files: dict[str, bytes], identity: list[tuple[str, str]]) -> list[str]:
    problems = []
    for path, data in text_files.items():
        if b'\0' in data[:8192]:
            continue
        text = data.decode('utf-8', errors='ignore')
        if re.search('holyher', text, re.I) or re.search('holyher', path, re.I):
            problems.append(f'{path}: still names HolyHer')
        for old, _ in identity:
            if old in text:
                problems.append(f'{path}: still holds a HolyHer identifier')
    return problems


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--holyher', type=Path, default=ROOT.parent / 'HolyHer')
    parser.add_argument('--commit', default='redesign/v2', help='HolyHer revision (committed only)')
    parser.add_argument('--parent', help='parent for the first import (default: HEAD)')
    parser.add_argument('--seed', nargs='+', metavar='PATH', help='copy renamed owned paths into the working tree')
    parser.add_argument('--force', action='store_true', help='let --seed replace existing files')
    parser.add_argument('--check', action='store_true', help='report what would change; write nothing')
    parser.add_argument('--trailer', action='append', default=[], help='extra commit message trailer')
    args = parser.parse_args()

    her = args.holyher.resolve()
    sha = git('rev-parse', '--verify', f'{args.commit}^{{commit}}', cwd=her).decode().strip()
    subject = git('log', '-1', '--format=%s', sha, cwd=her).decode().strip()
    identity = identity_map(her, sha)
    files: dict[str, tuple[bytes, int]] = {}
    with snapshot(her, sha) as tar:
        for member in tar.getmembers():
            if not member.isfile():
                continue
            path = rename(member.name)
            if matches(path, EXCLUDED):
                continue
            data = tar.extractfile(member).read()
            files[path] = (transform(data, identity), member.mode)

    if args.seed:
        wanted = [p.rstrip('/') for p in args.seed]
        written = skipped = 0
        for path, (data, mode) in sorted(files.items()):
            if not owned(path) or not any(path == w or path.startswith(w + '/') for w in wanted):
                continue
            target = ROOT / path
            if target.exists() and not args.force:
                skipped += 1
                continue
            if not args.check:
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(data)
                os.chmod(target, 0o755 if mode & 0o111 else 0o644)
            written += 1
        print(f'Seeded {written} file(s) from HolyHer {sha[:7]}; kept {skipped} existing.')
        return

    shared = {p: v for p, v in files.items() if not owned(p)}
    problems = residue({p: d for p, (d, _) in shared.items()}, identity)
    placeholders = sorted({new for _, new in identity if new.startswith('REPLACE_WITH_HOLYHIM')})

    previous = subprocess.run(['git', 'rev-parse', '--verify', '-q', f'refs/heads/{BRANCH}'],
                              cwd=ROOT, capture_output=True, text=True).stdout.strip()
    parent = previous or git('rev-parse', '--verify', f"{args.parent or 'HEAD'}^{{commit}}").decode().strip()
    with tempfile.TemporaryDirectory(prefix='holyhim-sync-') as temp:
        work = Path(temp) / 'tree'
        for path, (data, mode) in shared.items():
            target = work / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
            os.chmod(target, 0o755 if mode & 0o111 else 0o644)
        env = {**os.environ, 'GIT_INDEX_FILE': str(Path(temp) / 'index')}
        git('read-tree', '--empty', env=env)
        git(f'--work-tree={work}', 'add', '-A', '-f', '.', env=env)
        tree = git('write-tree', env=env).decode().strip()
    parent_tree = git('rev-parse', f'{parent}^{{tree}}').decode().strip()
    print(f'HolyHer {sha[:7]} "{subject}": {len(shared)} shared files, {len(files) - len(shared)} owned files left alone.')
    for literal, replacement in identity:
        print(f'  identity {literal[:12]}… -> {replacement[:40] or "(empty until assigned)"}')
    for problem in problems[:40]:
        print('  WARNING', problem)
    if placeholders:
        print(f'  {len(placeholders)} HolyHim identifier(s) are still placeholders; fill config/ and resync.')
    if tree == parent_tree:
        print(f'{BRANCH} already matches HolyHer {sha[:7]}.')
        return
    if args.check:
        print('Check only: no commit written.')
        return
    message = (f'Import HolyHer {sha[:7]} renamed to HolyHim\n\n'
               f'Source: HolyHer redesign/v2 {sha} ("{subject}").\n'
               'Written by tool/sync_upstream.py: shared code only, HolyHer named\n'
               'HolyHim, cloud and billing identifiers swapped for HolyHim\'s.\n'
               'HolyHim-owned paths are not part of this branch.\n')
    if args.trailer:
        message += '\n' + '\n'.join(args.trailer) + '\n'
    commit = git('commit-tree', tree, '-p', parent, data=message.encode()).decode().strip()
    git('update-ref', f'refs/heads/{BRANCH}', commit, previous or '0' * 40)
    print(f'{BRANCH} -> {commit[:7]}. Next: git merge {BRANCH}, then rerun the generators.')
    if problems:
        sys.exit(2)


if __name__ == '__main__':
    main()
