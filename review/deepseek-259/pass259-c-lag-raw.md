# Pass C — UI-layer lag suspects — raw DeepSeek replies (verbatim)

Route: Runcrate `deepseek-ai/DeepSeek-V4.1-Flash-1017` (primary) / `deepseek-ai/DeepSeek-V4.1-Flash` (fallback) — free models only.

## Chunk c1-1 — model: deepseek-ai/DeepSeek-V4.1-Flash-1017 — status: 200 — incidents: ['HTTP 529']

1. app.dart — `_ShellState.build` — `ListenableBuilder(listenable: widget.core)` wraps Scaffold/MobileShell, NavigationRail, and page content; whole shell rebuilds on every core notification (traffic poll ~1–2 s) — full-shell rebuild at poll rate, not just traffic.

2. app.dart — `_ShellState.build` — page widgets (`OverviewPage`, `ServersPage`, `AccountsPage`, `SettingsPage`, `LogsPage`, `AboutPage`) recreated inside the core listener; `ValueKey(page)` preserves state only, subtree still rebuilds — active page subtree rebuild every poll.

3. app.dart — `_TrafficPanel` / `_TrafficCard` — rebuilt with shell; `formatRate`/`formatBytes`, `Text`, `BoxDecoration`, `line` closures recreated each poll; no RepaintBoundary — repeated formatting/alloc/layout of traffic each tick.

4. app.dart — `VpnApp.build` — `ListenableBuilder(listenable: settings)` wraps `MaterialApp`; `ZedTheme.build(...)` recomputed and whole app rebuilt on any settings change — full-app rebuild + theme allocation per pref write.

5. app.dart — `_ShellState.build` — `needsAttention` recomputed via `.where(...).length` and `accountsIcon`/`items` rebuilt every core tick — O(accounts) scan + badge tree per poll even when unchanged.

6. app.dart — `_ShellState.build` — `pages`, `items`, destination tuples, and `select` closure allocated every build; `NavigationRail` destinations recreated — allocation churn and rail diff each poll.

7. app.dart — glass root `GlassWallpaperView` — instantiated inside the core-listener rebuild; recreated each tick; if it holds BackdropFilter/image, full-screen blur/repaint per poll — full-screen repaint at poll rate.

8. app.dart — `NavigationRail(trailing: _TrafficPanel(...), scrollable: true)` — traffic updates force rail relayout with scrollable trailing; no isolation/RepaintBoundary — rail relayout every tick.

9. mobile_shell.dart — `_MobileShellState.build` — parent Shell already rebuilds on core; build constructs `OverviewPage`/`_SettingsList`, `tabs`, offsets, and push closures — mobile page subtree rebuild every poll.

10. mobile_shell.dart — `_push` — `ListenableBuilder(Listenable.merge([core, settings]))` wraps whole route Scaffold + AppBar + GlassWallpaperView; new merged listenable per push — full route rebuild every core tick while open.

11. mobile_shell.dart — `_push` / shell / tab bar — `GlassWallpaperView` per pushed route plus shell `GlassWallpaperView` plus `GlassTabBar` blur — stacked BackdropFilter/blur layers; GPU overdraw scales with route depth.

12. mobile_shell.dart — `_MobileShellState.build` — `ZedTab` list, `tabs`, bar-offset switch, and `select` closure allocated each rebuild — minor allocation churn per poll.

13. mobile_shell.dart — `_MobileShellState.build` — `KeyedSubtree(key: ValueKey(_tab))` around page does not prevent rebuild when same tab; page recreated each poll — page subtree rebuild despite unchanged tab.

14. app.dart — `_TrafficCard.build` — `value` `copyWith`, `line` closures, `Container` decoration allocated each rebuild — minor per-tick allocation.

15. app.dart / mobile_shell.dart — `GlassWallpaperView(wallpaper: prefs.glass.wallpaper)` — call sites show no `cacheWidth`/`cacheHeight`/decode-size hint; wallpaper re-passed on every rebuild and per pushed route — risk of full-size image decode/re-decode and large memory, especially with multiple route instances.

## Chunk c1-2 — model: deepseek-ai/DeepSeek-V4.1-Flash-1017 — status: 200 — incidents: none

