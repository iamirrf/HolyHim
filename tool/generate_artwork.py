"""Versioned HolyHer Gemini artwork batches. Requires GEMINI_API_KEY only for live generation.

python3 tool/generate_artwork.py --dry-run --days 1-365
python3 tool/generate_artwork.py --days 1-5 --max-images 5 --reference /path/to/approved-composition.png
python3 tool/generate_artwork.py --days 1-365 --resume --max-images 20 --reference /path/to/approved-composition.png

The model default follows https://aistudio.google.com/docs/image-generation
(as checked November 2, 2026); override --model when a model is retired.
Generated files require review before approval/publication. No text is generated.
"""
import argparse,base64,datetime,hashlib,json,os,random,shutil,tempfile,time,urllib.error,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
VERSION='v1'
DEFAULT_MODEL='gemini-3-pro-image'
BRIEF="""HolyHer editorial devotional art. A luminous pearl-white and muted blush still life, warm champagne daylight, fine natural fabric, one or two botanicals, gentle realistic shadows. Feminine, quiet, tactile, refined photographic art. No words, lettering, symbols, logos, faces, hands, or rendered UI. Portrait 9:16. Keep the upper and central 70 percent very light and nearly empty so application-rendered dark plum text can remain clear. Objects sit near lower corners. Match the reference composition's light, scale, restraint, palette and negative space. Each lesson needs a distinct arrangement, not a duplicate."""
OBJECTS=['a white peony with a single olive sprig','a blush rose on folded ivory linen','a slender olive branch beside a pearl-white ceramic bowl','small white cosmos flowers on translucent fabric','a pale magnolia petal near a soft linen ribbon','an ivory ranunculus and a sprig of eucalyptus','a single champagne rose with an olive leaf','a white anemone beside draped pearl silk','delicate almond blossoms on warm white stone','a soft blush tulip and a curved linen fold','a small olive branch in a matte ivory vase','a pale garden rose and a scattering of white petals']
ANGLES=['soft daylight from the upper left','diffused morning light from the right','a gentle backlight with a warm shadow','overcast window light with barely visible shadows','a narrow band of morning light across the bottom']
def atomic(path,value):
 path.parent.mkdir(parents=True,exist_ok=True)
 with tempfile.NamedTemporaryFile('w',dir=path.parent,delete=False,encoding='utf-8') as file:json.dump(value,file,ensure_ascii=False,indent=2);file.write('\n');name=file.name
 os.replace(name,path)
def days(value):
 result=set()
 for part in value.split(','):
  bounds=part.split('-');a=int(bounds[0]);b=int(bounds[-1]);result.update(range(a,b+1))
 if not result or min(result)<1 or max(result)>365:raise argparse.ArgumentTypeError('Use days 1–365, for example 1-5,12,30.')
 return sorted(result)
