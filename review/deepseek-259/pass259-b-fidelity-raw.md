# Pass B — Fidelity gaps vs ZedSecure v3.2.0 — raw DeepSeek replies (verbatim)

Route: Runcrate `deepseek-ai/DeepSeek-V4.1-Flash-1017` (primary) / `deepseek-ai/DeepSeek-V4.1-Flash` (fallback) — free models only.

Note: chunk b3-2's prompt excerpt reached DeepSeek without Kotlin-side values, and its reply says so verbatim. Chunk b1-2 originally failed repeatedly (HTTP 529 / empty replies / helper rc=1) and was obtained as two halves b1-2a + b1-2b.

## Chunk b1-1 — model: deepseek-ai/DeepSeek-V4.1-Flash-1017 — status: 200 — incidents: ['empty reply at max-tokens 24000']

## B1 findings — playbook (Kotlin source values) vs `zed_motion.dart`

1. **Page fade duration** — Kotlin 260 enter / 180 exit ms | Dart 260 / 180 → `_specFor`, `case ZedTransition.fade` — **match**.
2. **Reduce-motion collapse** — Kotlin "120/90 ms fade + disables colour animation" | Dart 120/90 ms only → `_specFor` `if (reduceMotion)` — durations match; colour-animation gate absent from this file (unverified).
3. **Slide** — Kotlin 320 ms @ ⅓ width | Dart 320 ms, ±`width/3` via `zedFastOutSlowIn`, opacity 220/180 → `case slide` — transform matches; the 220/180 ms sub-fades are Dart-invented, not in recipe.
4. **Push** — Kotlin 340 ms, enter full width / exit −⅓ | Dart 340 ms, `sign*width` in, `-sign*width/3` out, opacity 120/340 & `1-t` → `case push` — **match** (opacity split undocumented).
5. **Depth** — Kotlin 0.88↔1.12 | Dart 0.88/1.12 via `forward` → `case depth` — scale match; the 300 ms duration and 220/180 fades are unsourced.
6. **Flip camera distance** — Kotlin `cameraDistance = 14×density` | Dart fixed `Matrix4.setEntry(3, 2, 0.0018)` (~555 px equivalent) → `case flip` — **divergence**: perspective is density-independent, so 3D strength varies per device vs source.
7. **Flip angle/duration** — Kotlin 78° / 360 ms, "ContentTransform is only a delayed fade" | Dart 78°·sign, 360 ms, fade `(t*360−90)/220` × `1−|angle|/110` → `case flip` — angle/duration match; the angle-derived alpha ramp is an added decoration.
8. **Curtain** — Kotlin ½ height + 0.94 counter-scale | Dart `height/2` translate, scale `1−0.06t` / `0.94+0.06t`, 360 ms → `case curtain` — geometry matches; 360 ms and the 200/260 fades are unsourced.
9. **Elastic spring** — Kotlin "medium-bouncy, low stiffness" | Dart `composeSpring(0.5, 200)` = ζ0.5, StiffnessLow 200 → `springMediumBouncyLow` — **match**.
10. **Elastic entrance geometry** — Kotlin (rise/scale not specified in playbook) | Dart `dy = height/8`, scale `0.9 + 0.1t`, opacity on 180 ms elapsed → `case elastic` — constants unverifiable against source; elapsed-time fade is a documented deliberate fix.
11. **Press spring** — Kotlin 1.07 scale, ζ0.5, StiffnessMedium | Dart `springPressGlass = composeSpring(0.5, 1500)` → `springPressGlass` — **match** on spring (1500 = StiffnessMedium); scale value lives in components, not here.
12. **Dock hold-scale spring** — Kotlin 1.03 hold, ζ0.55, StiffnessMedium(1500) | Dart no ζ0.55/1500 spring defined (nearest is `springMediumBouncyLow` 0.5/200) → spring set — **divergence/gap**: hold-scale spring missing from the reimplementation.
13. **Knob / platter springs** — Kotlin knob (0.62, MediumLow) / platter+thumb (0.72, MediumLow = 400) | Dart `springKnob` 0.62/400, `springPlatter` 0.72/400 → those symbols — **match**.
14. **Entrance stagger** — Kotlin 800 ms window, delay `min(i,12)×45 ms`, spring 0.62/380, +26 dp rise, scale 0.96→1 | Dart only `springEntrance = composeSpring(0.62, 380)` → `springEntrance` — spring matches; window, 45 ms delay, 26 dp rise and 0.96 scale are not in this file (unverified).
15. **Control behaviours / token surfaces** — Kotlin dock scroll thresholds (−4 px hide, +4/+24 restore, reset on destination), radii (cell 26 / module 24 / sheet 38 / menu 24) and blur sites (12 dp, chrome only) | Dart none present in `zed_motion.dart` → file scope — **coverage gap for this chunk**, not a proven divergence.

