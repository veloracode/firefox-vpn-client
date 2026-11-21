# DeepSeek bug-review — record (v1.1.0+257, branch zed-v2-Muse)

Reviewer: DeepSeek-V4.1-Flash via Runcrate (custom.runcrate), bug
reports only — no implementation code, no improvements (per the
user's order). Every finding below was adjudicated by Muse against
the code and the ZedSecure token extract: CONFIRMED (reproduced or
code-proven; fixed by Muse with a regression test) or REFUTED
(code/spec evidence). Raw reports: `review/deepseek/pass*.md`.
Muse wrote 100% of the implementation and of every fix.

## Pass 1 — zed_prefs.dart + zed_labels.dart
- **CONFIRMED (1):** `PixelPrefs.fromJson` used raw `as int?` /
  `as String?` casts for the 11 custom colours and `profileId`; a
  wrong-typed value in app-settings.json would throw on every
  `zedPrefs` read (crash-loop). Fixed with `_intOrNull` /
  `_stringOrNull` helpers + regression test (corrupt-colour case).
  Commit 1638ac2 (included in the CI build).
- No other findings.

## Pass 2a — zed_theme.dart, tokens half (lines 1–850)
- **REFUTED (1):** claimed the mono palette's light `lime`/`onLime`
  tones were inverted. The extract (§1.4 Mono) specifies
  `lime 94/12 · onLime 8/96` (dark/light) verbatim — the inversion
  is the mono design itself.

## Pass 2b — zed_theme.dart, build half (lines 851–end; two runs)
Run 1:
- **REFUTED (1):** claimed `applyZedProfile` must not write the
  connect/connected colours because its comment says "connect
  untouched". The extract's `applyThemeProfile` list explicitly
  includes `customConnectColor` and `customConnectedColor`;
  "untouched" covers the connect STYLE. The comment was ambiguous,
  so it was clarified, and a test now locks the spec behaviour.
Run 2:
- **CONFIRMED (2):**
  1. AMOLED: `pixelScheme` computed the eight-role black set, but
     `ZedTheme.build` used fixed greys (0xFF111218 / 0xFF1A1B23)
     for the scaffold and card surfaces, so the AMOLED toggle
     changed nothing visible. Fixed: under Pixel/Old + amoled +
     dark, scaffold = 0xFF000000, card = 0xFF0F0F0F (the scheme's
     own roles). Regression test added.
  2. The desktop navigation rail under Glass always used
     `glass.chromeSolid`, bypassing the reduceTransparency /
     tinted-material logic in `glass.chrome`. Fixed: rail uses
     `glass.chrome`. Regression test added.

## Pass 3 — zed_motion.dart
- **CONFIRMED (6):**
  1. `ZedPressScale` used a bounded AnimationController: the
     spring clamped at 1.0 and the 1.07 Glass press never rendered
     (proven empirically: max scale 1.0). Fixed: unbounded
     controller. Regression test added (max scale > 1.03).
  2. Page-transition transforms read the CURRENT `widget.forward`
     for every entry, so an exiting page flipped direction
     mid-exit when the user reversed navigation. Fixed: each entry
     keeps the direction it started with.
  3. A page caught mid-entrance and demoted to exit restarted its
     exit from t=0 (snap to fully-entered, then exit). Fixed: the
     exit controller is seeded with the entrance's progress and a
     proportionally shortened duration.
  4. The elastic enter's spring was driven through a bounded
     controller, so the overshoot never rendered. Fixed: unbounded
     controller for spring-driven entries.
  5. The flip transition's delayed fade jumped to ≈0.41 of full
     opacity at the 90 ms delay boundary (delay never subtracted).
     Fixed: `((t·360 − 90) / 220)` clamped. Regression test added.
  6. `ZedEntrance.windowStart` was once-per-process: after the
     first 800 ms of the app's life, no entrance ever animated
     again. Fixed: a mount group after a >800 ms quiet gap starts
     a fresh window. Regression test added.
  (The entrance's own spring controller was also made unbounded —
  same clamping class as 1/4.)

## Pass 3b — zed_kit.dart
- **CONFIRMED (6):**
  1. `GlassTabBar`'s platter controller was bounded 0..1 but its
     value is a tab INDEX: the pill could never reach tab 3 or 4.
     Fixed: unbounded. Regression test added (pill start offset).
  2. Tap-expanding the shrunk tab bar left `_downAccum > 48`, so
     the next 1 px down-scroll re-shrank it instantly. Fixed:
     accumulator reset on expand (tap and tab change).
  3. `_shrinkListener` returned early while `shrinkEnabled` was
     false without updating `_lastSeen`; re-enabling made the
     whole disabled-period travel read as one delta → instant
     shrink. Fixed: anchor updated before the enabled check.
  4. `ScrollDirectionTracker._safeOffset` returned 0 whenever the
     shared controller had ≠1 positions, contradicting its own
     comment ("keep the last known offset"); a mid-transition
     attach reset the anchor and the next scroll read as a fast
     down-scroll (dock auto-hide). Fixed: anchor only overwritten
     when exactly one position exists.
  5. Same anchor-reset pattern in `GlassTabBar.didChangeDependencies`
     (`_lastSeen`). Fixed the same way.
  6. The shrunk tab bar returned an unconstrained `Center`: in the
     shell's loose-height slot it expanded to full height. Fixed:
     the branch now holds its own 62 dp height. Regression test
     added (bar height in a shell-like slot + expand behaviour).

## Pass 4a — zed_connect.dart (Bento/Pixel controls)
- **CONFIRMED (7):**
  1. Hold control: `_pressDown` returned early while busy, so the
     busy-tap-cancel branch in `_pressUp` was dead code. Fixed:
     the press registers while busy (no hold fill/timer).
     Regression test added.
  2. Hold control: after a successful 650 ms hold fired and the
     parent went busy, releasing the pointer toggled a SECOND
     time (busy-cancel). Fixed: the cancel branch is skipped when
     the press already fired (`_fired`). Regression test added.
  3. Hold control: a second pointer-down overwrote `_holdTimer`
     without cancelling the first (double-fire risk). Fixed:
     cancel-before-replace + `_fired` guard in the callback.
  4. Slide control RTL: the gesture negated dx in RTL but
     `_SlidePainter` drew the knob in raw LTR coordinates — in
     RTL the knob moved against the finger. Fixed: the painter
     takes `rtl`, mirrors the knob position and the wave's phase
     coordinate, and swaps the behind/ahead segments.
  5. `_SlidePainter.shouldRepaint` omitted `wave` (and `rtl`):
     toggling the wave pref off could leave the wavy track
     painted. Fixed: both compared.
  6. `_HoldDialPainter.shouldRepaint` omitted `busy`, `track`,
     `disc`, `glyph`. Fixed: all paint inputs compared.
  7. Slide control: a direct off→error transition (toggle fails
     without a busy phase) left the knob settled at the on end,
     because `didUpdateWidget` only settled on an `active` change
     and active stayed false. Fixed: settle also on becoming
     error.

## Pass 4b — zed_connect_glass.dart
- **CONFIRMED (4):**
  1. `GlassZConnect`'s clock controller had NO duration, so
     `repeat()` asserted on the first frame the Glass home
     rendered (reproduced in a widget test before fixing). Fixed:
     a year-long cycle duration. Regression test added.
  2. A tint change during the busy phase did not re-blend the Z
     look (condition covered only phase/dark). Fixed.
  3. `_tiltX` stayed nonzero after parallax was turned off.
     Fixed: the painter receives 0 unless parallax is on.
  4. The glass slider's move/up handlers did not re-check
     `spec.enabled`; a control disabled mid-drag could still
     toggle. Fixed. (The same guard was added to the Bento slide,
     caught during adjudication — Muse's own catch, not a
     DeepSeek finding.)

## Pass 5 — zed_home.dart
- **CONFIRMED (1):** the traffic graph only sampled when the
  rates changed, so steady traffic froze it on the text fallback.
  Fixed: seed at mount + sample on every poll rebuild.
  Regression test added.
- **REFUTED (1):** the Bento session chip can render while
  disconnected — impossible through the only caller
  (overview_page.dart builds `elapsed` as '' unless connected).

## Pass 6a — integration diff (app / shell / overview / settings store)
- **CONFIRMED (4):**
  1. The desktop rail's leading (logo + title row) overflowed
     the collapsed rail under the minimal nav styles. Fixed: the
     leading collapses with the rail.
  2. The phone content inset ignored the safe-area padding that
     the floating bar's own offset adds, so the page's last slice
     stayed under the bar on gesture-nav devices. Fixed.
  3. The Android TV hint branch (remote/OK wording) was dropped
     in the overview rewrite. Restored.
  4. Pushed routes captured prefs at push time and listened only
     to the core, so a design/wallpaper change made inside a
     pushed settings route left the route chrome stale. Fixed:
     routes listen to settings and read prefs in the builder.
- **REFUTED (1):** claimed `int.clamp` returns `num` and cannot
  compile — it returns `int`; analyze is clean and CI built both
  platforms.

## Pass 6b — integration diff (settings / welcome / servers / accounts / about)
- **CONFIRMED (3):**
  1. Choosing the "Custom" theme profile never cleared
     `profileId`, so the dropdown snapped back to the preset and
     custom colours became unreachable. Fixed.
  2. Under Bento, two same-labelled nav-style controls rendered;
     the global one is inert under Bento (a dead toggle). Fixed:
     it renders only for non-Bento designs.
  3. `DefaultTextStyle.merge(style: null)` wrapped account cards
     even with no custom text colour — not a guaranteed no-op.
     Fixed: the wrap is conditional.
- **REFUTED (1):** the static search index lists inactive
  designs' rows — that is the upstream section-level pattern and
  the contract the stock search test enforces.

## Confirmation rounds over zed_motion.dart + zed_kit.dart
The two most-edited files were re-reviewed four times at their
then-current state (passes 7, 7-retry, 8, 9). Every round found
real defects; all were fixed by Muse with regression tests:
- Pass 7 (4): the pass-3 exit seeding was INVERTED (a settled page
  started its exit already gone — fixed to t = 1 − p); press scale
  stuck when disabled mid-press; shrink accumulator not reset on
  shrinkEnabled toggle; scroll anchors went stale across
  two-position transitions.
- Pass 7-retry (4, over post-fix code): exits take the CURRENT
  navigation's direction; elastic overshoot seeding; entrance
  windows delimited by mounted-ness instead of a time gap (lazy
  rows must not restart them); shrink anchor stale when the bar
  mounts before any scroll position exists.
- Pass 8 (6): reduce-motion opacity unclamped for spring values;
  exit duration double-scaled through forward() (since reverted
  with the seeding, see pass 9); elastic exit continuity; stale
  anchors when attach/detach fires no scroll event (fixed via
  didUpdateWidget); ZedEntrance ignored `enabled` changes after
  mount; multi-pointer press released early.
- Pass 9 (5): **transition Stack children were unkeyed — the
  incoming page's State was destroyed and recreated when the exit
  entry was cleaned up** (scroll positions / text state lost
  after every tab switch; regression test verified to fail
  without the fix); the enter-progress seeding itself deviated
  from the source's interruption semantics (Compose exits run
  their own spec from t=0) — **seeding reverted**; slow scrolls
  (<4 dp/event) never registered direction or unshrink (fixed
  with anchored accumulation); press snap-back missed the
  still-animating case.
