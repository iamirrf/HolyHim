"""Install the owner's supplied icon assets; never redraw or replace the artwork."""
import hashlib
import json
import zipfile
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
source=ROOT/'HolyHim_AppIcon_Set.zip'
target=ROOT/'ios/Runner/Assets.xcassets/AppIcon.appiconset'
manifest=json.loads((target/'Contents.json').read_text())
with zipfile.ZipFile(source) as archive:
    for item in manifest['images']:
        filename=item['filename']
        (target/filename).write_bytes(archive.read('HolyHim_AppIcon_Set/'+filename))
        with Image.open(target/filename) as image:
            pixels=round(float(item['size'].split('x')[0])*float(item['scale'][:-1]))
            assert image.size==(pixels,pixels),filename
            assert 'A' not in image.getbands() or image.getextrema()[-1]==(255,255),filename
master=target/'Icon-App-1024x1024@1x.png'
with Image.open(master) as image:
    for density,pixels in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
        image.resize((pixels,pixels),Image.Resampling.LANCZOS).save(ROOT/f'android/app/src/main/res/mipmap-{density}/ic_launcher.png')
    launch=ROOT/'ios/Runner/Assets.xcassets/LaunchImage.imageset'
    for scale,suffix in [(1,''),(2,'@2x'),(3,'@3x')]:
        image.resize((108*scale,108*scale),Image.Resampling.LANCZOS).save(launch/f'LaunchImage{suffix}.png')
for path in ['store/app-icon.png','public/app-icon.png']:
    (ROOT/path).parent.mkdir(parents=True,exist_ok=True)
    (ROOT/path).write_bytes(master.read_bytes())
(ROOT/'config/icon-provenance.json').write_text(json.dumps({'source':source.name,'sourceSha256':hashlib.sha256(source.read_bytes()).hexdigest(),'masterSha256':hashlib.sha256(master.read_bytes()).hexdigest()},indent=2)+'\n')
print('Installed supplied icons for iPhone, iPad, native launch, store, website, and Android assets.')