. `settings_page.dart` — `_SettingsListState.build` — `TextField.onChanged` calls `setState` per keystroke, rebuilding entire settings `ListView`, all groups/rows, and search hits — O(rows+index) UI work per character; typing jank.
2. `settings_page.dart` — `_SettingsListState.build` — `group(...)` arguments eagerly construct every `section`/`row` tile before filtering, so hidden rows are still allocated/built — O(all rows) per keystroke/rebuild.
3. `settings_page.dart` — `_SettingsListState.build` — `settingsIndex(l)` and repeated `foldForSearch` run inside build for nonempty query — index recreated/scanned each keystroke; O(index) allocations/compares; cache folded index per locale.
4. `settings_page.dart` — `_SettingsListState.build` — `ListView(children: [...])` eagerly builds all children, no lazy builder — offscreen tiles built on every rebuild; O(total settings) widget construction.
5. `settings_page.dart` — `_SettingsListState.build` — local closures/records/lists (`matches`, `group`, `tile`, `section`, `row`, `groups`, `hits`, `kept`) allocated every rebuild — GC churn per keystroke/parent rebuild.
6. shell file (not shown) — shell build/`GlassTopEdge` — full-width glass top edge inside shell `Stack`; if it uses `BackdropFilter` alongside a glass bar, two blur layers — extra GPU blur/saveLayer passes per frame.
7. shell file (not shown) — shell build/`bar` + `GlassTopEdge` — inline shell overlays with no `RepaintBoundary`; parent shell rebuilds (~2s poll) repaint bar/glass subtree — cost proportional to shell paint/GPU work.

## Chunk c2-1 — model: deepseek-ai/DeepSeek-V4.1-Flash-1017 — status: 200 — incidents: none

FINDINGS ONLY

1. overview_page.dart — OverviewPage/_DesktopHome — consumes `core.status!`/settings directly with no AnimatedBuilder/ValueListenableBuilder scoping; whole Stack, `_Glow`s, SingleChildScrollView, and `_content` rebuild on every core status tick/poll (~2 s). Cost: full home build+layout+repaint per poll; scroll jank.
2. overview_page.dart — _DesktopHome.build — three `_Glow` background widgets recreated inside Stack every shell rebuild though static; no const/RepaintBoundary isolation. Cost: large soft-gradient layout/raster churn each poll; moderate-high.
3. zed_glass.dart — _GlassEdgePainter.paint — per-paint `Path`, `Path.combine`, `Paint`, and `LinearGradient.createShader`; no cache keyed by size/radius/tokens. Cost: allocations/path ops per GlassSurface per paint; high with many cells/modules.
4. zed_glass.dart — GlassSurface.build — new `_GlassEdgePainter`/`CustomPaint` every build; `Directionality.of` and non-const wrappers; shouldRepaint prevents paint but not widget/painter allocation. Cost: rebuild churn under list updates; moderate.
5. zed_glass.dart — GlassSurface — per-cell/module ClipRRect + foreground edge painter, no RepaintBoundary; many glass cells clip/repaint together. Cost: O(cells) clip/path paint during scroll; moderate-high.
6. zed_glass.dart — GlassChromeSurface — each instance adds BackdropFilter blur 12 + BoxShadow blur 24; RepaintBoundary isolates repaint but not backdrop sampling/saveLayer. Cost: GPU blur/shadow multiplies with chrome count/overlap; high.
7. zed_glass.dart — GlassTopEdge — ShaderMask + ClipRect + BackdropFilter blur 10 across full-width status strip; no RepaintBoundary; shaderCallback creates gradient shader. Cost: offscreen saveLayer/blur/mask redone on parent rebuild; moderate-high.
8. zed_glass.dart — GlassTopEdge — BackdropFilter over top edge only clipped, not otherwise cached; shell rebuilds (~2 s) re-run blur sampling. Cost: recurring status-strip GPU blur; moderate.
9. zed_glass.dart — GlassWallpaperView/_WallpaperPainter — RepaintBoundary and value shouldRepaint present, but build recreates painter and paint allocates gradients/shaders. Cost: low unless resize/theme change.
10. overview_page.dart — _DesktopHome._content — all derived status values and card list rebuilt inside every shell rebuild; no memoization/scoped sections. Cost: extra allocations/child rebuilds per poll; moderate.

## Chunk c2-2 — model: deepseek-ai/DeepSeek-V4.1-Flash-1017 — status: 200 — incidents: none

