# Defect sweep — FoxyVPN v1.1.0+258 (zed-v2-Muse) vs DEFECT-CRITERIA.md

Scope of this round: fix ONLY the three +257 device rejections
(I1/I2/I3) on this tree. Diff vs +257 (9613fa8): three UI files
(zed_kit.dart, zed_connect_glass.dart, settings_page.dart),
pubspec version, tests. Core manifest re-verified after the
change: **485/485 OK** (`core/` + `app/lib/core/` byte-identical).
Gates: `flutter analyze` clean; full suite **282/282 green**
(275 from +257, +7 new behavioural tests, 3 existing widget_test
blocks adapted to the new inline-choice model — see I3).
DeepSeek record: review/deepseek-258/deepseek-review-258.md.

## A) Behavior & runtime truth
- **A1** — PARTIAL/UNPROVEN (unchanged verdict, extended lab
  evidence): every control changed in this round is exercised by
  a behavioural test with an observed effect (I-group below).
  On-device effect remains UNPROVEN until the user's test.
- **A2** — PASS in lab: the full stock-derived suite (settings
  sections walk included) is green on the new settings model.
- **A3** — PASS: core byte-identical (485/485); no config inputs
  can differ.
- **A4** — PASS for +258 artifacts: CI run (see handoff) produced
  the arm64 APK (aapt: com.arman.firefoxvpn, 1.1.0, versionCode
  2258) and the Windows portable ZIP (contents verified).
- **A5** — PASS by construction: no new network calls.

## B) Ports & upstream fidelity
- **B1** — PASS: settings surface identity kept; the choice
  control now matches the source's SettingsChoiceRow model
  (inline options) instead of diverging from it.
- **B2/B3** — PASS: no upstream flow removed; core untouched.
- **B4** — PASS, strengthened: the dead-toggle audit was re-run
  for every ZedPrefs field (record in deepseek-review-258.md);
  no field is written without a reader.
- **B5/B6** — PASS: prefs round-trip battery untouched and green;
  no bulk replaces in this diff.
- **B7** — PASS by process: DeepSeek was root-cause-only; every
  finding adjudicated (13 confirmed / 1 moot / 8 refuted); all
  code is Muse's.
- **B8** — PASS: same base (upstream-119), same private target
  repo/branch, one CI dispatch, no release/tag.

## C) State, upgrade & data flows
- **C1/C2/C3** — PASS: no persistence shape changed; choices and
  row toggles write through the same AppSettings/setZed/_save
  paths as +257; the two-way binding is test-proven (I3).
- **C4/C5/C7** — N/A (nothing in those areas touched).
- **C6** — PASS: the removed `_Choice` dialog path leaves no
  residue — `_pickOne` remains in use by _ProgramRow; no routes
  or persisted keys were removed.

## D) UI surface & variants
- **D1** — N/A.
- **D2** — PARTIAL/UNPROVEN: the changed controls (GlassSwitch,
  docks, settings rows/choices) are exercised through their real
  actions in widget tests under the designs that use them; a
  live tunnel per design remains device-only.
- **D3** — PASS in lab: full suite green across designs.
- **D4** — UNPROVEN: still no render/screenshot pass in this lab
  (no emulator/KVM). Carried as residual risk, as in +257.
- **D5** — UNPROVEN on device: the morph now implements the
  source's transition spec with frame-sampled lab proof (I2);
  feel is device-only.
- **D6** — PASS: no list/count logic changed.

## E) Performance
- **E1/E2** — UNPROVEN (no emulator/KVM on this VM; no frame
  timings captured; no performance claim is made). The morph
  keeps both bar states composed only during the transition and
  both are small chrome surfaces behind RepaintBoundary, as in
  the source's AnimatedContent.

## F) Release & publishing discipline
- **F1/F2/F7/F8** — N/A: nothing published; artifacts are handed
  to the user for his device test.
- **F3** — PASS: pubspec 1.1.0+258 → arm64 versionCode 2258,
  read back from the built APK (A4).
- **F4** — PASS: one version, one CI dispatch, all platforms.
- **F5** — PASS: no one-shot helpers; push via hand-written Git
  Database API calls through the scoped connector helper.
- **F6** — PASS: single writer, paced ~1 req/s.

## G) Verification honesty
- **G1/G2** — Counts recomputed in this run: 282 tests by the
  runner, 485/485 by sha256sum, analyze clean.
- **G3** — No network/config verdicts from this sandbox.
- **G4** — Artifact completeness checked file-by-file (handoff).
- **G5** — Per-finding DeepSeek verdicts recorded.
- **G6** — UNPROVEN list: on-device feel of the morph and of all
  controls (the user's A15 test is the verdict), frame
  performance, live FxA sign-in + Guardian quota, a real tunnel
  per design, RTL/Persian on a real device, Windows portable
  run. Lab-green means ready for his test, never "flawless".

## H) Identity, credit & content accuracy
- **H1–H8** — PASS (unchanged by this diff; re-checked: no new
  names/credits/text surfaces beyond two code comments citing
  the defect IDs; badge, AGPL and authorship state as in +257).

## I) Interaction fidelity (the three device bugs)
- **I1 — PASS in lab.** Fixes: GlassSwitch opaque hit behaviour
  + 63×48 hit box (was 63×28 deferToChild); every settings switch
  row toggles from the whole row (13 sites). Tests
  (test/zed_device_bugs_258_test.dart): GlassSwitch toggles from
  the padded box and from the stadium corner on the first tap;
  a settings switch row toggles from its label and exactly once
  from the switch itself; a Glass bool row toggles from its
  label; Bento dock and Glass tab items select on the first tap.
  Device confirmation UNPROVEN (his test decides).
- **I2 — PASS in lab.** Fix: the Glass tab bar's bar↔mini change
  is a spring-driven morph (springMediumLow = the source's
  AnimatedContent default spring, ζ=1.0, k=400) crossfading and
  scaling 0.9↔1.0 both layers, replacing the subtree swap.
  Test: shrink and expand are sampled frame-by-frame and must
  pass through intermediate opacity states (a one-frame snap
  fails the test); endpoints settle at 62 dp as before, and the
  pre-existing shrink regressions (accumulators, anchor,
  shrinkEnabled) stay green. Device feel UNPROVEN.
- **I3 — PASS in lab.** Fix: `_Choice` renders ZedSecure's real
  control — title + all options inline as chips, selected filled
  with the check glyph, tap applies immediately (no dialog);
  every enum setting in the app uses it. Tests: stored wallpaper
  is the checked chip on load; tapping another chip applies AND
  persists (settings.zedPrefs re-read) with no dialog; design
  chips switch the design and swap the settings panel. The
  dead-toggle audit found no decorative rows. Device
  confirmation UNPROVEN.

## Core integrity
`sha256sum -c review/core-manifest-baseline.txt` → **485/485 OK**
after all changes.
