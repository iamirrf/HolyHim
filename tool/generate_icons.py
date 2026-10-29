"""Render the existing flat cross mark into native launcher icons, offline."""
import json
import math
from pathlib import Path
import re
import struct
import subprocess
import zlib

theme = Path('lib/core/theme/app_theme.dart').read_text()
def token(name):
    match = re.search(r'static const ' + name + r' = Color\(0xFF([0-9A-Fa-f]{6})\)', theme)
    if not match:
        raise ValueError('Missing theme token: ' + name)
    return tuple(bytes.fromhex(match.group(1)))

white, blush, accent = token('background'), token('surfaceLight'), token('accent')
rows = bytearray()
for y in range(1024):
    rows.append(0)
    for x in range(1024):
        coverage = max(0, min(1, 400.5 - math.hypot(x + .5 - 512, y + .5 - 512)))
        color = tuple(round(a + (b - a) * coverage) for a, b in zip(white, blush))
        if (492 <= x < 532 and 332 <= y < 692) or (372 <= x < 652 and 422 <= y < 462):
            color = accent
        rows.extend(color)

def chunk(kind, data):
    return struct.pack('!I', len(data)) + kind + data + struct.pack('!I', zlib.crc32(kind + data) & 0xffffffff)

master = Path('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png')
master.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('!IIBBBBB', 1024, 1024, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(bytes(rows), 9)) + chunk(b'IEND', b''))
contents = json.loads(master.with_name('Contents.json').read_text())
for image in contents['images']:
    name = image.get('filename')
    if not name or name == master.name:
        continue
    size = round(float(image['size'].split('x')[0]) * float(image['scale'].rstrip('x')))
    subprocess.run(['sips', '-z', str(size), str(size), str(master), '--out', str(master.with_name(name))], check=True, stdout=subprocess.DEVNULL)
for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
    target = Path(f'android/app/src/main/res/mipmap-{density}/ic_launcher.png')
    subprocess.run(['sips', '-z', str(size), str(size), str(master), '--out', str(target)], check=True, stdout=subprocess.DEVNULL)
print('Native icons rendered from the existing theme and cross mark.')