def digest(data):return hashlib.sha256(data).hexdigest()
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--dry-run',action='store_true');parser.add_argument('--days',type=days,default=days('1-365'));parser.add_argument('--resume',action='store_true');parser.add_argument('--model',default=DEFAULT_MODEL);parser.add_argument('--max-images',type=int,default=365);parser.add_argument('--reference',type=Path);parser.add_argument('--retries',type=int,default=3);args=parser.parse_args()
 if args.max_images<0 or args.retries<0:parser.error('Limits must be nonnegative.')
 manifest_path=ROOT/'assets/artwork/manifest.json'
 existing=json.loads(manifest_path.read_text()) if manifest_path.exists() else {'schemaVersion':1,'assetVersion':VERSION,'composition':BRIEF,'documentation':'https://aistudio.google.com/docs/image-generation','assets':{}}
 reference=args.reference.read_bytes() if args.reference else None
 if reference and args.reference.suffix.lower() not in ['.png','.jpg','.jpeg','.webp']:parser.error('Reference must be PNG, JPEG, or WebP.')
 catalog=json.loads((ROOT/'content/readings.json').read_text())
 for day in args.days:
  row=catalog[day-1];key=f'{day:03d}';prompt=f"{BRIEF}\nLesson {day}: {row['title']}. Scripture reference: {row['reference']}. Still life: {OBJECTS[(day-1)%len(OBJECTS)]}; {ANGLES[(day-1)//len(OBJECTS)%len(ANGLES)]}. Arrangement seed {day}: cloth folded in {1+(day%4)} loose curves, botanicals near the {'lower left' if day%2 else 'lower right'} corner. Preserve clear center space."
  old=existing['assets'].get(key,{})
  if args.resume and old.get('status') in ['generated','approved']:
   path=ROOT/old['path']
   if path.is_file() and digest(path.read_bytes())==old.get('sha256'):continue
  entry={**old,'day':day,'prompt':prompt,'model':args.model,'revision':old.get('revision',0)+(0 if old.get('prompt')==prompt and old.get('model')==args.model else 1),'referenceSha256':digest(reference) if reference else old.get('referenceSha256'),'compositionRevision':1,'status':'planned','reviewStatus':'not-generated','path':f'public/artwork/{VERSION}/day-{key}.webp'}
  if old.get('status') in ['generated','approved'] and old.get('prompt')==prompt and old.get('model')==args.model:entry=old
  existing['assets'][key]=entry
 atomic(manifest_path,existing)
 if args.dry_run:print(f"Dry run: prepared {len(args.days)} prompts; no API calls or images generated.");return
 api_key=os.environ.get('GEMINI_API_KEY')
 if not api_key:parser.error('Set GEMINI_API_KEY outside the repository. The manifest is prepared; no request was sent.')
 if reference is None:parser.error('Use --reference with an approved portrait composition before generating a batch.')
 try:from PIL import Image,ImageOps
 except ImportError:parser.error('Live optimization requires Pillow (python3 -m pip install Pillow).')
 generated=0
 attempted=0
 try:
  for day in args.days:
   if attempted>=args.max_images:break
   entry=existing['assets'][f'{day:03d}'];target=ROOT/entry['path']
   if args.resume and entry.get('status') in ['generated','approved'] and target.exists() and digest(target.read_bytes())==entry.get('sha256'):continue
   attempted+=1
   if entry.get('status')=='approved':
    entry['revision']+=1;entry['path']=f"public/artwork/{VERSION}/day-{day:03d}-r{entry['revision']}.webp";target=ROOT/entry['path']
   entry['status']='generating';atomic(manifest_path,existing)
   mime='image/jpeg' if args.reference.suffix.lower() in ['.jpg','.jpeg'] else 'image/webp' if args.reference.suffix.lower()=='.webp' else 'image/png'
   body={'contents':[{'parts':[{'text':entry['prompt']},{'inlineData':{'mimeType':mime,'data':base64.b64encode(reference).decode()}}]}],'generationConfig':{'responseModalities':['TEXT','IMAGE'],'imageConfig':{'aspectRatio':'9:16','imageSize':'1K'}}}
   success=False
   for attempt in range(args.retries+1):
    try:
     request=urllib.request.Request(f'https://generativelanguage.googleapis.com/v1beta/models/{args.model}:generateContent',headers={'Content-Type':'application/json','x-goog-api-key':api_key},data=json.dumps(body).encode())
     with urllib.request.urlopen(request,timeout=180) as response:result=json.load(response)
     parts=[p for c in result.get('candidates',[]) for p in c.get('content',{}).get('parts',[]) if p.get('inlineData',{}).get('mimeType','').startswith('image/')]
     if not parts:raise RuntimeError('Response contained no image; the entry is retained for retry.')
     data=base64.b64decode(parts[0]['inlineData']['data']);target.parent.mkdir(parents=True,exist_ok=True)
     import io
     img=ImageOps.exif_transpose(Image.open(io.BytesIO(data))).convert('RGB')
     if abs(img.width/img.height-9/16)>.03:raise RuntimeError('Image is not portrait 9:16.')
     img.thumbnail((1080,1920))
     temp=target.with_suffix('.tmp');img.save(temp,'WEBP',quality=86,method=6);os.replace(temp,target)
     entry.update(status='generated',reviewStatus='needs-review',sha256=digest(target.read_bytes()),sourceSha256=digest(data),width=img.width,height=img.height,bytes=target.stat().st_size,generatedAt=datetime.datetime.now(datetime.timezone.utc).isoformat())
     entry.pop('lastError',None);generated+=1;success=True;print(f'Generated Day {day}; review required.',flush=True);break
    except (urllib.error.URLError,TimeoutError,RuntimeError,ValueError) as error:
     status=getattr(error,'code',None);entry['lastError']=f'HTTP {status}' if status else type(error).__name__
     if attempt>=args.retries or status in [400,401,403,404]:break
     time.sleep(min(30,2**attempt+random.random()))
   if not success:entry.update(status='failed',reviewStatus='not-generated');print(f'Day {day} failed; resume can retry.',flush=True)
   atomic(manifest_path,existing)
 finally:atomic(manifest_path,existing)
 print(f'Generated {generated} images. Approval and publishing are separate review steps.')
if __name__=='__main__':main()
