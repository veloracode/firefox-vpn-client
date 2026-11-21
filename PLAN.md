# PLAN — FoxyVPN Zed v2 (v1.1.0+257)

Authorship: **Muse writes 100% of the code.** DeepSeek-V4.1-Flash is
used afterwards for bug-review only; every finding is adjudicated
(CONFIRMED with repro / REFUTED with code evidence) and every fix is
written by Muse.

Starting tree: pristine upstream armanlife v1.0.19 (`upstream-119`,
b31ad48). Core manifest baseline: `review/core-manifest-baseline.txt`
(485 files: `core/` + `app/lib/core/`). The failed `zed/` port is NOT
copied; it is consulted only as a list of what not to repeat.

## Ground truth order

1. Kotlin source in `~/workspace/zedsecure-v320/src/` (wins on conflict)
2. `ZED-TOKENS-EXTRACT.md` (values verified against source during the
   previous study; scheme mappings re-verified this run against
   `BentoTheme.kt` / `GlassTheme.kt`)
3. `ZEDSECURE-MASTER.md`, `LIQUID-GLASS.md` (patterns)

## Architecture (new code, all under `app/lib/ui/zed/`)

| File | Contents |
|---|---|
| `zed_prefs.dart` | `ZedPrefs` model: design, transition, nav style, reduce motion; `BentoPrefs`, `PixelPrefs` (Pixel+Old), `GlassPrefs` sub-models; JSON round-trip; `AppSettings` bridge (stored under the `zed` key in app-settings.json). |
| `zed_theme.dart` | `BentoTokens` (8 hardcoded palettes ×2 + tonal/mono HCT derivations + AMOLED), `bentoColorScheme()` mapping (verbatim from BentoTheme.kt), Pixel/Old scheme (seed = preset light colour, SPEC_2025 variants, contrast, AMOLED role set), `GlassColors` + `glassColorScheme()` (verbatim table), `ZedTheme.build()` → ThemeData per design, `ZedColors` theme extension. |
| `zed_glass.dart` | Wallpaper painter (5 kinds, gradients + ellipse glows), `GlassSurface` (clip → fill → specular sliver → 5-stop rim; solid when reduced), `GlassChromeSurface` (BackdropFilter blur 12 + RepaintBoundary — tab pill / chrome / top edge only), `GlassTopEdge`. |
| `zed_motion.dart` | Compose spring conversion (`SpringDescription` from dampingRatio+stiffness), `ZedPageTransition` (Fade/Slide/Push/Depth/Elastic/Curtain/Flip with §6.1 parameters, enter+exit, RTL sign, reduce-motion 120/90 fade, Flip decoration via 3D transform), `ZedEntrance` (800 ms window, min(i,12)×45 ms, spring 0.62/380, alpha+26 dp rise+scale .96), `ZedPressScale`. |
| `zed_kit.dart` | `ZedDock` dispatch: BentoDock (56 dp, §1.8), GlassTabBar (62+22, §2.3, shrink→Mini), nav styles for other designs (FloatingPill/ExpressivePill/FullBar/Underline/Minimal/CompactDock/Dock per §5); `ZedSegmented`; per-design switch builder; settings row helpers. |
| `zed_connect.dart` | `ZedPhase {off, busy, on, error}` + dispatch to 16 controls: Bento Slide/Button/Morph/Rail/Hold/Tile (§4), Pixel/Old Pill/Hero/Ring/Bar/Icon/Switch (§3.3), Glass Z/Button/Switch/Slider (§2.7) — geometry, thresholds (Slide .72, Glass slider .70/.30, Hold 650 ms linear), springs per spec. |
| `zed_home.dart` | Hero block used inside `overview_page.dart`: status word, connect control, session timer/speed chips per design prefs — narrow `ListenableBuilder`s so the 2 s core poll rebuilds only the text leaves. |

## Integration edits (existing files, UI layer only)

- `app_settings.dart`: `zed` JSON field load/save + `update(zed:)`; save-chain error recovery (`_saveTail` gets `onError` so one failed save cannot poison the chain).
- `app.dart`: `_theme()` → `ZedTheme.build(...)` driven by `settings.zedPrefs`; desktop page content wrapped in `ZedPageTransition` (direction from page order); Glass → wallpaper behind the shell + transparent scaffold; rail traffic cards read Pixel custom colours when set.
- `mobile_shell.dart`: overlay chrome architecture — wallpaper (Glass) → page (with `ZedPageTransition` between Home/Settings, direction by tab order) → floating dock overlay (bar lives OUTSIDE the transition, per MainScaffold.kt); content bottom inset per bar (Bento 84, Glass 94, others nav-bar height); Glass shrink state reset on tab change; pushed pages keep wallpaper under Glass.
- `overview_page.dart`: `_HomePalette` derived from the active design's tokens; `_PowerOrb` replaced by the design's connect control in both `_DesktopHome` and `_PhoneHome` (same `onPressed`, same phase inputs); background glows use design accents; Glass → transparent background (shell wallpaper shows through).
- `settings_page.dart`: new "Interface / design" rows in the General section — design picker, transition, nav style, reduce motion, and the active design's full block (Bento: palette/corners/title/density/dock labels/dock auto-hide/connect/motifs/playful/indexes/live tiles/wave/home toggles/AMOLED; Pixel & Old: accent/style/contrast/AMOLED/corner/connect/traffic style/custom colours/profiles; Glass: material/wallpaper/tint/connect/glass lists/shrink/motion highlights/reduce transparency/home toggles). All rows added to `settingsIndex` so search finds them.
- `welcome_page.dart`: design + palette/tint/accent picker added (live preview swatches); Start still persists via the same path.
- `about_page.dart`: "Made by arblant & Muse" line.
- `servers_page.dart`: rows wrapped in `ZedEntrance` (window anchored at first build); no behaviour change.
- Root: AGPL-3.0 `LICENSE`, `NOTICE.md` (armanlife/Mozilla/CluvexStudio).
- `app/pubspec.yaml`: version `1.1.0+257`.

## Performance rules applied

- BackdropFilter census target: exactly 3 widget sites (Glass tab pill,
  glass chrome surfaces, glass top edge) — all small, floating,
  RepaintBoundary-isolated; everything else simulated glass.
- No perpetual animation the original lacks; original's ambient loops
  (Z caustics/shine/scan, slide wave, hero breathe) are gated by
  phase + visibility + reduce-motion.
- Poll discipline: home status/timer/traffic are separate narrow
  ListenableBuilders; the shell does not rebuild on core ticks (the
  desktop shell's existing root ListenableBuilder is narrowed to
  page-relevant fields where safe).

## Verification

- `flutter analyze` clean; full `flutter test` green; new tests in
  `app/test/zed_*.dart`: prefs round-trip/defaults, per-field wiring
  (theme/widget effect per field), connect-control behaviour
  (slide threshold, hold timing, switch/slider flips), transition
  parameters.
- Core manifest re-verified identical at the end.
- DeepSeek bug-review loop (review only) → adjudication table in
  `review/deepseek-review.md`.
- DEFECT-CRITERIA sweep in `review/sweep.md`.
- Emulator smoothness: local VM has no KVM/system images (standing
  fact) — attempt once via `~/workspace/emu-lab`; if unusable, report
  as UNVERIFIED, never substituted by test counts.
