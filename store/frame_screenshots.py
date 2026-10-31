"""Frame actual Flutter UI captures for App Store Connect. No UI is fabricated.
Run after: flutter test test/screens_test.dart --dart-define=STORE_SCREENSHOTS=true
  --plain-name 'capture App Store screens' --concurrency=1
"""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent
FONTS = ROOT.parent / 'assets' / 'fonts'
CAPTIONS = {
    '01-today': ('One quiet moment.', 'Every day.'),
    '02-verse': ('Begin with', 'His Word.'),
    '03-reason': ('Confidence,', 'with a reason.'),
    '04-carry': ('A thought to carry.', 'A focus that’s yours.'),
    '05-journey': ('365 small steps.', 'One beautiful journey.'),
}
SIZES = {'iphone-1206x2622': (1206, 2622), 'ipad-2064x2752': (2064, 2752)}


def font(size, weight='SemiBold'):
    return ImageFont.truetype(str(FONTS / f'Lexend-{weight}.ttf'), size)


def mesh(size):
    w, h = size
    small = Image.new('RGB', (w // 4, h // 4), '#fff9fc')
    draw = ImageDraw.Draw(small)
    for y in range(small.height):
        t = y / small.height
        draw.line((0, y, small.width, y), fill=(255 - int(t * 5), 249 - int(t * 14), 252 - int(t * 7)))
    blobs = Image.new('RGBA', small.size)
    d = ImageDraw.Draw(blobs)
    d.ellipse((small.width*.45, -small.height*.05, small.width*1.5, small.height*.5), fill=(219, 163, 191, 65))
    d.ellipse((-small.width*.8, small.height*.4, small.width*.7, small.height*.95), fill=(242, 192, 185, 65))
    small = Image.alpha_composite(small.convert('RGBA'), blobs.filter(ImageFilter.GaussianBlur(small.width*.15)))
    return small.convert('RGB').resize(size, Image.Resampling.LANCZOS)


def frame(raw, caption, size):
    w, h = size
    tablet = w > 1500
    result = mesh(size)
    draw = ImageDraw.Draw(result)
    ink = '#382331'
    plum = '#8b365c'
    eyebrow = 'HOLYHER  ·  A LITTLE FAITH. EVERY DAY.'
    eyebrow_font = font(32 if tablet else 24, 'Medium')
    draw.text((w/2, 66 if not tablet else 85), eyebrow, fill=plum, font=eyebrow_font, anchor='mt')
    title_font = font(102 if tablet else 77)
    y = 130 if not tablet else 162
    line_height = 102 if not tablet else 132
    for line in caption:
        draw.text((w/2, y), line, fill=ink, font=title_font, anchor='mt')
        y += line_height
    ui_width = 990 if not tablet else 1590
    ui_height = round(ui_width * raw.height/raw.width)
    x = (w-ui_width)//2
    y = 410 if not tablet else 485
    border = 12 if not tablet else 15
    if y + ui_height + border >= h:
        raise ValueError('Frame exceeds the required screenshot size')
    shadow = Image.new('RGBA', size)
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((x-border-5, y-border+18, x+ui_width+border+5, y+ui_height+border+24), radius=76, fill=(95, 39, 65, 43))
    result = Image.alpha_composite(result.convert('RGBA'), shadow.filter(ImageFilter.GaussianBlur(27)))
    draw = ImageDraw.Draw(result)
    draw.rounded_rectangle((x-border, y-border, x+ui_width+border, y+ui_height+border), radius=70, fill='#fffdfd', outline='#e9d4df', width=2)
    resized = raw.convert('RGB').resize((ui_width, ui_height), Image.Resampling.LANCZOS)
    mask = Image.new('L', resized.size)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, ui_width-1, ui_height-1), radius=57, fill=255)
    result.paste(resized, (x, y), mask)
    return result.convert('RGB')


def main():
    manifest = []
    for device, size in SIZES.items():
        source_dir = ROOT / 'screenshots' / 'raw' / device
        output_dir = ROOT / 'screenshots' / 'app-store' / device
        output_dir.mkdir(parents=True, exist_ok=True)
        for name, caption in CAPTIONS.items():
            source = source_dir / f'{name}.png'
            with Image.open(source) as raw:
                if raw.size != size:
                    raise ValueError(f'{source}: expected {size}, got {raw.size}')
                raw.convert('RGB').save(source)
                final = frame(raw, caption, size)
            destination = output_dir / f'{name}.png'
            final.save(destination, optimize=True)
            manifest.append({'file': str(destination.relative_to(ROOT)), 'width': size[0], 'height': size[1], 'mode': final.mode, 'bytes': destination.stat().st_size, 'source': str(source.relative_to(ROOT)), 'caption': list(caption)})
    (ROOT / 'screenshots' / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    overview = Image.new('RGB', (5 * 270, 587), '#fff9fc')
    for index, name in enumerate(CAPTIONS):
        with Image.open(ROOT / 'screenshots' / 'app-store' / 'iphone-1206x2622' / f'{name}.png') as screenshot:
            overview.paste(screenshot.resize((270, 587), Image.Resampling.LANCZOS), (index * 270, 0))
    overview.save(ROOT / 'screenshots' / 'overview.png')
    print(f'Prepared {len(manifest)} RGB App Store screenshots at two required device sizes.')


if __name__ == '__main__':
    main()
