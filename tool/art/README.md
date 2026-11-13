# HolyHim artwork

The current app uses **25 coordinated Christian photographs and 19 transparent 3D badges**, generated with the built-in image-generation tool and visually inspected. No image API key or separately hosted image per lesson is required.

- Originals: `art/generated/library/` and `art/generated/badges/`.
- Subjects and shared style specifications: `art/redesign-prompts.json`.
- Original/runtime asset hashes: `art/redesign-manifest.json`.
- Optimized app images and thumbnails: `assets/art/library/`, `assets/art/badges/`.
- Shared day mapping: `assets/art/library/catalog.json`, generated `lib/design/art_catalog.dart`.
- Reviews: `store/redesign-v3/library-review.jpg`, `store/redesign-v3/badges-review.jpg`.

The library contains five Jesus scenes, five sky/light scenes, five crosses, five Scripture/prayer settings and five landscapes/symbols. Warm light, rose, ivory, champagne and sage tie them together. All badge originals have actual transparency and use matching sculpted porcelain/gold materials, perspective and lighting.

Rebuild local packages and the content-aware 365-day mapping with:

```sh
python3 tool/art/package_redesign.py
```

This command performs no generation, paid request, upload or deployment. Library images become 1024×1536 WebP plus 240×360 thumbnails; badges are centered on a 1024px alpha canvas with 240px thumbnails. WidgetKit bundles 25 JPEG thumbnails and the same per-day artwork IDs. The app, daily verse, saved cards and widget bridge all use the shared mapping.

`holyhim_art.py` and its tests preserve the earlier standalone Gemini workshop for historical use. That workflow's 365 separately hosted backgrounds, eight separate scenes, chroma-key badges and AI Studio key are not requirements for this redesign. Do not run that generation workflow unless the user explicitly chooses it.
