File: zed_connect_glass.dart
Function: _GlassSwitchState.build
Failure scenario: GestureDetector defaults to deferToChild; hit-testing depends entirely on child paint size. AnimatedBuilder rebuilds Container each animation tick with Stack/PositionedDirectional knob; during spring squash/knob animation the child's layout fraction changes, and tap hit region is limited to painted child extents. When tap lands outside current child hit bounds (e.g., on the 63x28 opm container's transparent margin/rounded corners or during AnimatedBuilder rebuild where hit test uses stale/animating bounds), deferToChild yields no hit and tap is dropped. Ancestor Listener still receives pointer events (squash animates) but no tap fires.
Evidence: GestureDetector has no behavior; child is AnimatedBuilder→Container(63x28, BoxDecoration borderRadius 999)→Stack→PositionedDirectional knob (37x24). Rounded corners and the gap between knob and track edges are non-hit-testable under deferToChild. Listener wraps GestureDetector and animates on down/up, proving pointers reach ancestor but not tappable child.

File: zed_connect_glass.dart
Function: _GlassSwitchState.build (AnimatedBuilder builder)
Failure scenario: Hit test occurs against the Container produced on the last frame; because _knob and _squash drive AnimatedBuilder rebuilds, hit region is recomputed each frame from PositionedDirectional knob position and Transform.scale. Rapid taps during ListView scroll fling/overscroll or while squash spring is animating can hit a frame where the child's painted bounds do not include the touch point, so deferToChild fails.
Evidence: AnimatedBuilder(animation: Listenable.merge([_knob, _squash])) rebuilds Container/Stack/knob per tick; deferred hit testing recurses to the current child render object only.

File: zed_connect_glass.dart
Function: _GlassSwitchState.build
Failure scenario: Inside a scrolling ListView, tap gesture competes with scroll gesture arena. With GestureDetector deferToChild and no explicit HitTestBehavior.opaque, the switch reports a hit only where the child paints; when the touch begins in the transparent region within the 63x28 area, the ListView drag recognizer wins and the tap is never resolved. Squash Listener still fires (pointer down/up), explaining "sometimes ignores taps."
Evidence: Listener is outside GestureDetector and receives pointers regardless; GestureDetector tap only added when enabled && onChanged != null; default behavior not set.

TOTAL FINDINGS: 3