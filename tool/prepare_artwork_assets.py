"""Validate reviewed Gemini files and prepare versioned public/bundled assets.

Use --approve only after visually inspecting the requested days. This never
calls an image model or deploys Hosting. Publication still follows release QA.
"""
import argparse,json,hashlib,shutil
from pathlib import Path
from generate_artwork import days,atomic
ROOT=Path(__file__).resolve().parents[1]
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--approve',type=days,default=[]);args=parser.parse_args()
 path=ROOT/'assets/artwork/manifest.json';manifest=json.loads(path.read_text())
 for day in args.approve:
  asset=manifest['assets'][f'{day:03d}'];file=ROOT/asset['path']
  assert asset['status'] in ['generated','approved'] and file.is_file(),f'Day {day} is not generated.'
  assert hashlib.sha256(file.read_bytes()).hexdigest()==asset['sha256'],f'Day {day} checksum differs.'
  asset.update(status='approved',reviewStatus='approved')
 approved={key:{k:value for k,value in asset.items() if k in ['day','revision','sha256','width','height','bytes','status','reviewStatus']} for key,asset in manifest['assets'].items() if asset.get('reviewStatus')=='approved'}
 for key in approved:
  asset=manifest['assets'][key];file=ROOT/asset['path']
  assert hashlib.sha256(file.read_bytes()).hexdigest()==asset['sha256']
  if asset['day']<=5:shutil.copy2(file,ROOT/f'assets/artwork/day-{key}.webp')
 atomic(path,manifest)
 atomic(ROOT/'public/artwork/v1/manifest.json',{'schemaVersion':1,'assetVersion':'v1','assets':approved})
 bundled=sum(1 for asset in approved.values() if asset['day']<=5)
 print(f'Validated {len(approved)} approved assets; {bundled} initial slots bundled. No deployment performed.')
if __name__=='__main__':main()