_Note: `_specFor` elastic *exit* branch is truncated at chunk end — exit duration/spring for Elastic unverified._

## Chunk b1-2a — model: deepseek-ai/DeepSeek-V4.1-Flash-1017 — status: 200 — incidents: none

Blocker: this chunk contains only the Dart side (`zed_transition.dart` tail + `zed_glass.dart`). No Kotlin source is present, so Kotlin-vs-Dart side-by-side values cannot be asserted; the Dart values that require that comparison are inventoried below, each flagged unverified.

1. Duration (detail) — zed_transition.dart `ZedTransition.detail` — Dart 1000 ms + `springMediumBouncyLow`; Kotlin value absent in chunk → unverified.
2. Duration (detail, reduced) — zed_transition.dart `ZedTransition.detail` — Dart 220 ms, spring null; Kotlin value absent → unverified.
3. Duration (curtain) — zed_transition.dart `ZedTransition.curtain` — Dart 360 ms, spring null; Kotlin value absent → unverified.
4. Duration (flip) — zed_transition.dart `ZedTransition.flip` — Dart 360 ms, spring null; Kotlin value absent → unverified.
5. Spring (entrance) — zed_transition.dart `ZedEntrance._start` — Dart `SpringSimulation(springEntrance, 0, 1, 0)`; `springEntrance` defined outside this chunk → unverified.
6. Duration (entrance delay) — zed_transition.dart `ZedEntrance._start` — Dart `min(index,12) * 45 ms`; Kotlin value absent → unverified.
7. Duration (entrance window) — zed_transition.dart `ZedEntrance` — Dart 800 ms from first build; Kotlin value absent → unverified.
8. Size (entrance rise) — zed_transition.dart `ZedEntrance.build` — Dart 26 dp; Kotlin value absent → unverified.
9. Size (entrance scale) — zed_transition.dart `ZedEntrance.build` — Dart 0.96→1.0; Kotlin value absent → unverified.
10. Opacity (entrance alpha) — zed_transition.dart `ZedEntrance.build` — Dart `t.clamp(0,1)`; Kotlin value absent → unverified.
11. Press scales — zed_transition.dart `ZedPressScale` — Dart doc cites Bento 0.965/0.985, Glass 1.07 but actual constants are caller-supplied (not in chunk); Kotlin values absent → unverified.
12. Radius (default surface) — zed_glass.dart `GlassSurface` — Dart `BorderRadius.all(Radius.circular(24))`; Kotlin default absent → unverified.
13. Rim gradient stops — zed_glass.dart `glassRimGradient` — Dart `[0.0, 0.28, 0.48, 0.64, 1.0]` (topLeft→bottomRight); Kotlin absent → unverified.
14. Blur sites — zed_glass.dart — Dart `GlassSurface` has no blur; blur claimed only in `GlassChromeSurface`/`GlassTopEdge` (not in chunk); Kotlin blur inventory absent → unverified.
15. Stroke/sliver — zed_glass.dart `_GlassEdgePainter` — Dart strokeWidth 1, `deflate(0.5)`, 1 dp top sliver; Kotlin absent → unverified.

To produce real fidelity findings, provide chunk 1/2 (the Kotlin reference).

