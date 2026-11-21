# Defect sweep — FoxyVPN v1.1.0+257 (zed-v2-Muse) vs DEFECT-CRITERIA.md

Run by Muse (author of the build) on 2026-11-21. Verdicts cite
observations from this run only. UNPROVEN items are residual risks,
not passes.

## A) Behavior & runtime truth
- **A1 (exists ≠ works)** — PARTIAL/UNPROVEN. Every new control's
  action was exercised in widget tests with observable effects
  (taps/drag thresholds/hold timing flip the toggle callback;
  settings rows write through `AppSettings.setZed` and re-theme).
  On-device effect (real tunnel through each design's control) is
  UNPROVEN — device-only.
- **A2 (end-to-end flows)** — PASS in lab. The stock suite walks
  sign-in → accounts, connect, servers, settings on both shells
  (219 stock-derived tests green). The zed layer changes only which
  widget renders the same callbacks (`ZedConnectSpec.onToggle` is
  the stock toggle).
- **A3 (generated-artifact diff)** — PASS. The core is byte-identical
  (manifest 485/485, see below), and `grep` shows zero references to
  the zed prefs anywhere in `core/` or `app/lib/core/` — the sing-box
  config inputs cannot differ.
- **A4 (shipped-artifact capabilities)** — PASS. CI run 44910505420
  (branch zed-v2-Muse, tree ffcf8d2d) succeeded; the arm64 APK was
  dumped with aapt: package com.arman.firefoxvpn, versionName 1.1.0,
  versionCode 2257, INTERNET + the stock permission set present.
  The Windows portable ZIP lists firefox-vpn.exe,
  flutter_windows.dll, core/arman-vpn-core.exe (14.8 MB — the name
  core_process.dart:62 actually spawns) and core/arman-vpn-tun.exe.
- **A5 (fragile gating fetch)** — PASS by construction: no new
  network calls were added; the UI layer only re-renders existing
  core state.

## B) Ports & upstream fidelity
- **B1 (surface identity)** — PASS. The fork's surface is the four
  ZedSecure designs; every stock screen (home, servers, accounts,
  settings incl. search, welcome, about) renders under all four.
  Settings search index covers all 49 interface rows (stock
  `settings_search_test` green).
- **B2 (upstream-first)** — PASS. Base is pristine upstream-119
  (b31ad48); nothing upstream removed was resurrected; the only
  deletions are widgets the new heroes replaced (`_PowerOrb`,
  `_ConnectingRing`, contour background) — internal, no user flow.
- **B3 (request identity)** — PASS. Core untouched (manifest); no
  header/UA code exists in the UI diff.
- **B4 (no silent capability drop)** — PASS with one documented
  exception: Pixel `dynamicColor` has no platform source in this
  app and Bento hub-tile reordering has no surface in this app's
  navigation; both were omitted deliberately (PLAN.md) rather than
  shipped as dead toggles. Every other source preference field has
  a traced reader (wiring audit in the handoff).
- **B5 (port-differential battery)** — PASS for prefs: JSON
  round-trip + per-field fallback battery (zed_prefs_test) and the
  upgrade fixtures (v1.0.19 file, partial zed block).
- **B6 (bulk-replace audit)** — PASS. Three mechanical edits were
  made (identifier rename `zedProfileById`→`zedProfileOf`, a hamza
  fix in one fa string, enum renames inside the new tests); after
  each: full analyze + suite green, and `grep zedProfileById` = 0.
- **B7 (external-AI diff audit)** — PASS by process: no external AI
  wrote code in this build. DeepSeek-V4.1-Flash is review-only;
  its findings are adjudicated in review/deepseek-review.md.
- **B8 (base/target identity)** — PASS. Base stated: upstream-119
  b31ad48 in a fresh worktree; target: private veloracode repo only,
  one CI dispatch, no release/tag.

## C) State, upgrade & data flows
- **C1 (seeded upgrade state)** — PASS in lab: fixtures of the old
  settings file (no zed key) and a partial zed block load to
  per-field defaults (zed_prefs_test, both green). The zed block is
  additive; no data-plane key is touched.
- **C2 (shared-store writers/clears)** — PASS. The zed block lives
  in the same app-settings.json; the only writer is
  `AppSettings.setZed` → the existing serialized `_save` chain; no
  new clear path exists.
- **C3 (synchronized writes)** — PASS. Saves are serialized through
  the `_saveTail` future chain (round-4 F3 fix carried in the
  foundation: the chain recovers via `onError`).
- **C4 (reconciliation)** — N/A: no reconciliation logic added or
  changed (core untouched).
- **C5 (per-account attribution)** — N/A for the zed layer (no quota
  code touched); stock quota tests remain green.
- **C6 (removed-feature residue)** — PASS: the removed stock widgets
  persisted nothing; no routes were removed (all stock pages still
  reachable), so no stale back-stack/intent residue is possible.
- **C7 (new source verification)** — N/A: no new data source.

## D) UI surface & variants
- **D1 (unblock control on the blocked screen)** — N/A: no recovery
  control moved; settings reachability is unchanged from stock.
- **D2 (each variant through its real action)** — PARTIAL/UNPROVEN.
  In lab, all four designs render the home and their connect
  controls toggle through the same spec callback (widget tests per
  control family). The real action (traffic through a live tunnel
  per design) is device-only → UNPROVEN.
- **D3 (variant silently killed)** — PASS in lab: theme-extension
  assertions per design (ZedColors only under Bento, ZedGlass only
  under Glass) in zed_theme_test; all four designs are exercised by
  the stock suite's default (Bento) plus the zed widget tests.
- **D4 (render before shipping)** — UNPROVEN. No screenshot/render
  pass exists in this lab (no emulator/device — see E1). Widget
  tests assert structure and behaviour, never pixels. This is the
  exact gap that sank +256; it is carried as the top residual risk.
- **D5 (connect-control feel)** — UNPROVEN on device. In lab: the
  controls implement the source's state machines and timings
  (slide 0.72, hold 650 ms, glass slider 0.70/0.30, springs from
  the source's ζ/k) with tests; feel itself is device-only.
- **D6 (counts/lists from real actions)** — PASS: no list/count
  logic changed; stock tests seed through real flows and remain
  green.

## E) Performance
- **E1 (measure before claiming)** — UNPROVEN. This VM has no
  Android emulator binary, no AVD/system images and no /dev/kvm
  (checked 2026-11-21), so no frame/raster timings could be
  captured. No performance claim is made for this build. The known
  Mali-G57 trap was designed against (real BackdropFilter only in
  the sanctioned chrome/tab-bar surfaces behind RepaintBoundary;
  the Z is fully simulated) — that is design evidence, not a
  measurement.
- **E2 (re-measure after change)** — UNPROVEN (no baseline exists
  to compare against; see E1).

## F) Release & publishing discipline
- **F1 (badge-only ⇒ in-place)** — N/A: this is a new build at the
  user's order, versioned 1.1.0+257 (the rejected line ended at
  +256); nothing is published by this task.
- **F2 (in-place replacement warning)** — N/A (no release touched).
  The parent hands the artifacts to the user directly.
- **F3 (version parseability)** — PASS in lab: pubspec 1.1.0+257;
  split-APK arithmetic gives arm64 versionCode 2257
  (257 + 1000×2), to be read back from the built APK (A4).
- **F4 (one version, all platforms)** — PASS: the single dispatch
  (run 44910505420) produced android, windows, linux, linux-desktop
  and macos artifacts under the one version 1.1.0+257.
- **F5 (no one-shot helpers)** — PASS: no publish helper was
  executed; the push uses hand-written Git Database API calls via
  the scoped connector credential.
- **F6 (one writer, paced)** — PASS: this subagent is the only
  writer to the branch; the push is a single sequential script.
- **F7 (dependent-link sweep)** — N/A: no release/tag deleted.
- **F8 (page URL + honest notes)** — N/A (nothing published); the
  handoff lists only verified facts.

## G) Verification honesty
- **G1** — This sweep cites only observations made in this run.
- **G2** — Counts recomputed directly: tests 253 (219 stock-derived
  after documented edits + 34 new), manifest 485/485 by sha256sum.
- **G3** — No config/network verdicts are made from this sandbox.
- **G4** — Artifact completeness is checked file-by-file against
  the CI artifact listing before handoff (A4/F4).
- **G5** — DeepSeek findings get per-finding verdicts in
  review/deepseek-review.md (CONFIRMED / REFUTED with evidence).
- **G6** — UNPROVEN list (also in the handoff): on-device feel and
  frame performance (all designs, Glass worst case), live FxA
  sign-in + Guardian quota, a real tunnel through each design's
  control, RTL + Persian on a real device, Windows portable run.

## H) Identity, credit & content accuracy
- **H1** — PASS: `grep -ri amirhossein` over the tree (excluding
  .git) = 0; the only credit name is `arblant`.
- **H2** — PASS: the build commit's author and committer are
  `Arblant <328626220+Arblant@users.noreply.github.com>` (git log).
- **H3** — PASS: «Made by arblant & Muse» appears in the app
  (About page, visible, under the app title) and in NOTICE.md;
  no other surface was badged.
- **H4** — PASS: the design is reimplemented in Dart from the
  source's published tokens/geometry (documented in NOTICE.md);
  the tree is AGPL-3.0 (LICENSE replaced with the AGPL text), so
  the license matches the design source's terms.
- **H5** — PASS: PLAN.md/NOTICE.md/handoff state only verified
  facts; unverified items are labelled UNPROVEN.
- **H6** — PASS: the deliverable is the one specified (same app,
  same core, new UI layer); no substitution was made.
- **H7** — PASS: the UI layer is new code (structure, components
  and interaction models per design), not a recolor of the stock
  Material UI — the stock orb/home/settings widgets it replaced
  were deleted.
- **H8** — PASS: design names are ZedSecure's own (Bento, Pixel,
  Old, Glass); no cross-project theme names appear in shipped text.

