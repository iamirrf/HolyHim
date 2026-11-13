HolyHim's presentation system

Import `package:holyhim/design/design.dart`. Keep one `Atmosphere` outside the navigator so it persists across routes. Set `theme: HolyThemes.byId(profile.theme)` and pass the fractional tab page as `mood` for a continuously morphing mesh. `Atmosphere` installs `HolyThemeScope`, which is also available directly when a standalone sheet needs the current palette.

Use `HolyThemeData.build(theme)` for app theme data. All scaffold backgrounds are transparent. A `GlassTopBar(title: Widget, scrollOffset: pixels)` starts with no material and brings in Cognein's progressive blur and tint as content passes beneath it. Inner routes automatically receive a glass back circle. Reserve its normal app-bar inset in the body.

`HolyTabShell(index, onChanged, child)` uses Cognein's exact native iOS 26 configuration (`AdaptiveScaffold`, native bottom bar, automatic minimization). Other platforms use the ported refracting `MinimizingGlassNavBar`. Vertical scroll collapses the bar and a drag across the expanded bar switches tabs. Reserve `HolyTabShell.bottomInset(context)` at the end of tab content. A parent `PageView` may supply swiping.

`Glass` uses 22px blur, two highlights, continuous corners and two pink shadows. `Pressable` uses Cognein's velocity-preserving spring with finger-local four-degree tilt. `HoldButton` retains SunRize's hold mechanics and adds an accelerating heartbeat. VoiceOver and keyboard activation have a direct completion action.

The fonts are bundled: PlayfairDisplay, Lora, Manrope, PinyonScript. Reading styles do not clamp text scaling. Navigation labels cap only their own scale to preserve native-sized chrome.

`HolyHaptics.enabled` and `HolySounds.enabled` are the single settings switches; sounds use an ambient iOS audio session and respect the silent switch. Call `HolySounds.warmUp()` when opening a lesson. `LessonDeck` is the Cognein spring deck including detents and velocity-sensitive callbacks.

Reduce Motion stops the mesh, particles, art movement, shimmer and reveal transforms. `Atmosphere(reduceTransparency: true)` replaces glass with opaque surfaces; high contrast also chooses these fallbacks. On iOS, the app reads Reduce Transparency from its system accessibility bridge.

Art uses `assets/art/lessons/day-001.webp` through day 14 and Hosting `/art/v2/lessons/day-015.webp` onward. Missing art paints a themed floral atmosphere. Device tilt is disabled under Reduce Motion. Place the art in bounded constraints. `Petals` supplies a finite celebration burst.

Original source paths and hashes are recorded in `store/v2-design-ports.json`.

`SceneArt(scene: 'welcome-peace', child: content)` adds approved 9:16 art behind
bounded or intrinsically sized content. The eight scene IDs match the art pipeline.
It checks the bundle manifest before loading, so an absent image retains the theme
without a missing-file request. Camera motion runs only for present images and
stops under Reduce Motion; a plum tint keeps dark-theme text readable. Use
`fallback: const SizedBox.expand()` to preserve an existing atmosphere or icon state.

`Badge3D(badgeId: badge.id, ...)` and `showBadgeReveal(badgeId: badge.id, ...)` use
the packaged PNG medallions when available. Domain IDs such as `days-7`, `streak-7`
and `promise` map to `days-007.png`, `streak-007.png` and `promise-kept.png`.
Locked images are frosted; missing images retain the porcelain drawing. After
packaging new assets, rebuild the app so its bundle manifest includes them.

Primary controls use `HolyTheme.buttonGradient`, `buttonInk` and `holdFill`.
These are separate from decorative accent gradients and mesh colors. Action and
Hold labels maintain at least 4.5:1 contrast through theme morphs, either
transparency preference, and the hold progress fill.