## Chunk b1-2b — model: deepseek-ai/DeepSeek-V4.1-Flash — status: 200 — incidents: ['empty reply at max-tokens 24000', 'empty reply at max-tokens 34000', 'switched to fallback deepseek-ai/DeepSeek-V4.1-Flash']

1. Kotlin `12` vs Dart `12` — `GlassChromeSurface.blur`.
2. Kotlin `top+14`, `10`, `0.35`, `0.55`, `0.96/0.90/0` vs Dart `top+14`, `10`, `0.35`, `0.55`, `0.96/0.90/0` — `GlassTopEdge.build`.
3. Kotlin value-compare vs Dart `old.kind != kind || old.dark != dark` — `_WallpaperPainter.shouldRepaint`.
4. Kotlin `0/0.52/1` and `0/0.72` vs Dart `0/0.52/1` and `0/0.72` — `_WallpaperPainter.paint`, `_WallpaperPainter._glow`.

## Chunk b2-1 — model: deepseek-ai/DeepSeek-V4.1-Flash-1017 — status: 200 — incidents: none

Findings (chunk 1 = `zed_theme.dart` 1–700, palette/theme layer only):

1. **Motion / durations** — Kotlin: fade 260/180 ms, slide 320 ms, push 340 ms, elastic spring (medium-bouncy), flip 360 ms, chrome crossfade+scale0.9; Dart: none present in `zed_theme.dart` 1–700. Divergence: no duration/easing tokens defined in this range (deferred to later chunk).

2. **Springs / curves** — Kotlin: press scale 1.07 (damp 0.5, Medium), switch knob 0.62/MediumLow, segmented+tab platter 0.72/MediumLow, bar hold 1.03 (0.55, Medium), scheme spring StiffnessMediumLow; Dart: no spring constants in 1–700. Divergence: springs absent from theme layer here.

3. **Sizes / radii** — Kotlin: cells 26 dp, modules 24 dp, sheets-top 38 dp, menus 24 dp, tab bar 62 dp + 22 dp margin, switch 63×28 (knob 37×24), segmented 34 dp, corners Squared 6/Rounded 22/Pill 34; Dart: none in 1–700. Divergence: no shape/metric tokens in this range.

4. **Blur sites** — Kotlin: exactly 4 real backdrop blurs (tab pill blur 12 dp lens 14/26; hold bubble lens 12/24 1.2×; glassChrome blur 12 dp lens 12/22, shadow r=24; status edge blur 10 dp); Dart: no blur constants in 1–700. Divergence: blur parameters not defined in theme layer.

5. **Control behaviours** — Kotlin: connect styles {Slide(0.72 thresh)/Button/Morph/Rail/Hold(650 ms)/Tile}, dock labels {Active/Always/Never}+auto-hide, hide-on-scroll (−4/+4/+24 px), sensor tilt off by default; Dart: none in 1–700 (only `pingColor` + `colorful` bool). Divergence: no control-behaviour code in this chunk.

6. **Palette set count** — Kotlin: 12 palettes (Brand, Accent, Pastel, Vivid, Mono, Citrus, Matcha, Neon, Pistachio, Ocean, Sunset, Berry); Dart: `_bentoDark` (line 221) holds only 8 hardcoded (brand, citrus, matcha, neon, pistachio, ocean, sunset + cut); derived Accent/Pastel/Vivid/Mono absent. Divergence: only hardcoded subset present in 1–700.

7. **Brand seeding** — Kotlin: Brand "seeded from accent/dynamic colour"; Dart: `_bentoDark.brand` (lines 222–241) fully hardcoded hex (ground `0xFF0B0A10`, lime `0xFFC7F24E`…). Divergence: no accent-seed path visible; Brand is static here.

8. **chipOnStage opacity** — Kotlin: value not stated in master; Dart `_dark` `0x1FFFFFFF` (12.5% white, line 152) vs `_light` `0x24FFFFFF` (14.1% white, line 200). Divergence: internally asymmetric dark/light alpha; unverifiable vs Kotlin.

9. **dockLine opacity** — Kotlin: value not in master; Dart `_dark` `0x24FFFFFF` (14% white, line 166) vs `_light` `0x1A16161C` (10% dark, line 214). Divergence: cannot cross-check; light dockLine is dark-tinted, dark is white-tinted (expected).