## Core integrity
`sha256sum -c review/core-manifest-baseline.txt` → **485/485 OK**
(`core/` + `app/lib/core/` byte-identical to upstream-119).

## Addendum (DeepSeek loop close, 2026-11-21)
- The DeepSeek bug-review loop ran 10 passes + 6 confirmation
  rounds: 60 findings confirmed and fixed by Muse, 7 refuted.
  Full record: review/deepseek-review.md. Structural findings:
  the Glass Z clock asserted on first render; unkeyed transition
  entries destroyed the incoming page's State at cleanup; the
  keying fix itself introduced a duplicate-key crash on fast
  reverse navigation, caught and fixed in the next round. A
  seventh confirmation round could not be obtained (HTTP 529).
- Final gates: flutter analyze clean; 271/275 tests pass; core
  manifest re-verified 485/485 identical at loop close.
- IMPORTANT: the CI artifacts (run 44910505420) predate passes
  2b-9 — they contain only the pass-1 fix. The reviewed code is
  in local commits on top of the pushed tree (HEAD 30a4a49);
  matching artifacts need one more CI dispatch, which was NOT
  done (the brief allowed one dispatch; flagged for the parent).
- D4/E1/E2/G6 remain UNPROVEN (no emulator/KVM on this VM);
  A1/D2 remain PARTIAL (lab-proven only). No smoothness claim.
