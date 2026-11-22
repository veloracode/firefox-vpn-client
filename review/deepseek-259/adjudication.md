# DeepSeek +259 — adjudication (by Muse, against the code)

DeepSeek found and reviewed only; every claim below was checked in
the tree before any code moved. Raw passes: pass259-a/b/c-raw.md;
index: findings-index.md (190 findings). Tallies:

- Pass A (bugs, 53): 19 confirmed & fixed · 12 refuted · 22 moot/by-design
- Pass B (fidelity, 78): 3 confirmed & fixed · 9 confirmed matches (no
  action) · 6 refuted · 60 moot/unverified/documented
- Pass C (lag, 59): 13 confirmed & fixed · 1 partially fixed ·
  2 refuted · 43 moot/by-design/standard-pattern

Note on Pass C timing: the child's prompt chunks were prepared
before this round's IMP-1 shell fix landed, so the whole-shell
rebuild class (C1/C2/C9/C23/C33…) is adjudicated
confirmed-and-already-fixed, with the fix cited.

## Pass A

Confirmed & fixed:
- A1 — settings load failure spun forever → `_loadFailed` + retry
  block (new l10n `settingsLoadFailed`/`tryAgain`).
- A2 — `_save` would replace a non-map config node with `{}` →
  pre-validation refuses the save (`settingsPathBlocked`).
- A3 — upstreamProxy indexed under `advanced` → indexed under
  `SettingsSection.upstreamProxy` (on Android the hit was filtered
  out entirely; on desktop it opened the wrong section).
