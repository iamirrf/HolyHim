"""Apply a sequential, individually authored prose batch and verify its record."""
import argparse,hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('batch',type=Path);a=p.parse_args()
patches=json.loads(a.batch.read_text());content=ROOT/'content/lessons_v2.json'
lessons=json.loads(content.read_text());statusPath=ROOT/'content/v2-editorial-status.json';status=json.loads(statusPath.read_text())
start=max(status.get('newlyAuthoredDays',[]),default=0)+1
assert 1<=len(patches)<=28 and [x['day'] for x in patches]==list(range(start,start+len(patches))), 'Batch must continue the approved sequence, at most 28 days.'
for patch in patches:
 assert set(patch)=={'day','meaning','heart','holdOn','prayer'},'Prose fields only; Scripture and lesson identity must be preserved.'
 lesson=lessons[patch['day']-1];lesson.update(patch);lesson['teaser']=patch['holdOn']
content.write_text(json.dumps(lessons,ensure_ascii=False,indent=2)+'\n')
status['newlyAuthoredDays']=list(range(1,start+len(patches)));status['adaptedDraftDays']=list(range(start+len(patches),366))
status['voiceReviewComplete']=False;status['sourceSha256']=hashlib.sha256(content.read_bytes()).hexdigest()
status.setdefault('redesignBatches',[]).append({'from':start,'to':start+len(patches)-1,'sourceSha256':status['sourceSha256'],'mechanicallyValidated':False})
statusPath.write_text(json.dumps(status,ensure_ascii=False,indent=2)+'\n')
print(f'Authored days {start}–{start+len(patches)-1}; validators must now pass.')
