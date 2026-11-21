1. **lib/ui/zed/zed_kit.dart — `_GlassTabBarState.initState` / `didUpdateWidget` / `build`**  
   `_platter` is an `AnimationController` with default bounds `0..1`, but it is treated as a tab index: `_platter.value = widget.index.toDouble()`, `animateWith(... widget.index.toDouble())`, and `start: 6 + itemW * _platter.value`. With 3+ tabs and index 2+, the controller clamps the value/target to `1`, so the selected pill stays under the second tab while the selected icon is the correct later tab.

2. **lib/ui/zed/zed_kit.dart — `_GlassTabBarState.build` shrunk `onTap` and `_shrinkListener`**  
   When the bar is shrunk, tapping the mini circle does `setState(() => _shrunk = false)` but leaves `_downAccum` unchanged. After any prior down-scroll made `_downAccum > 48`, expanding via tap and then scrolling down even 1 px satisfies `_downAccum > 48 && !_shrunk`, immediately shrinking again. Evidence: the tap handler only clears `_shrunk`; `_shrinkListener` uses the stale accumulator.

3. **lib/ui/zed/zed_kit.dart — `_GlassTabBarState._shrinkListener`**  
   When `widget.shrinkEnabled` is false, the listener returns before updating `_lastSeen`. If the user scrolls (e.g. offset 0→200) while shrink is disabled, then re-enables it, the next scroll computes `d = c.offset - _lastSeen` from the stale value (≈200), pushes `_downAccum` over 48, and shrinks immediately instead of requiring sustained new down-scroll.

4. **lib/ui/zed/zed_kit.dart — `ScrollDirectionTracker._safeOffset` / `_attach`**  
   The comment says to keep the last known offset while two scroll positions coexist, but `_safeOffset` returns `0` whenever `c.positions.length != 1`. `_attach` assigns this to `_lastOffset`, so during a transition/controller attach with two positions, the tracker resets to 0. When a single position resumes at a nonzero offset, the first scroll event compares against 0, can incorrectly set `scrollingDown`, and auto-hides the dock.

5. **lib/ui/zed/zed_kit.dart — `_GlassTabBarState.didChangeDependencies`**  
   `_lastSeen = c.positions.length == 1 ? c.offset : 0;` resets `_lastSeen` to 0 when the controller has zero/two positions. If the bar attaches during a transition with two positions and the offset is later nonzero, the first small downward scroll produces a large positive delta and can shrink the bar immediately.

6. **lib/ui/zed/zed_kit.dart — `_GlassTabBarState.build` shrunk branch**  
   The full bar constrains itself with `SizedBox(height: 62)`, but the shrunk branch returns an unconstrained `Center(child: ... SizedBox(width: 62, height: 62))`. In a bounded slot such as `Scaffold.bottomNavigationBar`, `Center` expands to the available height instead of staying 62 dp, so the “mini circle” state can take full height and break the surrounding layout.

TOTAL FINDINGS: 6