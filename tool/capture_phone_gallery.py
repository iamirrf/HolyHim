#!/usr/bin/env python3
"""Capture explicitly invoked HolyHim QA states on the connected physical iPhone.

Uses the installed app's non-release diagnostic branch, memory-only fixtures,
and Xcode Devices screenshots. Restores the actual app at the end of the batch.
"""
import argparse, hashlib, json, shutil, subprocess, tempfile, time, uuid
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
BUNDLE = 'com.holyhim.app'
p = argparse.ArgumentParser()
p.add_argument('--device', default='79D1760F-3CCF-5595-874B-46E260F41DCD')
p.add_argument('--routes', nargs='+', required=True)
p.add_argument('--scale', type=float, default=1)
p.add_argument('--motion', action='store_true')
p.add_argument('--output', default='store/pearl-redesign/device-gallery')
a = p.parse_args()
out = ROOT / a.output
out.mkdir(parents=True, exist_ok=True)
app = ROOT / 'build/ios/Release-iphoneos/Runner.app'
artifacts = {str(f.relative_to(app)): hashlib.sha256(f.read_bytes()).hexdigest()
             for f in [app/'Runner', app/'Frameworks/App.framework/App']}

def run(*args, check=True, timeout=35):
    return subprocess.run(args, capture_output=True, text=True, check=check, timeout=timeout)

def launch(*arguments):
    run('xcrun', 'devicectl', 'device', 'process', 'launch', '--device', a.device,
        '--terminate-existing', BUNDLE, *arguments)

def fetch(source, target):
    return run('xcrun', 'devicectl', 'device', 'copy', 'from', '--device', a.device,
        '--domain-type', 'appDataContainer', '--domain-identifier', BUNDLE,
        '--source', source, '--destination', str(target), check=False, timeout=12).returncode == 0

def is_holyhim_image(path):
    # Validate only palette/geometry before opening a capture for visual review.
    # A switched app is discarded, never archived or presented to the agent.
    with Image.open(path) as im:
        if im.size != (1290, 2796):
            return False
        im = im.convert('RGB').resize((43, 93))
        pixels = [im.getpixel((x,y)) for y in range(12,88) for x in [1,2,40,41]]
        return sum(r > 225 and r >= g and r >= b and g > 205 and b > 210
                   for r,g,b in pixels) / len(pixels) > .78

try:
    with tempfile.TemporaryDirectory(prefix='holyhim-phone-capture-') as temporary:
        temp = Path(temporary)
        for route in a.routes:
            session = uuid.uuid4().hex
            launch(f'--holyhim-preview={route}', f'--holyhim-session={session}',
                   f'--holyhim-scale={a.scale}', f'--holyhim-motion={str(a.motion).lower()}')
            ready = temp/'ready.json'
            ready.unlink(missing_ok=True)
            deadline = time.monotonic()+95
            while time.monotonic() < deadline:
                if fetch(f'tmp/preview-ready-{session}.json', ready):
                    break
                time.sleep(.7)
            if not ready.exists():
                raise RuntimeError(f'{route} never became ready; phone may be locked')
            data = json.loads(ready.read_text())
            if data['session'] != session or data['route'] != route:
                raise RuntimeError('Stale or mismatched capture state')
            errors = temp/'errors.txt'
            errors.unlink(missing_ok=True)
            fetch(f'tmp/preview-errors-{session}.txt', errors)
            if errors.exists() and errors.read_text().strip():
                raise RuntimeError(errors.read_text())
            # Deliberately foreground HolyHim immediately before its screenshot.
            run('xcrun', 'devicectl', 'device', 'process', 'launch', '--device', a.device, '--activate', BUNDLE)
            time.sleep(.6)
            desktop = Path.home()/'Desktop'
            before = set(desktop.glob('Screenshot*.png'))
            script = ('tell application "System Events" to tell process "Xcode" to '
                      'click button "Take Screenshot" of scroll area 1 of splitter group 1 '
                      'of splitter group 1 of window "Devices"')
            run('osascript', '-e', script)
            shot = None
            deadline = time.monotonic()+18
            while time.monotonic()<deadline:
                created = set(desktop.glob('Screenshot*.png'))-before
                if len(created)==1:
                    shot=created.pop()
                    try:
                        with Image.open(shot) as image:
                            image.verify()
                        break
                    except (OSError, SyntaxError):
                        pass
                time.sleep(.25)
            if shot is None:
                raise RuntimeError('Xcode did not save a screenshot')
            try:
                if not is_holyhim_image(shot):
                    raise RuntimeError('Capture was outside the expected HolyHim palette; discarded')
                name=f'{route.replace(":","-")}--iphone14promax--s{a.scale:g}' + ('--motion' if a.motion else '')
                shutil.copy2(shot, out/f'{name}.png')
                data.update(capture='Xcode Devices screenshot from physical iPhone',
                    device=a.device, artifactSha256=artifacts, errors='',
                    actualAccount=False, pointerInput='QA-generated Flutter events; physical touch feel unverified')
                (out/f'{name}.json').write_text(json.dumps(data, indent=2))
                print(route, data['logicalWidth'], data['logicalHeight'], data['frameTimings']['sampleCount'], 'OK', flush=True)
            finally:
                shot.unlink(missing_ok=True)
finally:
    launch()  # Normal HolyHim, actual account and persistence, no fixture arguments.
