#!/usr/bin/env python3
"""Capture only the isolated preview app. No account credentials or UI automation outside QA."""
import argparse,json,subprocess,time,shutil,hashlib
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--device',required=True);p.add_argument('--routes',nargs='+',default=[f'{a}-{b}' for a in 'ABC' for b in ['welcome','learn','scripture']]);p.add_argument('--scale',type=float,default=1);p.add_argument('--motion',action='store_true');p.add_argument('--record-video',action='store_true');p.add_argument('--orientation',choices=['portrait','landscape'],default='portrait');p.add_argument('--viewport',choices=['full','split'],default='full');p.add_argument('--output',default='store/pearl-redesign/gallery');args=p.parse_args()
out=Path(args.output);out.mkdir(parents=True,exist_ok=True)
# Use the Simulator's own orientation menu. iPad multitasking deliberately ignores
# application orientation locks; a landscape label must follow real device rotation.
subprocess.run(['open','-a','Simulator','--args','-CurrentDeviceUDID',args.device],check=True)
orientation_name='Landscape Left' if args.orientation=='landscape' else 'Portrait'
script=f'tell application "System Events" to tell process "Simulator" to click menu item "{orientation_name}" of menu "Orientation" of menu item "Orientation" of menu "Device" of menu bar 1'
subprocess.run(['osascript','-e',script],check=True)
time.sleep(1)

def run(*cmd):return subprocess.check_output(cmd,text=True,timeout=80).strip()
app=Path(run('xcrun','simctl','get_app_container',args.device,'com.holyhim.app','app'))
artifact=app/'Frameworks/App.framework/flutter_assets/kernel_blob.bin'
if not artifact.exists():artifact=app/'Frameworks/App.framework/App'
artifact_sha=hashlib.sha256(artifact.read_bytes()).hexdigest()
container=Path(run('xcrun','simctl','get_app_container',args.device,'com.holyhim.app','data'))
for route in args.routes:
 ready=container/'tmp/preview-ready.json';errors=container/'tmp/preview-errors.txt';ready.unlink(missing_ok=True);errors.unlink(missing_ok=True)
 name=f'{route.replace(":","-")}--{args.device[:8]}--s{args.scale:g}{'-motion' if args.motion else '-reduced' if args.record_video else ''}{'-landscape' if args.orientation=='landscape' else ''}{'-split' if args.viewport=='split' else ''}'
 recorder=None
 if args.motion or args.record_video:
  recorder=subprocess.Popen(['xcrun','simctl','io',args.device,'recordVideo','--codec=h264','--force',str(out/f'{name}.mp4')],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
 run('xcrun','simctl','launch','--terminate-running-process',args.device,'com.holyhim.app',f'--holyhim-preview={route}',f'--holyhim-scale={args.scale}',f'--holyhim-motion={str(args.motion).lower()}',f'--holyhim-orientation={args.orientation}',f'--holyhim-viewport={args.viewport}')
 deadline=time.monotonic()+100
 while not ready.exists() and time.monotonic()<deadline:time.sleep(.25)
 if not ready.exists():
  if recorder:recorder.send_signal(2);recorder.wait()
  raise RuntimeError(f'{route} never reached ready: {errors.read_text() if errors.exists() else "inspect simulator log"}')
 time.sleep(2)
 metadata=json.loads(ready.read_text())
 if metadata['route']!=route:raise RuntimeError(f'Expected {route}, rendered {metadata["route"]}')
 metadata['nativeSpecimen']=f'native-rounded-specimen--{args.device[:8]}.png';metadata['artifactSha256']=artifact_sha;metadata['simulator']=args.device;metadata['capture']='simctl native iOS screenshot';metadata['errors']=errors.read_text() if errors.exists() else ''
 subprocess.run(['xcrun','simctl','io',args.device,'screenshot',str(out/f'{name}.png')],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
 if args.viewport=='split':
  from PIL import Image
  full=out/f'{name}-full-window.png';shutil.copy2(out/f'{name}.png',full)
  im=Image.open(full);dpr=metadata['devicePixelRatio'];im.crop((0,0,round(metadata['pixelWidth']),round(metadata['pixelHeight']))).save(out/f'{name}.png')
  metadata['capture']='native iOS UIKit child viewport cropped from retained full-window screenshot';metadata['fullWindowScreenshot']=full.name
 if recorder:recorder.send_signal(2);recorder.wait()
 (out/f'{name}.json').write_text(json.dumps(metadata,indent=2))
 print(route,metadata['logicalWidth'],metadata['logicalHeight'],'ERROR' if metadata['errors'] else 'OK',flush=True)
 if metadata['errors']:print(metadata['errors'],flush=True)
for file in ['native-rounded-specimen.png']:
 if (container/'tmp'/file).exists():shutil.copy2(container/'tmp'/file,out/f'native-rounded-specimen--{args.device[:8]}.png');shutil.copy2(container/'tmp'/file,out/file)
