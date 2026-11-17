"""Build the landing page's images in public/images/site/.

Sources: the App Store art (art/generated/store, store/creative), the app
screens rendered for the store (build/store/raw, from
tool/render/store_test.dart), the medallion art and the app icon.

  python3 tool/build_site_assets.py
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'public/images/site'
SCREENS = ['today', 'verse', 'heart', 'prayer', 'amen', 'growth', 'circle', 'reminder']
MEDALS = {'medal-walk': 'days-007.png', 'medal-month': 'days-030.png',
          'medal-word': 'first-saved.png'}


def webp(image, name, quality=82):
    path = OUT / f'{name}.webp'
    image.save(path, 'WEBP', quality=quality, method=6)
    return path


def fit_width(image, width):
    return image.resize((width, round(image.height * width / image.width)), Image.LANCZOS)


def crop_aspect(image, aspect, cx=0.5, cy=0.5):
    """The largest crop of [aspect] (w / h) around the point (cx, cy)."""
    w, h = image.size
    if w / h > aspect:
        cw, ch = round(h * aspect), h
    else:
        cw, ch = w, round(w / aspect)
    left = min(max(round(w * cx - cw / 2), 0), w - cw)
    top = min(max(round(h * cy - ch / 2), 0), h - ch)
    return image.crop((left, top, left + cw, top + ch))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    made = []
    with Image.open(ROOT / 'art/generated/store/header-epic-21x9.jpeg') as art:
        art = art.convert('RGB')
        made += [webp(fit_width(art, 2400), 'hero-2400', 80),
                 webp(fit_width(art, 1400), 'hero-1400', 80)]
    with Image.open(ROOT / 'art/generated/store/search-epic-3x2.jpeg') as art:
        art = art.convert('RGB')
        # A tall crop for phones, centred on the sun under the clouds.
        made.append(webp(fit_width(crop_aspect(art, 3 / 4, cx=0.44), 1100), 'hero-phone', 80))
        made.append(webp(fit_width(art, 2000), 'sunrise-band', 80))
    for name in SCREENS:
        with Image.open(ROOT / f'build/store/raw/{name}.png') as screen:
            made.append(webp(fit_width(screen.convert('RGB'), 720), f'screen-{name}', 84))
    for name, file in MEDALS.items():
        with Image.open(ROOT / f'assets/art/badges/{file}') as medal:
            made.append(webp(fit_width(medal.convert('RGBA'), 360), name, 86))
    with Image.open(ROOT / 'ios/Runner/Assets.xcassets/AppIcon.appiconset/'
                    'Icon-App-1024x1024@1x.png') as icon:
        icon = icon.convert('RGB')
        for size in (512, 180, 64):
            path = OUT / f'icon-{size}.png'
            icon.resize((size, size), Image.LANCZOS).save(path, optimize=True)
            made.append(path)
    with Image.open(ROOT / 'store/creative/header-3840x1646.png') as header:
        og = crop_aspect(header.convert('RGB'), 1200 / 630).resize((1200, 630), Image.LANCZOS)
        path = OUT / 'share.jpg'
        og.save(path, 'JPEG', quality=86, optimize=True)
        made.append(path)
    total = 0
    for path in made:
        total += path.stat().st_size
        print(f'{path.relative_to(ROOT)}  {path.stat().st_size / 1024:.0f} KB')
    print(f'{len(made)} files, {total / 1e6:.1f} MB')


if __name__ == '__main__':
    main()