10. **goodOnStage constant** — Kotlin: not stated; Dart `0xFF9BF0AE` used identically in dark (line 153) and light (line 201). Divergence: same green regardless of brightness — verify low-contrast on light stage.

11. **good/mid/bad tones** — Kotlin: not enumerated; Dart dark `0xFF7BE495`/`0xFFF2C14E`/`0xFFFF8A80` (lines 161–163), light `0xFF16803F`/`0xFF8A5A00`/`0xFFB3261E` (lines 209–211). Divergence: brightness-specific set; no Kotlin hex to compare.

12. **pingColor thresholds** — Kotlin: master silent; Dart `BentoTokens.pingColor` (line 84): ms≤0→bad, <300→good, <800→mid, else bad. Divergence: unverifiable; boundary note — 0 and ≥800 both map to bad.

13. **HCT algorithm presence** — Kotlin: "where the source computes a colour (HCT), same algorithm" (no guessed hexes); Dart imports `package:material_color_utilities/material_color_utilities.dart` (line 1). Divergence: consistent — algorithm available, but no computed-palette function appears in 1–700 (only in the 4 derived palettes, absent here).

## Chunk b2-2 — model: deepseek-ai/DeepSeek-V4.1-Flash-1017 — status: 200 — incidents: none

Note: this chunk (2/2 of pass B2) is Dart-only — no Kotlin reference text is present, so no head-to-head comparison is possible from this excerpt. Findings below report observed Dart values and the only categories this chunk actually touches (opacities + colors); durations, springs, curves, sizes, radii, and blur sites are not present in this chunk.

1. AMOLED ground opacity — Kotlin: n/a (not in chunk) — Dart `0xFF000000`; `bentoTokensFor(...amoled...)` in `bento_tokens.dart` (line 686) — pure-black override, divergence unverified.
2. AMOLED surface/surface2/dock — Kotlin: n/a — Dart `0xFF111015` / `0xFF1B1A21` / `0xFF141319` (lines 687–689) — only 4 tokens overridden; divergence unverified.
3. `chipOnStage` alpha — Kotlin: n/a — Dart `0.12` dark / `0.14` light in `_tonalTokens` (line 597); constant `0.12` in `_monoTokens` (line 641) — asymmetric dark/light in tonal, flat in mono; divergence unverified.
4. `dockLine` alpha — Kotlin: n/a — Dart `0.08` (dark, white) / `0.10` (light, black) in `_tonalTokens` (lines 611–613) and `_monoTokens` (lines 655–657) — divergence unverified.
5. Accent chroma floor — Kotlin: n/a — Dart `seedChroma > 56 ? seedChroma : 56.0` for `BentoPalette.accent` (`_tonalTokens`, line 558); stage chroma `64.0` — divergence unverified.
6. Pastel chroma — Kotlin: n/a — Dart accent `40.0` / stage `40.0` (line 559) — divergence unverified.
7. Vivid chroma — Kotlin: n/a — Dart accent `92.0` / stage `64.0` (line 560) — divergence unverified.
8. Neutral/neutralVariant chromas — Kotlin: n/a — Dart `6` and `10` (`_tonalTokens`, lines 562–563) — divergence unverified.
9. Semantic good/mid/bad chromas (tonal) — Kotlin: n/a — Dart `145/48`, `80/60`, `25/70` (lines 566–568) — divergence unverified.
10. Tile chroma by kind — Kotlin: n/a — Dart accent `36.0`, pastel `26.0`, vivid `66.0` (lines 570–573) — divergence unverified.
11. Pastel tile tones — Kotlin: n/a — Dart `(dark 82, light 92)` / `(dark 16, light 24)` (lines 578–581) — divergence unverified.
12. Vivid tile tones — Kotlin: n/a — Dart `(dark 38, light 76)` / `(dark 96, light 10)` (lines 582) — divergence unverified.
13. Default (accent) tile tones — Kotlin: n/a — Dart `(dark 20, light 90)` / `(dark 88, light 24)` (lines 583) — divergence unverified.
14. Mono chroma and semantic palettes — Kotlin: n/a — Dart `n = 3`, good `145/40`, mid `80/50`, bad `25/64` (`_monoTokens`, lines 623–626) — divergence unverified.
15. Algorithmic seeds — Kotlin: n/a — Dart accent `0xFF5646D6`, pastel `0xFFD77FA1`, vivid `0xFFE64A19`, mono `0xFF616161` (`_algorithmicSeeds`, lines 543–546) — divergence unverified.