- A6 — no refresh after TUN-service removal → `_load()` after
  `TunServiceDone` (the page's status-facts listener covers the rest).
- A10 (part) — `removeTunService` searchable on Android where it
  cannot exist → added to `settingOnThisPlatform`'s computer-only
  set. (The tunMtu part is refuted: the MTU row renders in
  `_connection`, phone included.)
- A11 — removeTunService also indexed under `routing`, a section
  that does not show it → entry removed (advanced is the real one).
- A12 — six general-section rows used a plain Material `Switch`
  while every other row uses the glass-aware `sw()` → all six now
  go through `sw()` (with semantic labels).
- A15 — `_ChoiceChip` tap target ~36 dp → vertical padding 12
  (~44 dp).
- A16 — chip label announced twice → `excludeSemantics: true`.
- A38/A39 — GlassTabBar items (full bar + shrunk circle) were bare
  GestureDetectors → Semantics(button/selected/label) added;
  widget test added.
- A40 — Glass Z phase-colour blend ran under reduced motion →
  snaps when `_animate` is false.
- A41 — `_DockItem` label announced twice → `excludeSemantics: true`.
- A42 — `_ZPainter.shouldRepaint` compared 3 of 14 painted look
  fields → `ZLook` gained value equality over all fields; painter
  compares the whole look. Unit test added.
- A43/A51 — connect toggles' Semantics lacked the disabled state →
  `enabled: spec.enabled` on all 13 spec-driven toggle sites.
- A45 — Bento `_QuickAction` tap target ~37 dp → 44 dp floor
  (width unchanged).
- A48 — `_BentoHero` quick actions required BOTH callbacks → either
  one now shows.
- A53 — `math.max(from, knobR - knobR)` no-op clamp → `max(from, 0.0)`
  (cosmetic cleanup).

Refuted (code evidence against the claim):
- A5 — "success shown as error": `showError` is a plain neutral
  floating SnackBar (widgets.dart:705); no error styling exists.
- A7 — `_pickLanguage` pre-load read: the picker lives in a section
  the page only renders after `_config` loads; unreachable.
- A8 — `_saving` is read at ~20 call sites (`onChanged: _saving ?
  null : …`); DeepSeek saw a partial excerpt.
- A13/A14 — double-toggle: the switch wins the gesture arena, and
  both handlers pass the same captured `!value` (idempotent set,
  not a flip). Row semantics: the switch carries the state; the
  GlassSwitch gained its row label in IMP-2.
- A20/A21 — dual navStyle storage with different defaults is the
  SOURCE's own shape: Kotlin `BentoPrefs.navStyle` defaults to
  `NavBarStyle.Dock`, `AppSettings.navBarStyle` to `ExpressivePill`
  (AppSettings.kt:259, BentoPrefs.kt:24). `setZed` writes both
  together, so they cannot diverge through the UI.
- A22 — `_intOrNull` rejecting doubles is the tree's TESTED
  contract (`zed_prefs_test`: "corrupt custom-colour values read
  as unset"). A fix was attempted and reverted for exactly this.
- A25 — `GlassPrefs.translucent` IS consumed: zed_glass.dart:101
  gates the glass edge on `tokens.translucent`.
- A31 — `barBottom` is used (content inset in the shell build).
- A36 — `settingOnThisPlatform(l, name)` takes the localized name
  by contract; the sets are built from the same `l`.
- A37 — `GlassTopEdge` wraps its content in `IgnorePointer`.
- A52 — slide-toggle release during busy counting as a tap is the
  documented design ("a busy tap cancels the attempt",
  zed_connect.dart onPointerUp); drag deltas are frozen during
  busy, so the release is a tap by construction.

Moot / by-design (no change): A4, A33 (search opens the section —
the app's navigation model), A9 (panel titles are findable labels),
A17, A18 (chips are never disabled: the only caller always passes
onTap), A19 (the _Choice doc was rewritten with the chips in +258),
A23, A24, A26 (typed-prefs normalization of our own file format),
A27, A28 (no-core states replace content by design), A29 (traffic
icons are decorative; values carry the text), A30 (ancestor pops
routes — DeepSeek itself flagged it masked), A32, A34, A35 (live
filtering makes these cosmetic), A44 (no content to assess), A46
(graph is decorative beside text rates), A47 (harmless fallback),
A49 (dispatcher throw is an internal invariant; glass is routed
separately), A50 (GestureDetector participates in semantic tap via
RenderSemanticsGestureHandler).

## Pass B

Confirmed & fixed:
- B12 — the source's dock hold spring (1.03, ζ0.55, StiffnessMedium)
  had no counterpart: dock items had NO press feedback →
  `springDockHold` added; `_DockItem` wraps its content in
  `ZedPressScale(1.03)` (Listener-based, cannot eat taps).
- B65 — GlassSwitch disabled opacity 0.4 vs Compose's 0.38 → 0.38.
- B67 — knob alpha popped at squash 0.05 → continuous formula
  (identical at squash 0 and 1).

Confirmed matches (no action): B1 (fade 260/180), B9, B11, B13
(springs), B31 (chrome blur 12), B32 (top edge values), B33
(wallpaper shouldRepaint), B34 (wallpaper stops), B77 (segmented
250 ms).

Refuted:
- B40/B41 — "only 8 palettes, no seed path": the derived Accent/
  Pastel/Vivid/Mono palettes are computed by `_tonalTokens`/
  `_monoTokens` from `_algorithmicSeeds` via HCT
  (material_color_utilities) — outside the chunk's line range.
- B63/B64 — described the pre-rewrite `ZedBottomBar` (72 dp, labels
  on compact). This round's BUG-3 rewrite (before the chunks were
  cut) already made it source-true: floating 64, compact 54,
  compact label-free.
- B66 — the switch's 63×48 hit box vs 63×28 paint is the deliberate
  +258 I1 device fix (bigger target, same visual).
- B70 — glass press scale 1.07 IS the source value (playbook
  springPressGlass).

Moot / unverified / documented (no action): the remaining 60 —
mostly values whose Kotlin side never reached the chunk (B16–B30,
B42–B62, B73–B76, B78) or chunk-scope artefacts (B35–B39: the
tokens live in zed_motion.dart/zed_glass.dart, not zed_theme.dart).
Notable documented divergences kept as-is: B3–B5, B7, B8 (opacity
sub-fades are the Flutter crossfade equivalents of the Compose
transitions), B6 (flip perspective is density-independent in the
port; visual strength difference is UNPROVEN on device), B10
(elapsed-time fade is a deliberate, documented fix), B2 (the
reduced-motion colour gate lives at the widgets — and A40 closed
its last gap), B14/B20–B25 (entrance values present in
zed_transition.dart and verified against the playbook in +257),
B68 (knob stretch asymmetry is the source's squash), B69, B71, B72,
B75 (per-design card radii follow each design's own spec).

## Pass C

Confirmed & fixed:
- C1, C2, C5, C6, C7, C9, C13, C14, C23, C33 — the 2 s core poll
  rebuilt the whole shell and every page → IMP-1: the shell
  rebuilds only when `shellStructureOf(core)` changes; the traffic
  panel and the home page own their listeners; servers/settings/
  accounts/about listen selectively. Widget tests prove a
  traffic-only poll rebuilds neither the shell nor a pushed page.
- C3, C8 — traffic panel/rail: isolated in its own
  `ListenableBuilder` by IMP-1.
- C18 — `settingsIndex(l)` rebuilt per keystroke → cached per
  locale in the settings state.
- C10 — partially: pushed routes now receive their page as the
  builder's `child:` (built once); route chrome still restyles on
  a poll, by design and cheap.

Refuted:
- C15 — `GlassWallpaperView` is procedural CustomPaint; there is
  no image to decode at any size.
- C56 — the dock's `_onScroll` setStates only when the direction
  flag actually flips (change-guarded, with anchor hysteresis).

Moot / by-design / standard pattern (no change): C4 (a settings
change must rebuild MaterialApp — user-initiated, not per-tick),
C11 (blur inventory is the 2 sanctioned sites; the wallpaper is
paint, not backdrop), C12, C16, C17, C19, C20 (the settings list is
one screen of rows; per-keystroke rebuild is the platform norm and
C18 removed its only real cost), C21, C22 (sanctioned blur sites;
the shell no longer rebuilds per tick), C24–C31 (painter/widget
allocation per build is the Flutter pattern; shouldRepaint guards
the paint; chrome blur matches the source), C34–C43 (per-build
allocations on the home page, whose 2 s cadence is inherent —
rates change), C44, C59 (DeepSeek's own positive confirmations),
C45–C55 (per-frame painter allocation inside AnimatedBuilder is
the standard pattern; the areas are small; jank is a device
question — UNPROVEN), C57, C58 (animation-bounded subtree rebuilds;
the bar morph is frame-sampled-tested since +258).

## Also this round (own sweep, before DeepSeek returned)

- BUG-1: corrupt app-settings file counted as welcome-done →
  `firstRun` stays true (tests added).
- BUG-2: welcome's routing write failure still marked welcome
  done and stuck the button → stays, resets, retry works (test).
- BUG-3: Bento `navStyle` was a no-op on the phone and
  `ZedBottomBar` rendered all 7 styles as one bar → rewritten per
  NavBar.kt (6 distinct bars + heights), Bento routes dock vs
  shared bar by the setting (15 tests).
- IMP-1: shell rebuild blast radius (above).
- IMP-2: accessible names — GlassSwitch semantic labels wired,
  segmented options and swatches announce as selectable buttons,
  swatch hit boxes 44 dp.
