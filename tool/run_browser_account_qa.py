"""Run local authenticated browser QA on the retained journey QA account only."""
import os,subprocess
from prepare_review_accounts import read_secret
_,credential=read_secret('journey')
import json
result=subprocess.run(['node','tool/browser_account_qa.cjs'],input=json.dumps({'email':credential['email'],'password':credential['password']}),text=True,env={**os.environ,'HOLYHER_PLAYWRIGHT':'/tmp/holyher-browser-qa/node_modules/playwright'})
raise SystemExit(result.returncode)