- Pass 10 (4 more confirmed): a fast reverse navigation created
  two entries with the same page key — Flutter's duplicate-key
  error (introduced by the pass-9 keying fix; regression test
  verified against the real error); the tracker's anchor was
  still overwritten by a trailing per-event assignment, negating
  the slow-scroll hysteresis; the entrance group count tracked
  enabled rather than mounted entrances; resetWindow could leave
  a null window for a later _start.
- Pass 11 (3 confirmed, 2 refuted): shrink accumulators were not
  reset at the top boundary or on a page-change resync; the
  elastic entrance's 180 ms fade ran on the spring value instead
  of elapsed time. Refuted as re-raises of pass 7-retry/9
  adjudications: exit direction at creation, and exit-from-t=0
  interruption semantics.
- A seventh confirmation round (pass 12) was attempted twice and
  could not be obtained (HTTP 529). The loop closes on six
  completed confirmation rounds; the last two rounds' confirmed
  items were narrow (accumulator resets, fade timing), and every
  file in the build has had at least one full pass.

## Final tally
- Confirmed and fixed by Muse: **60** DeepSeek findings
  (34 across passes 1–6b, +26 across the six confirmation
  rounds), plus 1 same-class fix Muse caught during
  adjudication (Bento slide enabled guard).
- Refuted with code/spec evidence: **7**.
- DeepSeek wrote no implementation code; every fix is Muse's.
  23 dedicated regression tests were added across the loop
  (prefs/theme/motion/kit/connect/home); the remaining fixes are
  construction-level (guards, condition widening, keying) verified
  by analyze + the full suite. Three tests were verified to fail
  when their fix is reverted (bounded-controller clamp probe;
  keyed-entry State preservation; duplicate-key on fast reverse
  navigation — Flutter's own error).
- Full suite at loop close: **275 tests, all passing**;
  `flutter analyze`: no issues.
