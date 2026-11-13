"""Compile, publish, and read back HolyHim rules using the owner's gcloud login.

Tokens remain in memory. This changes the production rules only with --deploy.
"""
import argparse
import hashlib
import json
import subprocess
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = 'holyhim-app-production'

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--deploy', action='store_true', required=True)
    parser.parse_args()
    token = subprocess.run(['gcloud', 'auth', 'print-access-token',
        '--account=iamirrf1@gmail.com', '--verbosity=error'],
        check=True, capture_output=True, text=True).stdout.strip()
    base = f'https://firebaserules.googleapis.com/v1/projects/{PROJECT}'
    def call(method, suffix, body=None):
        request = urllib.request.Request(base + suffix, method=method,
            headers={'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json',
                'x-goog-user-project': PROJECT},
            data=None if body is None else json.dumps(body).encode())
        with urllib.request.urlopen(request, timeout=45) as response:
            return json.load(response)
    content = (ROOT / 'firestore.rules').read_text()
    source = {'files': [{'name': 'firestore.rules', 'content': content}]}
    compiled = call('POST', ':test', {'source': source})
    if any(issue.get('severity') == 'ERROR' for issue in compiled.get('issues', [])):
        raise RuntimeError('Rules compilation failed; production unchanged.')
    created = call('POST', '/rulesets', {'source': source})
    name = f'projects/{PROJECT}/releases/cloud.firestore'
    call('PATCH', '/releases/cloud.firestore', {'release': {
        'name': name, 'rulesetName': created['name']}, 'updateMask': 'rulesetName'})
    release = call('GET', '/releases/cloud.firestore')
    assert release['rulesetName'] == created['name']
    fetched = call('GET', '/rulesets/' + created['name'].rsplit('/', 1)[-1])
    assert fetched['source']['files'][0]['content'] == content
    report = {'project': PROJECT, 'ruleset': created['name'],
        'sha256': hashlib.sha256(content.encode()).hexdigest(),
        'compiled': True, 'deployed': True, 'readBackMatches': True,
        'release': release}
    (ROOT / 'store/rules-deployment.json').write_text(json.dumps(report, indent=2) + '\n')
    print('Rules compiled, deployed, and read-back verified for HolyHim production.')

if __name__ == '__main__':
    main()
