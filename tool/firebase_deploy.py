"""Deploy HolyHim without printing verbose SDK/configuration response bodies."""
import argparse, re, subprocess, sys
p=argparse.ArgumentParser();p.add_argument('--only',required=True)
# --force accepts a retry-on-failure policy (the Circle triggers have one),
# which the CLI will not turn on unattended otherwise.
p.add_argument('--force',action='store_true');args=p.parse_args()
process=subprocess.Popen(['firebase','deploy','--only',args.only,'--project','holyhim-app-production','--account','iamirrf1@gmail.com','--non-interactive']+(['--force'] if args.force else []),stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,bufsize=1)
for line in process.stdout:
 if re.match(r'^\[\d{4}-\d\d-\d\dT',line):continue
 print(re.sub(r'\bsk_[A-Za-z0-9_-]+','[redacted secret]',line),end='',flush=True)
sys.exit(process.wait())
