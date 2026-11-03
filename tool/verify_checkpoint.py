"""Read-only integrity check for the recorded working tree and preserved inputs."""
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = 'store/rebuild-test-results/persistence-source-manifest.json'

def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()

snapshot = json.loads((ROOT / MANIFEST).read_text())
paths = subprocess.check_output(['git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard'], cwd=ROOT).decode().split('\0')
current = {name for name in paths if name and name != MANIFEST and (ROOT / name).is_file()}
recorded = {row['path'] for row in snapshot['files']}
assert current == recorded, f'Source inventory changed: added {current-recorded}; removed {recorded-current}'
for row in snapshot['files']:
    assert digest(ROOT / row['path']) == row['sha256'], f"Checkpoint mismatch: {row['path']}"
for row in json.loads((ROOT / 'store/rebuild-test-results/preserved-native-artifacts.json').read_text()):
    assert digest(ROOT / row['path']) == row['sha256'], f"Preserved artifact changed: {row['path']}"
reference = json.loads((ROOT / 'store/cognein-source-manifest.json').read_text())
for row in reference['files']:
    assert digest(Path(reference['repository']) / row['path']) == row['sha256'], f"Reference changed: {row['path']}"
environment = json.loads((ROOT / 'store/rebuild-test-results/environment.json').read_text())
for name, value in environment['dependencyLocks'].items():
    assert digest(ROOT / name) == value, f'Dependency lock changed: {name}'
archive = Path(environment['checkpoint']) / 'source.tar.gz'
assert digest(archive) == environment['checkpointSha256'], 'Original source archive changed'
print(f"Verified {len(recorded)} working-tree/evidence files, original archive/IPA contents, dependency locks, Cognein reference, and pre-edit source archive.")
print('This establishes integrity of the development checkpoint, not release acceptance.')
