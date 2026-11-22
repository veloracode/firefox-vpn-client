# Pass A — Bug hunt (UI layer) — raw DeepSeek replies (verbatim)

Route: Runcrate `deepseek-ai/DeepSeek-V4.1-Flash-1017` (primary) / `deepseek-ai/DeepSeek-V4.1-Flash` (fallback) — free models only.

## Chunk a1-1 — model: deepseek-ai/DeepSeek-V4.1-Flash — status: 200 — incidents: ['empty reply at max-tokens 24000', 'empty reply at max-tokens 34000', 'switched to fallback deepseek-ai/DeepSeek-V4.1-Flash']

1. `settings_page.dart` — `_load` / non-general sections — load failure leaves `_config == null`, so non-general sections show an indefinite spinner with no retry/error state — `if (_config == null) const LinearProgressIndicator()`
2. `settings_page.dart` — `_save` — path traversal silently replaces an existing non-map node with `{}`, dropping unshown config data — `_ => node[key] = <String,Object?>{}`
3. `settings_page.dart` — `settingsIndex` — `l.upstreamProxy` is indexed under `SettingsSection.advanced`, but the section list exposes `SettingsSection.upstreamProxy`; search opens the wrong section and on Android advanced is absent — `(SettingsSection.upstreamProxy, ... l.upstreamProxy)`; `(SettingsSection.advanced, l.upstreamProxy)`
4. `settings_page.dart` — search hit `ListTile` — indexed setting cannot be targeted; tapping only opens the parent section, not the matching control — `onTap: () => setState(() => _open = section)`
5. `settings_page.dart` — `_removeTunService` — success is reported through `showError`, presenting a success message as an error — `showError(context, l.tunServiceRemoved)`
6. `settings_page.dart` — `_removeTunService` — after `TunServiceDone` there is no `_load()`/status refresh, so removed-TUN state can remain stale — `case TunServiceDone(): showError(...)` with no reload
7. `settings_page.dart` — `_pickLanguage` — routing config is read before `_config` is loaded because general renders before the null guard; unknown config is treated as routing disabled and can trigger an unnecessary region prompt — `_bool(['routing','enabled'])`; `if (open == general) _general(l,s) else if (_config == null)`
8. `settings_page.dart` — `_saving` — written but not read in the provided ranges; likely dead state or missing disabled-control semantics — `bool _saving = false;` / `setState(() => _saving = true);` (uncertain; omitted lines 460–540 may read it)
9. `settings_page.dart` — `settingsIndex` — indexes informational titles as settings, so search can return non-controls that only open a section — `(SettingsSection.routing, l.ruleSyntaxTitle)`; `(SettingsSection.routing, l.rulesTitle)`; `(SettingsSection.tun, l.udpNoticeSetting)`
10. `settings_page.dart` — `settingOnThisPlatform` — does not filter `l.removeTunService` / `l.tunMtu`, so if those are desktop/TUN-only, Android search can surface absent settings — `computerOnly = {...}` lacks them; `settingsIndex` includes `l.removeTunService`, `l.tunMtu` (uncertain)
11. `settings_page.dart` — `settingsIndex` — duplicate `l.removeTunService` entries under routing and advanced; may yield duplicate hits if only one control exists — `(SettingsSection.routing, l.removeTunService)` and `(SettingsSection.advanced, l.removeTunService)` (uncertain)

## Chunk a1-2 — model: deepseek-ai/DeepSeek-V4.1-Flash-1017 — status: 200 — incidents: none

**Findings (pass A1, chunk 2/2)**

