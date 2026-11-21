1. **lib/ui/zed/zed_connect.dart — `_BentoHoldConnectState._pressDown` / `_pressUp`**  
Busy tap does not cancel. When `spec.busy` is true, `_pressDown` returns before setting `_holding = true`, and `_pressUp` only toggles under `widget.spec.busy && !cancelled && _holding`; therefore a busy tap is ignored, contradicting the class comment “a busy tap cancels.”

2. **lib/ui/zed/zed_connect.dart — `_BentoHoldConnectState._pressUp`**  
Successful hold double-toggles. The 650 ms timer sets `_fired = true` and calls `onToggle`, but leaves `_holding = true`. If the parent enters `spec.busy`, releasing the still-held pointer makes `_pressUp` satisfy `widget.spec.busy && !cancelled && _holding` and calls `onToggle` again, cancelling/disconnecting the attempt.

3. **lib/ui/zed/zed_connect.dart — `_BentoHoldConnectState._pressDown`**  
Repeated pointer-down events overwrite `_holdTimer` without cancelling the previous timer. With multi-touch or a second down before the first up, multiple timers can fire while `_holding` remains true, and the callback does not check `_fired` or timer identity, causing multiple toggles.

4. **lib/ui/zed/zed_connect.dart — `_BentoSlideConnectState.onPointerMove` / `_SlidePainter.paint`**  
RTL drag math is inconsistent with the painter. The gesture negates horizontal delta in RTL (`if (rtl) dx = -dx`), but `_SlidePainter` always draws the knob at `knobR + range * pos` in left-to-right coordinates. In RTL, dragging left increases `pos`, so the knob moves right, opposite the finger, and thresholds behave reversed.

5. **lib/ui/zed/zed_connect.dart — `_SlidePainter.shouldRepaint`**  
`wave` is used by `paint` but omitted from `shouldRepaint`. In the idle state, `_wave` is not animating and `wavePhase` is stable; toggling `prefs.wave` from true to false rebuilds with `wave = false`, but `shouldRepaint` sees unchanged `pos`, `wavePhase`, `busy`, `connected`, and colors, so the old wavy track can remain painted.

6. **lib/ui/zed/zed_connect.dart — `_HoldDialPainter.shouldRepaint`**  
The painter’s `busy`, `track`, `disc`, and `glyph` inputs are not compared. If `busy` changes while `progress`, `rotation`, and `arc` happen to be unchanged (for example `_fill.value` already equals busy’s fixed `0.25`), or if only non-`arc` colors change, the painter can keep a stale rotated arc/colors.

7. **lib/ui/zed/zed_connect.dart — `_BentoSlideConnectState.onPointerUp`**  
After a drag crosses the toggle threshold from off, `_settleTo(_engaged ? 0 : 1)` uses the old `active` value and settles the knob to `1`. If `onToggle` transitions directly to `ZedPhase.error` (`active == false`, same as the old off state), `didUpdateWidget` does not correct it because `_engaged != old.spec.active` is false, leaving the knob at the connected end while the phase is error/off.

TOTAL FINDINGS: 7