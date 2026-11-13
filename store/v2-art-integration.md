# Approved art integration

Verified November 4, 2026. No paid generation was run and no placeholder
photographs were created.

- `SceneArt` reads all eight scene IDs from `assets/art/scenes/<id>.webp` and
  uses the current theme while a file is absent. It animates present art with a
  20-second Ken Burns movement, freezes under Reduce Motion and adds a readable
  dark-theme overlay.
- Welcome, heart/promise onboarding, Saved/Growth empty states and Celebration
  now have scene-aware backgrounds. Existing icons and atmosphere remain the
  fallback until approved art is packaged.
- Badge shelves, spin reveals, celebration keepsakes and badge sharing pass the
  actual domain badge ID. All nineteen IDs map to the pipeline's PNG filenames.
  Locked generated images are frosted; missing images keep the existing 3D
  porcelain fallback.
- Bundle-manifest checks prevent attempted loads of absent art. A listed but
  corrupt image also falls back through a handled image error.
- Four art widget tests pass, covering the package filename contract, missing
  assets, actual bundle fixture loading, Reduce Motion and a corrupt-image
  fallback. The twelve existing secondary/celebration tests also passed after
  scene integration, including 200% text and native sharing image output.

Actual generated art still requires the Gemini API key, style-reference approval,
review/package steps, and an app rebuild so the asset manifest contains the new
files. Real scene composition, medallion keying and photographic contrast must be
reviewed after those files exist; widget fixtures validate loading and fallbacks.
