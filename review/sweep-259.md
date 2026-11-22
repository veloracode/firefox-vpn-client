# Sweep — build 1.1.0+259 (Muse tree, foxy-zed-v2)

Round: full bug-fix + improvement pass with DeepSeek (find/review
only; all code by Muse). Baseline +258 re-measured first:
analyze clean, 282/282 tests, core manifest 485/485.

Final gates for +259: **analyze clean · 305/305 tests · core
manifest 485/485**. New tests this round: 23 (4 in
app_settings/widget tests, 19 in test/zed_round_259_test.dart).

## DEFECT-CRITERIA verdicts (A–I)

- A (connect behaviour): PASS (lab) — all connect styles dispatch
  and toggle through the untouched core; dispatcher invariants
  hold. Live tunnel per design stays UNPROVEN (device).
- B (settings integrity): PASS — every ZedPrefs field has a real
  consumer (re-grepped field by field); search index complete AND
  section-correct (A3/A11 fixed; the source-scanning test's section
  model was corrected to match runtime truth); save/load error
  recovery: corrupt app-settings → firstRun (BUG-1), failed core
  settings load → error + retry (A1), save across a non-map node
  refused instead of clobbering (A2); corrupt prefs values read as
  unset per the tested contract (A22 refuted).
- C (navigation/bars): PASS — the 7 nav styles are now 6 distinct
  source-true bars + the Bento dock (BUG-3, frame- and
  geometry-tested); Bento's navStyle reaches the phone; Glass bar
  items are named buttons (A38/39).
- D (designs/sections): PASS (lab) — all four designs render all
  sections; general-section switches are glass-aware on Glass
  (A12). Device look UNPROVEN.
- E (motion/performance): UNPROVEN on device (no emulator/KVM, no
  frame timings — as always). Lab: poll blast radius cut (IMP-1,
  widget-tested); reduced-motion now also gates the Glass Z colour
  blend (A40); dock hold spring added (B12). Never claim
  "smoother" from this — E1/E2 await the user's phone.
- F (a11y/labels): PASS — friendly labels only (no raw enum names);
  accessible names extended (IMP-2 + A38/39/41/43/51); tap targets:
  chips ~44 dp (A15), quick actions 44 dp (A45), swatches 44 dp.
- G (core integrity): PASS — manifest 485/485 byte-identical;
  nothing under core/ or app/lib/core/ touched.
- H (platforms): PASS (lab) — one codebase; desktop rail behaviour
  unchanged; Windows ZIP built by CI (below). Windows portable run
  UNPROVEN (not run here).
- I (the +258 device trio): PASS — I1 switches toggle from the
  whole row with an opaque 63×48 hit box (unchanged, tests green);
  I2 dock morph is a spring crossfade+scale (frame-sampled test
  green); I3 settings rows are real controls (segmented chips
  inline; switch rows real switches — and now glass-aware in the
  general section too, A12).

## This round's changes

[bug fix]
- BUG-1 app_settings corrupt-file firstRun (lib/app_settings.dart)
- BUG-2 welcome save-failure handling (lib/ui/welcome_page.dart)
- BUG-3 Bento navStyle no-op + ZedBottomBar single-shape bars
  (lib/ui/zed/zed_kit.dart, lib/ui/mobile_shell.dart)
- A1 settings load-failure retry (settings_page.dart, l10n)
- A2 _save non-map clobber guard (settings_page.dart, l10n)
- A3/A11 search index section mapping (settings_page.dart)
- A6 refresh after TUN-service removal (settings_page.dart)
- A10 removeTunService platform filter (settings_page.dart)
- A40 reduced-motion gate for the Glass Z blend
  (zed_connect_glass.dart)
- A42 ZLook equality + painter shouldRepaint (zed_connect_glass.dart)
- A48 lone quick action suppressed (zed_home.dart)

[improvement — fidelity]
- B12 dock hold spring 1.03 ζ0.55/1500 (zed_motion.dart, zed_kit.dart)
- B65 GlassSwitch disabled opacity 0.38 (zed_connect_glass.dart)
- B67 knob alpha continuous in squash (zed_connect_glass.dart)
- A12 general-section switches glass-aware (settings_page.dart)

[improvement — lag, UI layer only]
- IMP-1 shell/page selective listeners; traffic panel isolated;
  pushed pages built once (app.dart, mobile_shell.dart,
  overview/accounts/about/servers/settings pages)
- C18 search index cached per locale (settings_page.dart)
- C10 pushed-route page passed as builder child (mobile_shell.dart)

[improvement — accessibility]
- IMP-2 GlassSwitch names, segmented/swatch semantics, 44 dp
  swatch targets (zed_connect_glass.dart, zed_kit.dart,
  settings_page.dart, welcome_page.dart)
- A15/A16 chip target + single announcement (settings_page.dart)
- A38/A39 GlassTabBar item semantics (zed_kit.dart)
- A41 dock item single announcement (zed_kit.dart)
- A43/A51 toggle Semantics enabled state (zed_connect.dart,
  zed_connect_glass.dart)
- A45 quick-action 44 dp floor (zed_home.dart)
- A53 wave-path clamp cleanup (zed_connect.dart)

DeepSeek tally: A 19 fixed / 12 refuted / 22 moot · B 3 fixed /
9 matches / 6 refuted / 60 moot-unverified · C 13 fixed /
1 partial / 2 refuted / 43 moot. Full record:
review/deepseek-259/adjudication.md.

## UNPROVEN / residual (honest list)

- Device feel and frame performance of everything (E1/E2) — the
  user's Galaxy A15 test is the verdict, as with +257/+258.
- Live FxA sign-in and Guardian quota on device.
- Real tunnel connect under each design on device.
- RTL/Persian rendering on device (semantics labels are localized
  strings; layout not device-verified).
- Windows portable ZIP actually launching on Windows.
- B6: flip-transition perspective is density-independent in the
  port (source: cameraDistance scales with density) — minor,
  visual difference unmeasured.
- The core's 2 s poll still notifies every listener; IMP-1 cut
  what the UI rebuilds from it, but the poll itself is core-side
  and untouchable by the rules of this tree.
- Settings search opens the containing section, not the exact
  control (A4) — the app's navigation model; changing it is a
  feature decision, not a bug fix.
