# DeepSeek root-cause review — +258 fix round (the three +257 device bugs)

Reviewer: DeepSeek via Runcrate (custom.runcrate), root causes ONLY —
no code, no fixes, no improvements (user's standing order). Muse
adjudicated every finding against the code and wrote 100% of the
fixes. Raw reports: `review/deepseek-258/pass258-*.md`.

Route notes: `deepseek-ai/DeepSeek-V4-Flash-0731` and
`DeepSeek-V3.2` return HTTP 402 (no credits). The free
`DeepSeek-V4.1-Flash` answered the I2 pass but burned its whole
token budget on reasoning (empty replies) for the I1 passes; the
I1/I3 passes therefore ran on `deepseek-ai/DeepSeek-V4.1-Flash-1017`
(same model family, cost 0, replies intact).

## I2 — dock morph snaps (pass258-1, V4.1-Flash): 4 findings, 4 CONFIRMED
All four state one root cause, code-proven in
`_GlassTabBarState` (zed_kit.dart): the shrink was a boolean flip
(`_downAccum > 48 → setState(() => _shrunk = true)`) and `build`
swapped the whole subtree on it (`if (_shrunk) return …circle…;
return …bar…`). No interpolated morph value existed; the only
AnimatedBuilder served the platter and lived inside the bar branch.
FIX (Muse): an unbounded `_morph` controller (0 = bar, 1 = mini)
springs with `springMediumLow` (dampingRatio 1.0, stiffness 400 —
the Compose default behind the source's AnimatedContent
fadeIn+scaleIn(0.9) / fadeOut+scaleOut(0.9)); both states stay in
the tree in a Stack, crossfading and scaling with the morph value;
only the mostly-reached state takes taps (IgnorePointer at t=0.5).
Every `_shrunk` mutation now goes through `_setShrunk`.

## I1 — taps lost / dead buttons
### GlassSwitch (pass258-2a, V4.1-Flash-1017): 3 findings — 2 CONFIRMED (one root), 1 REFUTED
- CONFIRMED: `GestureDetector` had no `behavior` (deferToChild) and
  the visual is a 63×28 stadium — corner cut-outs are not
  hit-testable and 28 dp is under a finger's reliable height, so
  real taps missed the detector entirely.
- CONFIRMED (contributor, same root): a touch starting in a
  non-hit region never enters the tap recognizer, so the ListView's
  drag recognizer wins the arena — "sometimes" behaviour.
- REFUTED: the claim that AnimatedBuilder rebuilds make hit testing
  use stale/animating bounds. The switch's layout is constant
  during the knob/squash animations (the knob moves inside a fixed
  63×28 box) and hit testing always uses current render objects.
FIX (Muse): `HitTestBehavior.opaque` + the detector now owns a
63×48 hit box with the 63×28 visual centred.

### Settings rows & structure (pass258-2b, V4.1-Flash-1017): 6 findings — 1 CONFIRMED, 1 MOOT, 4 REFUTED (+1 partial refutation)
- CONFIRMED: switch rows built by `boolRow` (and the other
  `_Row(child: Switch…)` sites) had NO row onTap — tapping the
  label/icon (most of the row) did nothing at all. FIX (Muse):
  every switch row in settings_page.dart now toggles from the whole
  row (13 sites: boolRow helper, general panel ×6, Pixel AMOLED,
  routing ×3, TUN notice, DNS fallback).
- MOOT (was a real code observation): `_Choice._open` had no
  re-entrancy guard, so a fast double-tap could stack two picker
  dialogs. The I3 rework removed the dialog from `_Choice`
  entirely; no separate fix needed.
- REFUTED (addendum to the confirmed finding): the claim that the
  ~2 s core-poll rebuild "replaces gesture recognizers mid-gesture"
  because rows have no keys. A rebuild producing the same widget
  shape preserves elements and their recognizers (key or not);
  recognizers die only when the subtree structure changes. No
  code instance was or could be cited.
- REFUTED: InkWell splash "occluded by Container margin" — cosmetic
  speculation, no tap-loss mechanism; splashes render.
- REFUTED: dock/tab opaque GestureDetectors "swallowing or
  doubling" taps — the slots are disjoint Expanded children; the
  new first-tap tests (zed_device_bugs_258_test) show single,
  correct selection.
- REFUTED: connect-button taps lost to the poll rebuild — same
  refuted mechanism as above; the buttons wrap hit-testable
  coloured containers.
- REFUTED: `under:` rows' margin "offsetting the hit area" — the
  margin is inside the InkWell's own box; padding is visual only.

## I3 — settings rows are labels only (pass258-3, V4.1-Flash-1017): 9 findings — 6 CONFIRMED, 3 REFUTED
- CONFIRMED ×5 (one structural gap): `_Choice` rendered icon +
  title + current-value text and hid all options behind the
  `_pickOne` modal — no inline options, no visible selected state,
  no title+summary+options layout, no chip fallback for long
  labels. The source (SettingsItem.kt) renders SettingsChoiceRow:
  title/summary, then ALL options inline as ConnectedChoices or
  ChoiceChips, applied on tap. FIX (Muse): `_Choice` now renders
  the title row plus a Wrap of option chips (selected = filled +
  check glyph), applying onChanged on tap; used by every enum
  setting in the app (general, interface + per-design panels, DNS
  preset, sleep choice).
- CONFIRMED (minor): per-option label styles (e.g. a language in
  its own font) were discarded by the row rendering. The chips now
  carry each option's TextStyle.
- REFUTED ×3: the speculative binding failures (value read from a
  different field than onChanged writes; persisted type/key
  mismatch emptying the label; onChanged-null decorative rows).
  No call site exhibits any of them: every `_Choice` site reads and
  writes the same field, and the only null-onChanged site is the
  DNS preset while `_saving` (a transient busy state, by design).

## Muse's own audit (no DeepSeek prompt): dead-toggle sweep
Every ZedPrefs field was traced to a consumer outside
settings_page/zed_prefs (the +256 dead-toggle class):
bento.* (theme, dock, home, connect, servers), pixel.* (theme
scheme incl. `contrast` → `contrastLevel` at zed_prefs.dart:247 →
zed_theme pixelScheme; trafficTileSize → zed_home), glass.*
(tint/material → zed_theme.dart:1121 glassTokensFor; wallpaper,
glassLists, shrinkTabBar, motionHighlights → connect parallax,
homeTimer/homeCard/homeSpeed → zed_home/overview), prefs.design /
transition / reduceMotion / navStyle (shells + motion). Both
navStyle fields are read (ZedPrefs.navStyle → mobile_shell bar
style; BentoPrefs.navStyle → app.dart insets). RESULT: no dead
toggles in this tree.

## Tally
22 findings: 13 confirmed (all fixed by Muse), 1 moot (removed
with the dialog path), 8 refuted with code evidence (one a partial
refutation of an addendum to a confirmed finding). DeepSeek wrote
no code.