1. `settings_page.dart` · autoConnect row (~L785–796) · this switch row bypasses the glass-aware helper defined 8 lines later, so on the Glass design it renders a plain Material `Switch` (the helper cannot be used there — `glassNow` is declared at L803) · `child: Switch(` … `Widget sw(bool value, …) => glassNow != null ? GlassSwitch(tokens: glassNow, …) : Switch(…)`
2. `settings_page.dart` · autoConnect row (~L787) · `onTap` and the child switch both toggle the same value; if the row's tap region overlaps the switch's padding one tap can queue two toggles (net no-op) · `onTap: () => s.update(autoConnect: !s.autoConnect)` with `value: s.autoConnect, onChanged: (v) => s.update(autoConnect: v)` — uncertain (hit-test/arena not visible).
3. `settings_page.dart` · `boolRow` (L807–820) · whole-row toggle plus switch toggle share `onChanged(!value)`; correctness depends entirely on arena resolution, and the row has no `Semantics`/`MergeSemantics` to name the setting · `onTap: () => onChanged(!value), child: sw(value, onChanged)`
4. `settings_page.dart` · `_ChoiceChip` (L2713–2714) · tap target ≈36dp tall, below the 48dp minimum · `padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)`
5. `settings_page.dart` · `_ChoiceChip` (L2698–2701) · `Semantics(label: label)` wraps a `Text` carrying the same label without `excludeSemantics: true` → screen readers announce the chip text twice · `Semantics(button: true, selected: selected, label: label,`
6. `settings_page.dart` · `_ChoiceChip` (L2698, L2712) · `button: true` is set unconditionally, so `onTap == null` (disabled) chips are still announced as actionable; no `enabled: false` · `button: true,` with `onTap: onTap,`
7. `settings_page.dart` · `_ChoiceChip` (L2697) · no disabled visual: a null `onTap` chip keeps full-onSurface text and normal outline, indistinguishable from enabled · `final fg = selected ? scheme.onSecondaryContainer : scheme.onSurface;`
8. `settings_page.dart` · `_Choice` doc (L2611–2613) · doc comment describes a centered dialog with radio buttons but the widget renders inline chips — stale doc contradicting the implementation · `/// … a tap opens the values in a dialog in the middle of the window (not a menu at the control), one radio button each.` vs `for (final (v, label, style) in options) _ChoiceChip(`
9. `zed_prefs.dart` · `ZedPrefs.navStyle` + `BentoPrefs.navStyle` · the same user setting is persisted twice (`nav_style` at top level and inside `bento`); whichever surface writes one leaves the other stale → nav style silently reverts depending on reader · `this.navStyle = ZedNavStyle.expressivePill,` / `this.navStyle = ZedNavStyle.dock,`
10. `zed_prefs.dart` · `BentoPrefs.navStyle` default vs `ZedPrefs.navStyle` default · identical enum with two different defaults (`dock` vs `expressivePill`), so the initial value depends on which field is read · `this.navStyle = ZedNavStyle.dock` / `this.navStyle = ZedNavStyle.expressivePill`
11. `zed_prefs.dart` · `_intOrNull` (and `_stringOrNull`) · rejects `num`/`double`-encoded values, so a stored `1.0`-style custom colour reads as `null` and is then written back as `null` on the next save (silent loss) · `int? _intOrNull(Object? raw) => raw is int ? raw : null;`
12. `zed_prefs.dart` · `PixelPrefs.accentIndex` · out-of-range accents are silently clamped and then persisted, with no way to recover the original choice · `accentIndex: _int(j['accent'], 0).clamp(0, 9),`
13. `zed_prefs.dart` · `_enum` + `toJson` (`'color_style': colorStyle.name`) · values are matched by exact Dart enum name (`zedSecure`, `tonalSpot`); any source/legacy convention (`zed_secure`, `ZED_SECURE`) falls back to default on read and is durably overwritten on the next save — uncertain, the Kotlin key format isn't in this excerpt · `values.asNameMap()[raw] ?? fallback` alongside `'color_style': colorStyle.name`
14. `zed_prefs.dart` · `GlassPrefs.translucent` · `material` (`clear`/`tinted`) is persisted but not consulted by the flag that drives the glass rim/highlight, so the tinted-vs-clear choice may be written-never-read · `bool get translucent => glassLists && !reduceTransparency;`
15. `zed_prefs.dart` · `_bool`/`_int`/`_enum` + `extension ZedSettings.setZed` · every wrong-typed or unknown value is coerced to a default with no diagnostic, and the coerced model is written back wholesale via `update(zed: prefs.toJson())`, making the loss permanent · `void setZed(ZedPrefs prefs) => update(zed: prefs.toJson());`