1. `home_screen.dart (chunk2)` · `build/Column@444` · status/core listener causes full Column rebuild on every ~2s poll · full subtree rebuild; jank every poll.
2. `home_screen.dart` · `ZedHero@447` · receives fresh rate text/rates/spec every build; no RepaintBoundary/isolated rate area · hero rebuild + possible full-layer repaint; medium-high if animated.
3. `home_screen.dart` · `_zedSpec@449` · spec object and closures recreated each build; identity churn forces Hero update · unnecessary hero rebuild; medium.
4. `home_screen.dart` · `_ModeSwitch@577` · fresh `modes` record list + `onSelected` closure at 584-600 every build · allocation + child rebuild; low-medium per poll.
5. `home_screen.dart` · `onToggle@462` · new closure passed to Hero each build · callback identity churn; low.
6. `home_screen.dart` · `_HomeData@437` · new data records each build · equality/rebuild churn; low.
7. `home_screen.dart` · `Text@486`/`Text@518` · `textTheme...copyWith` allocates TextStyle every rebuild · GC churn each poll; low.
8. `home_screen.dart` · `formatRate@466-469` · repeated formatting and `toDouble` per build · minor CPU/alloc; low.
9. `home_screen.dart` · `Wrap@477` · dynamic delay/IP/upstream pills rebuilt with parent; no RepaintBoundary around updating pill area · rebuild/repaint bleed; low-medium.
10. `home_screen.dart` · `FilledButton.tonalIcon@554` · async `onPressed` closure allocated each build · minor alloc; low.
11. `home_screen.dart` · `Tooltip@514` · tooltip state/message rebuilt on status ticks · minor state churn; low.
12. No BackdropFilter, AnimatedBuilder, or full-size image decode findings in this chunk.

## Chunk c3-1 — model: deepseek-ai/DeepSeek-V4.1-Flash-1017 — status: 200 — incidents: ['empty reply at max-tokens 24000']

1. zed_connect.dart — `_SlidePainter` — rebuilt in `AnimatedBuilder(Listenable.merge([_pos,_wave]))`; new `Listenable.merge` + new painter allocated every frame — per-frame alloc, full card repaint.
2. zed_connect.dart — rail card — `AnimatedBuilder(_travel,_wave)` wraps whole `Stack` (Positioned.fill + CustomPaint + label) — whole card subtree rebuilt per frame; wrap only CustomPaint.
3. zed_connect.dart — morph card — `BlobPainter` allocated inside `AnimatedBuilder(Listenable.merge([_morph,_spin,_drift]))` — new painter each frame.
4. zed_connect.dart — 4-pt toggle — `BlobPainter` allocated inside `AnimatedBuilder(_morph,_spin)` — new painter each frame.
5. zed_connect.dart — 6+ `CustomPaint`s (SlidePainter/RailWavePainter/HoldDialPainter/BlobPainter) — no `RepaintBoundary` — repaints propagate to card `AnimatedContainer` and siblings.
6. zed_connect.dart — press buttons — `Listener.onPointerDown/Up` calls `setState(_pressed)` — rebuilds entire button Row (siblings + GestureDetector) each press.
7. zed_connect_glass.dart — parallax card — `MouseRegion.onHover` `setState(_tiltX)` on every pointer move, no throttle — full card rebuild per micro-move.
8. zed_connect_glass.dart — `_ZPainter` — `AnimatedBuilder(Listenable.merge([_clock,_blend]))` wraps whole CustomPaint — new painter per frame, clock-driven.
9. zed_connect_glass.dart — `_ZPainter` under-glow — `MaskFilter.blur(BlurStyle.normal, 22)` every frame, no cached layer/RepaintBoundary — expensive GPU blur per tick.
10. zed_connect_glass.dart — switch — `AnimatedBuilder(_knob,_squash)` wraps full track+knob with `BoxShadow`s — whole switch rebuilt per frame.
11. zed_connect_glass.dart — mini toggle — `_MiniZPainter` CustomPaint re-instantiated inside `AnimatedBuilder(_pos,_shimmer)` — new painter per frame.
12. zed_kit.dart — `_onScroll` — `setState(scrollingDown)` on every delta + 1600ms idle `Timer` — rebuilds entire dock shell (AnimatedSlide/Opacity) per scroll tick.
13. zed_kit.dart — dock auto-hide — `AnimatedSlide` + `AnimatedOpacity` wrap whole dock `Container` — full dock subtree repaint on every hide/show transition.
14. zed_kit.dart — bar morph — `AnimatedBuilder(_platter)` wraps `LayoutBuilder`→`Stack` with `AnimatedPositionedDirectional` + labels — whole bar rebuilt per morph frame.
15. zed_connect_glass.dart — BackdropFilter — none present in excerpts (comment explicitly: "static-shape blur, not backdrop blur"); count = 0, no placement issue. Missing from other files unavailable in this chunk.
