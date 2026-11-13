# HolyHim 2.0 website verification

Reviewed locally on November 3–4, 2026. No deployment or production form submission
was performed.

## Verified

- The home page contains the requested header, hero with app capture, statement,
  five-card reading demonstration, streak keepsakes, eight theme choices,
  notification preview, numbered FAQ, final invitation and four-column footer.
- Privacy, terms, support and 404 use the same typography, atmosphere, header and
  footer. The FAQ uses native `details` elements and works without JavaScript.
- All five HTML pages have one `h1`, unique IDs, image alternative text, labelled
  form fields and valid local links/anchors. Referenced font and image assets
  exist. CSS braces are balanced and all referenced CSS assets exist.
- `public/lesson-sample.json` exactly matches the active authored Day 1 record in
  `content/lessons_v2.json`. The static HTML retains the complete first WEB verse
  if sample fetching or JavaScript is unavailable.
- `node --check public/site.js` and `node --check public/support.js` pass.
- `node --test tool/verify_site.cjs` passes seven interaction checks using the
  production scripts in isolated DOM fixtures: source/sample parity; all five
  cards through buttons, arrow keys and swipes; all eight themes and persistence;
  offline sample and blocked-storage fallbacks; support JSON submission; support
  failure/rate-limit recovery without clearing the message; and primary button
  contrast in all eight themes.
- Local HTTP checks returned `200` and appropriate MIME types for `/`, `/support`,
  `/privacy`, `/terms`, `/404.html`, `/lesson-sample.json`, both scripts, CSS and
  the four brand fonts.
- Source review confirms reduced-motion and reduced-transparency fallbacks,
  keyboard focus styles, a readable no-JavaScript fallback, lazy footer/reminder
  images, local fonts with `font-display: swap`, and a support
  request timeout. The rendered app preview is eager-loaded above the fold.

- Primary button palettes now provide at least **4.97:1** text contrast at both
  gradient endpoints in all eight themes. This is a calculation against the
  actual CSS variables; the corrected gradient applies to every `.button`.

## Verification still required

The mandatory in-app Browser execution tool was unavailable after rediscovery.
No substitute browser automation was used. The DOM fixtures are functional unit
checks; they do not validate layout, paint, browser compatibility or keyboard
focus order in a real browser.

Before release, capture and inspect Chrome at **390, 768 and 1440 px** in Blush
and Midnight Rose. Check the hero phone and floating captions, sticky five-card
reader, complete prayer text, theme transitions, FAQ, form errors, reduced motion,
200% zoom and narrow-screen overflow. Exercise the support form against an
emulator or staging endpoint rather than sending a production request during QA.

The phone image now uses an inspected, actual iPhone 17 Pro v2 simulator capture
with a local sample account. Its caption and alternative text identify the
preview; the redundant decorative Dynamic Island was removed because the capture
already includes it. Refresh the image after the final CTA palette capture. The App Store control correctly
states that the iPhone/iPad release is coming; a genuine store URL remains to be
configured when the listing is available.