## Chunk a2-1 — model: deepseek-ai/DeepSeek-V4.1-Flash-1017 — status: 200 — incidents: ['empty reply at max-tokens 24000']

.dart — `_ShellState.build` — NavigationRail stays active while core status is null, but every destination renders the same `_NoCore`; selections are no-op. Evidence: `status == null ? _NoCore(core: core) : switch (page) {`.

2. mobile_shell.dart — `_MobileShellState.build` — When `noCore` is non-null, page ignores `_tab`, so Home/Settings tab taps only mutate state. Evidence: `final page = widget.noCore ?? (_tab == 0 ? OverviewPage(...`.

3. app.dart — `_TrafficCard.build` — Up/down traffic icons have no semantic labels, so screen readers get values without direction. Evidence: `Icon(icon, size: 14, color: color),` with no `semanticLabel`/`Semantics`.

4. mobile_shell.dart — `_MobileShellState._openHome` — Home request only resets tab; it does not dismiss pushed routes itself. Masked in this app by the ancestor Shell listener, so uncertain. Evidence: `void _openHome() => setState(() => _tab = 0);`.

5. mobile_shell.dart — `_MobileShellState.build` — Uncertain: `barBottom` is destructured but its use is not visible in the truncated excerpt. Evidence: `final (barBottom, contentInset) = switch (prefs.design) {`; only `contentInset` appears in visible padding.

## Chunk a2-2 — model: deepseek-ai/DeepSeek-V4.1-Flash-1017 — status: 200 — incidents: ['HTTP 529', 'HTTP 529']

1. file: not shown; symbol: `_SettingsListState.group` — search ignores visible group headings, so a query matching only a group title can show “no match.” Evidence: `if (matches(name)) tile`; `title` is never passed to `matches`.
2. file: not shown; symbol: `_SettingsListState.build` hit `ListTile.onTap` — a setting search hit opens only its section, not the setting; `name` is discarded for navigation. Evidence: `onTap: () => open(section, settingsSectionName(l, section))`.
3. file: not shown; symbol: `_SettingsListState.build` search `TextField` — `TextInputAction.search` is declared but has no `onSubmitted`, so the keyboard search action is a no-op. Evidence: `textInputAction: TextInputAction.search,` with no `onSubmitted`.
4. file: not shown; symbol: `_SettingsListState.build` suffix clear `IconButton` — visibility reads raw `_search.text` while filtering uses folded `_query`; whitespace-only input shows clear but does not filter. Evidence: `suffixIcon: _search.text.isEmpty ? null : IconButton(...)`; `_query = foldForSearch(v)`.
5. file: not shown; symbol: `_SettingsListState.build.hits` — uncertain: `settingOnThisPlatform(l, entry.$2)` passes localized display text; if it expects a setting key, platform filtering is wrong. Evidence: `settingOnThisPlatform(l, entry.$2)`.
6. file: not shown; symbol: `GlassTopEdge` overlay in build — uncertain touch-stealing overlay: full-width top `Positioned` child has no visible `IgnorePointer`. Evidence: `Positioned(top: 0, left: 0, right: 0, child: GlassTopEdge(...))`.

## Chunk a3-1 — model: deepseek-ai/DeepSeek-V4.1-Flash — status: 200 — incidents: ['HTTP 529', 'empty reply at max-tokens 24000', 'empty reply at max-tokens 34000', 'switched to fallback deepseek-ai/DeepSeek-V4.1-Flash']