No duration, spring, curve, size, radius, blur, or control-behaviour values exist in this chunk; those must come from a different chunk to be scored.

## Chunk b3-1 — model: deepseek-ai/DeepSeek-V4.1-Flash-1017 — status: 200 — incidents: none

1. Bottom-bar dock height — spec 64 dp ("floating bar") | Dart 72.0 — zed_kit.dart `ZedBottomBar.build` L576–578 — dock renders 8 dp taller than documented.
2. Bottom-bar compactDock labels — spec 56 dp "icons only" | Dart `showLabels = style != minimal` (true at 56 dp) — `ZedBottomBar` L581–584 — 56 dp compactDock keeps text; only minimal hides it.
3. Switch disabled opacity — Compose default 0.38 | Dart 0.4 — zed_connect_glass.dart `_GlassSwitchState.build` L689 — 0.02 opacity divergence.
4. Switch hit target — visual 63×28 | Dart hit box 63×48 — `_GlassSwitchState` L715–718 — detector extends 20 dp vertically beyond paint.
5. Switch knob alpha — continuous ease | Dart `squash > 0.05 ? 0.55 + 0.45*(1−s)` else 1 — L738–742 — alpha pops discontinuously at squash 0.05.
6. Switch knob squash scale — uniform/unknown | Dart scaleX 1+0.22s, scaleY 1+0.12s — L731–733 — asymmetric stretch, not shrink.
7. Switch squash spring — Compose symmetric press/release | Dart `composeSpring(1.0, 1500)` onPointerDown/Up — L694–698 — same stiffness both directions, no release damping.
8. Connect button press scale — typical shrink (≤1.0) | Dart `pressedScale: 1.07` — zed_connect_glass.dart button L580 — scales UP on press.
9. Connect button gradient alpha — spec 0.26 highlight | Dart 0.18 when busy — L610–613 — busy dims highlight by 0.08.
10. Connect button glow — no documented shadow | Dart tint α0.5, blurRadius 14 — L593–597 — 14 dp glow present.
11. Connect card sizing — spec §2.7 unquantified | Dart SizedBox h74, disc 42, icon 22 — `GlassSwitchConnect` L785–801 — 74 dp card, 42 dp disc.
12. Slider shimmer — spec unknown | Dart Duration(ms: 2600) — `_GlassSliderConnectState` L857–859 — 2.6 s shimmer period.
13. Card corner radii — single spec radius | Dart Glass 26, Pixel 20, Bento `cardTheme.shape` — zed_kit.dart `ZedCard.build` L696–713 — three distinct radii per design.
14. Section header metrics — spec unknown | Dart padding 4/18/4/8, size 13, w700, ls 0.4 — `ZedSectionHeader.build` L664–670 — 18 dp top inset, 0.4 tracking.
15. Segmented/selection duration — spec 250 ms | Dart 250 ms `zedFastOutSlowIn` — `ZedSegmentedRow.build` L854–856 — matches bottom-bar item pill; unverified vs Compose spring.

## Chunk b3-2 — model: deepseek-ai/DeepSeek-V4.1-Flash — status: 200 — incidents: ['HTTP 529', 'HTTP 529', 'HTTP 529', 'empty reply at max-tokens 24000', 'empty reply at max-tokens 34000', 'switched to fallback deepseek-ai/DeepSeek-V4.1-Flash']

1. Reference gap — Kotlin value: not supplied — Dart value: present in toggle/`zed_theme.dart` — no side-by-side fidelity comparison possible; no verifiable Kotlin-vs-Dart findings.
