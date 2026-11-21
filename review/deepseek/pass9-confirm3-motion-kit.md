1. **lib/ui/zed/zed_motion.dart — `_ZedPageTransitionState.build` / `_cleanup`**  
   **Failure:** After a normal transition, `_cleanup` removes the completed outgoing entry from `_entries`. The `Stack` children are unkeyed, so the remaining entries shift index and Flutter reuses the old outgoing `Positioned.fill`/`AnimatedBuilder` element for the incoming page. The incoming page's `State` is disposed and recreated, resetting scroll positions/controllers immediately after the transition completes.  
   **Evidence:** `_cleanup` mutates `_entries` with `removeWhere`; `build` emits `for (final e in _entries) Positioned.fill(child: AnimatedBuilder(... child: e.child))` with no key on the `Positioned.fill` or `AnimatedBuilder`. The page key is only on `e.child`.

2. **lib/ui/zed/zed_motion.dart — `_ZedPageTransitionState.didUpdateWidget` / `_transform`**  
   **Failure:** A page caught mid-entrance snaps when reversed or pushed again. For example, with `ZedTransition.slide` at entrance progress `p = 0.5`, the entrance offset is `+w/3 * (1 - curve(0.5))`. Seeding the exit with `t = 1 - p = 0.5` produces an exit offset of `-w/3 * curve(0.5)` (or the mirrored sign depending on direction), which is a different visual position. This contradicts the comment that a caught page “leaves from the matching visual state instead of snapping.”  
   **Evidence:** `exit.controller.value = springy ? 1 - raw : 1 - progress;` combined with the slide/push/depth branches using different entrance and exit transform formulas.

3. **lib/ui/zed/zed_kit.dart — `ScrollDirectionTracker._onScroll`**  
   **Failure:** Slow scrolls are not detected. `_lastOffset` is updated on every scroll event, so `down`/`up` only trigger when a single event delta exceeds 4 px. A slow down-scroll with per-event delta <4 px never sets `scrollingDown`, so `BentoDock` with `dockAutoHide` never hides. After hiding, a slow up-scroll with per-event delta <4 px leaves `scrollingDown` true until the 1.6 s idle timer fires.  
   **Evidence:** `down = offset > _lastOffset + 4; up = offset < _lastOffset - 4; ... _lastOffset = offset;`.

4. **lib/ui/zed/zed_kit.dart — `_GlassTabBarState._shrinkListener`**  
   **Failure:** After the tab bar has shrunk, a slow upward scroll with per-event delta `-1` never resets `_downAccum` or `_shrunk` because the reset requires `d < -2`. The mini circle remains until a tab change or the offset reaches zero, even though the user is scrolling up.  
   **Evidence:** `else if (d < -2) { _downAccum = 0; if (_shrunk) setState(() => _shrunk = false); }`.

5. **lib/ui/zed/zed_motion.dart — `_ZedPressScaleState.didUpdateWidget`**  
   **Failure:** If the widget is disabled immediately after a pointer down, before the spring has moved `_controller.value` away from `1`, the check `_controller.value != 1` is false and no return-to-rest animation starts. The already-started spring to `pressedScale` continues, so the child scales up while disabled until pointer up.  
   **Evidence:** `if (!widget.enabled && _controller.value != 1) _to(1);` — it does not check whether an animation to a non-rest target is active.

TOTAL FINDINGS: 5