1. zed_kit.dart: `GlassTabBar._fullBar` — tab controls lack button/selected semantics; evidence: `GestureDetector(... onTap: ... child: Column(... Icon(...), Text(...)))` with no `Semantics(selected: ...)`.
2. zed_kit.dart: `GlassTabBar` mini tab — icon-only tap control has no semantic label; evidence: `GestureDetector(onTap: ... child: ... Icon(tab.icon, ...))` with no `Semantics(label: tab.label)`.
3. zed_connect_glass.dart: `_GlassZConnectState.didUpdateWidget` — reduced-motion setting does not gate phase color animation; evidence: `_blend.forward(from: 0);` runs without checking `_animate`/`MediaQuery.disableAnimationsOf`.
4. zed_kit.dart: `_DockItem` — Semantics label duplicates child Text label; evidence: `Semantics(label: tab.label, ... Text(tab.label))` without `excludeSemantics: true`.

## Chunk a3-2 — model: deepseek-ai/DeepSeek-V4.1-Flash-1017 — status: 200 — incidents: none

. unknown file (chunk 2/2), `_ZPainter.shouldRepaint` — under-compares painted look state; changes to `look.caust/shine/spec/shade/hi/lo/rim` or `tint` may not repaint. Evidence: `old.look.a != look.a || old.look.b != look.b || old.look.glow != look.glow;`
2. unknown file (chunk 2/2), `Semantics` in `_Z...build` — disabled state is not exposed to accessibility. Evidence: `button: true, toggled: spec.on, label: spec.stateLabel,` with no `enabled: spec.enabled`.
3. unknown file (chunk 2/2), `GlassButtonConnect` — uncertain; excerpt truncates at class start, so controls/semantics cannot be assessed. Evidence: `class GlassButtonConnect extends StatelessWidget {` then `final Widget inner = Row(`.

## Chunk a4-1 — model: deepseek-ai/DeepSeek-V4.1-Flash-1017 — status: 200 — incidents: none

. zed_home.dart — `_QuickAction` — tap target is below 48dp; no minimum size constraint. Evidence: `padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9)` with `Icon(icon, size: 16)`.
2. zed_home.dart — `_TrafficStripState` (`TrafficCardStyle.graph`) — graph bars expose no semantic label/value for screen readers. Evidence: `for (final sample in _history) Expanded(child: Container(...))`; no `Semantics`.
3. zed_home.dart — `_TrafficStripState` — empty-history fallback is unreachable because `initState` always samples. Evidence: `_sample();` in `initState`; later `if (_history.isEmpty)`.
4. zed_home.dart — `_BentoHero.showQuick` — one available quick action is suppressed when the other callback is null. Evidence: `showQuick = prefs.homeQuick && onOpenServers != null && onOpenAccounts != null;`.
5. zed_connect.dart — `ZedConnectControl` — public dispatcher throws for glass design instead of handling/redirecting it. Evidence: `case ZedDesign.glass: ... throw StateError('Glass connect is dispatched by zed_connect_glass');`.

## Chunk a4-2 — model: deepseek-ai/DeepSeek-V4.1-Flash-1017 — status: 200 — incidents: none

1. `chunk2/2` — `build` / `Semantics`: toggle has button+toggled semantics but no semantic activation action, so accessibility activation cannot toggle it. Evidence: `return Semantics(button: true, toggled: spec.on, label: spec.stateLabel, child: Listener(` with no `onTap:`.
2. `chunk2/2` — `build` / `Semantics`: disabled state is not exposed to semantics. Evidence: `if (!spec.enabled) return;` but Semantics sets only `button`, `toggled`, `label` (no `enabled:`).
3. `chunk2/2` — `onPointerMove` / `onPointerUp`: while busy, drag movement is ignored but `_dragging` stays true, so release sees `moved < 0.02` and calls `onToggle()` as a tap. Evidence: `if (!_dragging || spec.busy) return;` then `if (moved < 0.02) { spec.onToggle(); ... }`.
4. `chunk2/2` — `_SlidePainter.wavePath`: no-op clamp expression `knobR - knobR`; start clamps against a constant 0. Evidence: `final start = math.max(from, knobR - knobR);`.

File name unavailable in excerpt; citations use chunk label.
