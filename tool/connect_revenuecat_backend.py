"""Validate a HolyHim v2 key and configure its server secrets without local storage."""
from getpass import getpass
from pathlib import Path
import argparse, json, re, secrets, subprocess, urllib.request, urllib.error, urllib.parse

CLOUD=json.loads((Path(__file__).resolve().parents[1]/'config/cloud.json').read_text())
PROJECT=CLOUD['projectId'];ACCOUNT=CLOUD['account'];RC_PROJECT='proj1b08bf4e'
BASE=['npx','--yes','@revenuecat/cli@0.1.7']
def verify_projects(data):
    return any(item.get('id')==RC_PROJECT for item in data.get('items',[]))
def validate_key(key):
    if not key.startswith('sk_'):raise SystemExit('Use a v2 secret server key starting sk_, not a public app SDK key.')
    url='https://api.revenuecat.com/v2/projects'
    for _ in range(25):
        request=urllib.request.Request(url,headers={'Authorization':'Bearer '+key,'User-Agent':'HolyHim-release-setup/1.0'})
        try:
            with urllib.request.urlopen(request,timeout=30) as response:data=json.load(response)
        except urllib.error.HTTPError as error:
            try:message=json.loads(error.read()).get('message','')
            except Exception:message=''
            message=re.sub(r'\bsk_[A-Za-z0-9_-]+','[redacted]',message)
            raise SystemExit(f'RevenueCat key validation returned HTTP {error.code}: {message[:300]}. Check Projects read and Customer information read/write permissions.')
        if verify_projects(data):return
        next_page=data.get('next_page')
        if not next_page:break
        parsed=urllib.parse.urlparse(next_page)
        if parsed.scheme!='https' or parsed.netloc!='api.revenuecat.com' or parsed.path!='/v2/projects':raise SystemExit('Unexpected RevenueCat pagination URL.')
        url=next_page
    raise SystemExit('This key cannot access the HolyHim RevenueCat project. Create it inside HolyHim.')
def cloud_command(*arguments):
    return ['gcloud',*arguments,'--project='+PROJECT,'--account='+ACCOUNT]
def put_secret(name,value):
    exists=subprocess.run(cloud_command('secrets','describe',name,'--format=value(name)'),capture_output=True,text=True)
    if exists.returncode:
        subprocess.run(cloud_command('secrets','create',name,'--replication-policy=automatic'),check=True,capture_output=True,text=True)
    subprocess.run(cloud_command('secrets','versions','add',name,'--data-file=-'),input=value,text=True,check=True,capture_output=True)
def configure(key):
    validate_key(key)
    print('Verified HolyHim RevenueCat access. Saving to',PROJECT,'using',ACCOUNT)
    put_secret('REVENUECAT_SECRET_API_KEY',key)
    previous=subprocess.run(cloud_command('secrets','versions','access','latest','--secret=REVENUECAT_WEBHOOK_SECRET'),capture_output=True,text=True)
    webhook=previous.stdout.strip() if previous.returncode==0 else secrets.token_urlsafe(32)
    if previous.returncode:put_secret('REVENUECAT_WEBHOOK_SECRET',webhook)
    result=subprocess.run(BASE+['webhooks','list','--project-id',RC_PROJECT,'--json','--no-input'],check=True,capture_output=True,text=True)
    existing=[item for item in json.loads(result.stdout)['data'].get('items',[]) if item.get('name')=='HolyHim backend']
    path='/projects/'+RC_PROJECT+'/integrations/webhooks'+('/'+existing[0]['id'] if existing else '')
    body={'name':'HolyHim backend','url':'https://us-central1-'+PROJECT+'.cloudfunctions.net/revenuecatWebhook','authorization_header':'Bearer '+webhook}
    subprocess.run(BASE+['api','POST',path,'--body','@-','--json'],input=json.dumps(body),check=True,capture_output=True,text=True)
    print('SUCCESS: HolyHim server key and authenticated billing webhook are configured. No credentials were written to local files.')
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true',help='Check the real project-list route using the existing CLI login; no secrets or changes.');args=parser.parse_args()
    if args.check:
        result=subprocess.run(BASE+['api','GET','/projects','--json'],check=True,capture_output=True,text=True)
        decoded=json.loads(result.stdout)
        data=decoded.get('data',decoded)
        if not verify_projects(data):raise SystemExit('The CLI login cannot access HolyHim.')
        print('PASS: RevenueCat project-list endpoint and HolyHim project verified. Target cloud account:',ACCOUNT,'project:',PROJECT)
        return
    configure(getpass('HolyHim RevenueCat v2 secret API key (hidden): ').strip())
if __name__=='__main__':main()
