"""Exercise the deployed free flow on the retained journey QA account only.

Requires --run-qa-flow because it creates real QA journey/attempt activity.
Never resets/deletes an account, fabricates purchase ownership, or logs secrets.
"""
import argparse
import json
import plistlib
import urllib.error
import urllib.request
import uuid
from pathlib import Path
from prepare_review_accounts import read_secret, http, AUTH

ROOT = Path(__file__).resolve().parents[1]
PROJECT = 'holyher-app-production'
BASE = f'https://us-central1-{PROJECT}.cloudfunctions.net/'
DOCS = f'https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents/'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--run-qa-flow', action='store_true', required=True)
parser.parse_args()
report = {'project': PROJECT, 'qaRole': 'journey', 'checks': [], 'customerAccountsModified': False,
          'purchaseOwnershipWritten': False, 'credentialsLogged': False}
output = ROOT / 'store/rebuild-test-results/free-flow-live-verification.json'

def checked(name, condition):
    if not condition:
        raise RuntimeError(name + ' did not pass')
    report['checks'].append({'check': name, 'passed': True})
    print('PASS:', name, flush=True)

def fields(data):
    return {key: {'nullValue': None} if value is None else {'booleanValue': value} if isinstance(value, bool)
            else {'integerValue': str(value)} if isinstance(value, int) else {'stringValue': value}
            for key, value in data.items()}

try:
    _, credential = read_secret('journey')
    native = plistlib.loads((ROOT / 'ios/Runner/GoogleService-Info.plist').read_bytes())
    assert native['PROJECT_ID'] == PROJECT and native['BUNDLE_ID'] == 'com.holyher.app'
    signed = http('POST', AUTH + 'accounts:signInWithPassword?key=' + native['API_KEY'],
                  {'email': credential['email'], 'password': credential['password'], 'returnSecureToken': True})
    assert signed['localId'] == credential['uid']
    token, uid = signed['idToken'], credential['uid']
    def request(method, url, data=None, expected=200, authenticated=True):
        headers = {'Content-Type': 'application/json'}
        if authenticated:
            headers['Authorization'] = 'Bearer ' + token
        req = urllib.request.Request(url, method=method, headers=headers,
                                     data=None if data is None else json.dumps(data).encode())
        try:
            with urllib.request.urlopen(req, timeout=60) as response:
                status, raw = response.status, response.read()
        except urllib.error.HTTPError as error:
            status, raw = error.code, error.read()
        if status != expected:
            raise RuntimeError(f'Live request returned HTTP {status}, expected {expected}')
        return json.loads(raw) if raw else {}
    def call(name, data=None):
        value = request('POST', BASE + name, {'data': data or {}})
        if 'result' not in value:
            raise RuntimeError(name + ' returned no callable result')
        return value['result']
    def doc(path, **kwargs):
        return request('GET', DOCS + f'users/{uid}/' + path, **kwargs)

    access = call('getAccessStatus')
    checked('No-purchase QA account is eligible for free enrollment', access['eligible'] and not access['genuinePurchase'])
    journey = call('startJourney', {'timeZone': 'America/New_York'})
    checked('Server acknowledges free journey creation', journey['started'] and journey['revision'] >= 1)
    access = call('getAccessStatus')
    checked('Retained edition grant is distinct from genuine purchase', access['retainedGrant'] and not access['genuinePurchase'])
    again = call('startJourney', {'timeZone': 'UTC'})
    checked('Repeated start preserves date, timezone and existing progress', all(again[key] == journey[key] for key in ['startDate', 'timeZone', 'completedDays', 'revision']))

    profile = {'name': 'QA Journey', 'familiarity': 'new', 'focus': 'peace', 'obstacle': 'busy',
               'reminderMinutes': None, 'onboardingComplete': True, 'haptics': True, 'sounds': True,
               'tips': True, 'largerText': False, 'onboardingVersion': 2, 'onboardingStepId': 'day-one', 'onboardingStep': 9}
    request('PATCH', DOCS + f'users/{uid}', {'fields': fields(profile)})
    checked('Deployed rules accept the current onboarding profile schema', True)
    request('GET', DOCS + f'users/{uid}', expected=403, authenticated=False)
    checked('Unauthenticated profile read is denied', True)

    catalog = json.loads((ROOT / 'functions/teaching.json').read_text())
    questions = catalog['lessons'][0]['questions']
    attempt = {'attemptId': 'qa-free-' + str(uuid.uuid4()), 'day': 1, 'contentVersion': catalog['version'],
               'journeyRevision': journey['revision'], 'selectedOptionIds': {},
               'optionOrder': {q['id']: [o['id'] for o in q['options']] for q in questions}}
    prior = request('GET', DOCS + f'users/{uid}/resumes/day-1', expected=404 if not journey['completedDays'] else 200)
    revision = int(prior.get('fields', {}).get('checkpointRevision', {}).get('integerValue', 0))
    resume = {'checkpointId': 'qa-checkpoint-' + str(uuid.uuid4()), 'stepId': 'question-1', 'renderedPart': 0, 'attempt': attempt}
    saved = call('saveLessonResume', {'expectedRevision': revision, 'resume': resume})
    checked('Current guided checkpoint API accepts the real lesson structure', saved['accepted'])
    attempt['selectedOptionIds'] = {questions[0]['id']: next(o['id'] for o in questions[0]['options'] if o['id'] != questions[0]['correctOptionId']),
                                    questions[1]['id']: questions[1]['correctOptionId']}
    result = call('completeLessonAttempt', attempt)
    checked('Live canonical grading accepts one mistake and completes Day 1', result['correctCount'] == 1 and result['questionCount'] == 2 and 1 in result['completedDays'])
    duplicate = call('completeLessonAttempt', attempt)
    checked('Retrying the same attempt is idempotent', duplicate == result)
    current = call('getJourney')
    checked('Journey read-back preserves the start and completion', current['startDate'] == journey['startDate'] and set(current['completedDays']) == set(journey['completedDays']) | {1})
    checked('Delayed checkpoint cannot restore the completed attempt', not call('saveLessonResume', {'expectedRevision': saved['checkpointRevision'], 'resume': resume})['accepted'])
    doc('attempts/' + attempt['attemptId'])
    checked('Owner can read the server-graded attempt under deployed rules', True)

    operation = {'day': 1, 'saved': True, 'operationId': 'qa-bookmark-' + str(uuid.uuid4())}
    receipt = call('setSavedLesson', operation)
    call('setSavedLesson', {'day': 1, 'saved': False, 'operationId': 'qa-bookmark-' + str(uuid.uuid4())})
    checked('Bookmark retries return canonical timestamps', call('setSavedLesson', operation)['savedAt'] == receipt['savedAt'])
    catalog_doc = doc('private/savedCatalog')
    checked('Replaying an old save cannot resurrect a removed bookmark', 'nullValue' in catalog_doc['fields']['days']['mapValue']['fields']['1'])
    report['passed'] = True
except Exception as error:
    report['passed'] = False
    report['failure'] = str(error) if isinstance(error, (RuntimeError, AssertionError)) else type(error).__name__
    print('FAIL:', report['failure'], flush=True)
finally:
    output.write_text(json.dumps(report, indent=2) + '\n')
raise SystemExit(0 if report['passed'] else 1)
