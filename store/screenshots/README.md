# App Store screenshots

Prepared sets contain five PNGs per device size, with the same ordering:

1. Today — one daily message
2. Verse — the exact Day-1 WEB quotation
3. Reason — the passage's original editorial explanation
4. Carry — practical reflection and the selected Peace focus
5. Journey — the complete 365-lesson catalog and calendar locks

Use the files in `app-store/iphone-1206x2622/` and `app-store/ipad-2064x2752/` for upload. They are RGB PNGs without transparency. The iPhone set is 1206 × 2622; the iPad set is 2064 × 2752. `manifest.json` records every dimension, file size, source, and caption. `overview.png` is a contact sheet for review, not an upload image.

`raw/` preserves the actual Flutter UI renders. The captures use the current bundled 365-lesson library and follow the real Home → Journey → Today → Lesson navigation. Account, purchase, and progress providers use deterministic first-day preview state; no real account details or payment information appear. These are rendered app screens, not evidence of a live App Store purchase or a physical-device run. The framing script adds only the pearl background, captions, and a neutral rounded frame around each unchanged UI image.

Reproduce after the content and UI tests pass:

```sh
flutter test test/screens_test.dart --dart-define=STORE_SCREENSHOTS=true --plain-name 'capture App Store screens' --concurrency=1
python3 store/frame_screenshots.py
```

The capture test requires exactly 365 bundled lessons. The framing script checks raw dimensions, writes RGB upload files, and generates the manifest/contact sheet. The font is the bundled Lexend family.

Apple screenshot requirements checked October 29, 2026: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/
