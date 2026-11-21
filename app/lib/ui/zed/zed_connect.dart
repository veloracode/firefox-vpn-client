import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'zed_glass.dart';
import 'zed_prefs.dart';
import 'zed_theme.dart' show glassTintColor;

/// The connect controls, one kit per design, reimplemented from the
/// documented ZedSecure v3.2.0 variant catalogue (§25):
/// Bento {Slide (0.72 threshold), Button, Morph, Rail, Hold (650 ms),
/// Tile}, Pixel/Old {Pill, Hero, Ring, Bar, Icon, Switch},
/// Glass {Z, Button, Switch, Slider}. Every control drives the same
/// three states — off, busy (starting/unconfirmed), live — and the same
/// single toggle action; only the instrument differs.

class ZedConnectState {
  const ZedConnectState({
    required this.on,
    required this.busy,
    required this.live,
    required this.label,
    required this.onToggle,
    this.tooltip = '',
  });

  /// The power tooltip ("Tap to connect" / "Tap to disconnect") — the
  /// homes have always named the power this way.
  final String tooltip;

  /// The engine's power (phase != off).
  final bool on;

  /// Starting, or running but not yet confirmed by a connection test.
  final bool busy;

  /// Running and confirmed live.
  final bool live;

  /// The state's word (Connected / Connecting / Off …).
  final String label;

  final VoidCallback onToggle;
}

Color _stateColor(BuildContext context, ZedConnectState s) {
  final scheme = Theme.of(context).colorScheme;
  if (s.live) return scheme.primary;
  if (s.busy) return scheme.tertiary;
  return scheme.onSurfaceVariant;
}

/// The foreground that belongs ON [_stateColor]'s background for the
/// same state — pairing onPrimary with the busy (tertiary) or off
/// (onSurfaceVariant) backgrounds mismatches the colour roles and can
/// fail contrast (e.g. white on the Bento lime).
Color _onStateColor(BuildContext context, ZedConnectState s) {
  final scheme = Theme.of(context).colorScheme;
  if (s.live) return scheme.onPrimary;
  if (s.busy) return scheme.onTertiary;
  return scheme.onSurface;
}

/// The wait's progress mark, shown by every connect control while the
/// state is busy: a spinner, or — when the system asks for reduced
/// motion — the same arc standing still (no animation runs at all).
/// Its own widget type so the mark is one identifiable thing.
class _BusyMark extends StatelessWidget {
  const _BusyMark({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return SizedBox(
        width: 22,
        height: 22,
        child: CustomPaint(painter: _BusyArcPainter(color)),
      );
    }
    return SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(strokeWidth: 2.5, color: color),
    );
  }
}

/// A still 72% arc — the spinner's pose with the motion taken out.
class _BusyArcPainter extends CustomPainter {
  const _BusyArcPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawArc(Offset.zero & size, -1.5708, 4.5239, false, paint);
  }

  @override
  bool shouldRepaint(_BusyArcPainter old) => old.color != color;
}

Widget _busyMark(BuildContext context, ZedConnectState s, Color color) => s.busy
    ? _BusyMark(color: color)
    : Icon(
        s.live ? Icons.power_settings_new_rounded : Icons.power_settings_new,
        color: color,
        size: 26,
      );

/// The control for the current design + the design's chosen style.
class ZedConnectControl extends StatelessWidget {
  const ZedConnectControl({
    super.key,
    required this.prefs,
    required this.state,
  });

  final ZedPrefs prefs;
  final ZedConnectState state;

  @override
  Widget build(BuildContext context) {
    final control = _control(context);
    // Every control may carry the tooltip: the drag-primary controls
    // (Slide/Slider) and the Hold track their pointers through a
    // Listener, OUTSIDE the gesture arena, so the Tooltip's
    // long-press recognizer can never cancel them (a press that
    // pauses before sliding used to lose the arena to the tooltip
    // and the drag silently died — round-2 regression, proven by
    // zed_tooltip_slide_test.dart). Tap-primary controls follow the
    // platform's accepted behaviour: press-and-hold shows the hint
    // instead of activating.
    return state.tooltip.isEmpty
        ? control
        : Tooltip(message: state.tooltip, child: control);
  }

  Widget _control(BuildContext context) => switch (prefs.design) {
    ZedDesign.bento => switch (prefs.bentoConnect) {
      BentoConnectStyle.slide => _SlideConnect(state: state),
      BentoConnectStyle.button => _ButtonConnect(state: state, big: true),
      BentoConnectStyle.morph => _MorphConnect(state: state),
      BentoConnectStyle.rail => _RailConnect(state: state),
      BentoConnectStyle.hold => _HoldConnect(state: state),
      BentoConnectStyle.tile => _TileConnect(state: state),
    },
    ZedDesign.pixel => _pixelControl(prefs.pixelConnect),
    ZedDesign.old => _pixelControl(prefs.oldConnect),
    ZedDesign.glass => switch (prefs.glassConnect) {
      GlassConnectStyle.z => _GlassZConnect(state: state),
      GlassConnectStyle.button => _ButtonConnect(state: state, big: true),
      GlassConnectStyle.switchStyle => _SwitchConnect(
        state: state,
        prefs: prefs,
      ),
      GlassConnectStyle.slider => _GlassSlideConnect(
        state: state,
        prefs: prefs,
      ),
    },
  };

  Widget _pixelControl(PixelConnectStyle style) => switch (style) {
    PixelConnectStyle.pill => _ButtonConnect(state: state, big: false),
    PixelConnectStyle.hero => _HeroConnect(state: state),
    PixelConnectStyle.ring => _RingConnect(state: state),
    PixelConnectStyle.bar => _BarConnect(state: state),
    PixelConnectStyle.icon => _IconConnect(state: state),
    PixelConnectStyle.switchStyle => _SwitchConnect(state: state),
  };
}

/// Slide-to-toggle: the wave track completes at a 0.72 drag fraction
/// (§25). Sliding back while live disconnects by the same rule.
class _SlideConnect extends StatefulWidget {
  const _SlideConnect({required this.state});

  final ZedConnectState state;

  @override
  State<_SlideConnect> createState() => _SlideConnectState();
}

class _SlideConnectState extends State<_SlideConnect> {
  /// The drag fraction while a drag is in flight; null at rest. (A
  /// plain 0 cannot mean "at rest": 0 is also the knob's left end, and
  /// conflating the two snapped the knob back mid-drag.)
  double? _drag;

  /// Pointer tracking, deliberately OUTSIDE the gesture arena (a
  /// Listener, like the Hold control): the wrapping Tooltip's
  /// long-press recognizer wins the arena at ~500 ms, and a
  /// GestureDetector drag that pauses before sliding was cancelled
  /// by it — the slide silently did nothing. Pointer events reach a
  /// Listener regardless of who wins the arena.
  int? _pointer;
  double _downX = 0;

  /// The pointer's travel past the touch slop at the last move event
  /// (the drag's effective distance is measured from beyond the slop,
  /// exactly as the arena recognizer accounted it).
  double _lastBeyond = 0;
  DateTime? _downAt;

  void _slideDown(PointerDownEvent e) {
    if (_pointer != null) return;
    _pointer = e.pointer;
    _downX = e.position.dx;
    _lastBeyond = 0;
    _downAt = DateTime.now();
  }

  void _slideMove(PointerMoveEvent e, double travel, bool rtl) {
    if (e.pointer != _pointer) return;
    // The drag starts only past the touch slop, mirroring the arena
    // recognizer this replaces: sub-slop movement is still a tap,
    // and the slop itself never counts as knob travel.
    final total = e.position.dx - _downX;
    if (_drag == null && total.abs() <= 18) return;
    final beyond = total - 18 * total.sign;
    final dBeyond = beyond - _lastBeyond;
    _lastBeyond = beyond;
    // travel is 0 when the control is narrower than the knob;
    // dividing by it would poison the drag fraction with NaN. In RTL
    // the track is mirrored, so the physical delta's sign flips.
    if (travel <= 0 || dBeyond == 0) return;
    final rest = widget.state.on ? 1.0 : 0.0;
    final dx = rtl ? -dBeyond : dBeyond;
    setState(() => _drag = ((_drag ?? rest) + dx / travel).clamp(0, 1));
  }

  void _slideUp(PointerUpEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    final s = widget.state;
    final drag = _drag;
    if (drag == null) {
      // No drag happened: a plain tap — the power has always
      // answered a tap. But a press held past the long-press
      // deadline was the user reading the tooltip (which the arena
      // would have awarded the press to), not a tap: don't toggle.
      final held = _downAt == null
          ? Duration.zero
          : DateTime.now().difference(_downAt!);
      if (held < const Duration(milliseconds: 500)) s.onToggle();
      return;
    }
    // The knob's landing zone decides: from off, only a drag past
    // the connect threshold connects; from on, only a drag back
    // under the stay threshold disconnects — anything less springs
    // back. Bento's slide is 0.72/0.28 (§25); the Glass slider has
    // its own control (_GlassSlideConnect) with its own 0.70/0.30.
    final endOn = s.on ? drag >= 0.28 : drag > 0.72;
    if (endOn != s.on) s.onToggle();
    setState(() => _drag = null);
  }

  void _slideCancel(PointerCancelEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    if (_drag != null) setState(() => _drag = null);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final color = _stateColor(context, s);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const knob = 56.0;
        final travel = (width - knob - 8)
            .clamp(0.0, double.infinity)
            .toDouble();
        final rest = s.on ? 1.0 : 0.0;
        final frac = _drag ?? rest;
        return Listener(
          onPointerDown: _slideDown,
          onPointerMove: (e) => _slideMove(e, travel, rtl),
          onPointerUp: _slideUp,
          onPointerCancel: _slideCancel,
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    s.label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                AnimatedPositionedDirectional(
                  // While a drag is in flight the knob must track the
                  // finger 1:1 — animating each update makes it lag
                  // and undershoot; the 220 ms glide is for the
                  // release snap and state changes at rest.
                  duration: reduced || _drag != null
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  start: 4 + travel * frac,
                  top: 4,
                  child: Container(
                    width: knob,
                    height: knob,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: _busyMark(context, s, _onStateColor(context, s)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The Glass slider: the original's dedicated GlassSlideControl
/// (§2 of the extract, GlassControls.kt) — NOT the shared Bento
/// slide with a glass flag, which is what the port ran through
/// round 2. Its own geometry: a 74 dp glass-chrome track (the
/// recipe's real-blur chrome capsule, radius 37), a 64 dp white
/// knob resting 5 dp in, carrying the Z mark (30 dp; the glass
/// tint while off, #FFB06CFF while on), and the state label centred
/// with 72 dp of clearance on the knob's resting side, shimmering
/// on a 2600 ms sweep while it waits. Landing thresholds are the
/// slider's own 0.70 / 0.30. Pointer tracking is the slide's
/// Listener pattern — outside the gesture arena, so the wrapping
/// Tooltip can never cancel a paused drag — and the knob's motion
/// is physical-left based, as in the source. The source's springs
/// (stiff flip, 0.6-damped snap-back) are expressed as the kit's
/// ease curves, like the glass switch's.
class _GlassSlideConnect extends StatefulWidget {
  const _GlassSlideConnect({required this.state, required this.prefs});

  final ZedConnectState state;
  final ZedPrefs prefs;

  @override
  State<_GlassSlideConnect> createState() => _GlassSlideConnectState();
}

class _GlassSlideConnectState extends State<_GlassSlideConnect>
    with SingleTickerProviderStateMixin {
  double? _drag;
  int? _pointer;
  double _downX = 0;
  double _lastBeyond = 0;
  DateTime? _downAt;
  bool _reduced = false;

  /// The label shimmer's sweep; runs only while the control waits
  /// idle — never while busy, never under reduced motion.
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    _syncShimmer();
  }

  @override
  void didUpdateWidget(_GlassSlideConnect old) {
    super.didUpdateWidget(old);
    _syncShimmer();
  }

  void _syncShimmer() {
    if (widget.state.busy || _reduced) {
      if (_shimmer.isAnimating) _shimmer.stop();
      if (_shimmer.value != 0) _shimmer.value = 0;
    } else if (!_shimmer.isAnimating) {
      _shimmer.repeat();
    }
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  void _down(PointerDownEvent e) {
    if (_pointer != null) return;
    _pointer = e.pointer;
    _downX = e.position.dx;
    _lastBeyond = 0;
    _downAt = DateTime.now();
  }

  void _move(PointerMoveEvent e, double travel, bool rtl) {
    if (e.pointer != _pointer) return;
    final total = e.position.dx - _downX;
    if (_drag == null && total.abs() <= 18) return;
    final beyond = total - 18 * total.sign;
    final dBeyond = beyond - _lastBeyond;
    _lastBeyond = beyond;
    if (travel <= 0 || dBeyond == 0) return;
    final rest = widget.state.on ? 1.0 : 0.0;
    final dx = rtl ? -dBeyond : dBeyond;
    setState(() => _drag = ((_drag ?? rest) + dx / travel).clamp(0, 1));
  }

  void _up(PointerUpEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    final s = widget.state;
    final drag = _drag;
    if (drag == null) {
      // A plain tap toggles — unless the press was held past the
      // long-press deadline, which was the user reading the tooltip.
      final held = _downAt == null
          ? Duration.zero
          : DateTime.now().difference(_downAt!);
      if (held < const Duration(milliseconds: 500)) s.onToggle();
      return;
    }
    final endOn = s.on ? drag >= 0.30 : drag > 0.70;
    if (endOn != s.on) s.onToggle();
    setState(() => _drag = null);
  }

  void _cancel(PointerCancelEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    if (_drag != null) setState(() => _drag = null);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final prefs = widget.prefs;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final tint = glassTintColor(prefs.glassTint, dark);
    final markColor = s.on ? const Color(0xFFB06CFF) : tint;
    // While the shimmer runs the label wears the full label colour;
    // still (busy / reduced motion) it drops to the secondary label
    // token, exactly as the source switches label → label2.
    final labelColor = Theme.of(context).colorScheme.onSurface;
    final stillColor = dark ? const Color(0x99EBEBF5) : const Color(0x993C3C43);
    final frac = _drag ?? (s.on ? 1.0 : 0.0);
    final shimmering = !s.busy && !_reduced;
    Widget label = Text(
      s.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w500,
        color: shimmering ? Colors.white : stillColor,
      ),
    );
    if (shimmering) {
      label = AnimatedBuilder(
        animation: _shimmer,
        builder: (context, child) => ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            colors: [
              labelColor.withValues(alpha: 0.35),
              labelColor,
              labelColor.withValues(alpha: 0.35),
            ],
            // The source's band: full colour at 0.45, dim by 0.9.
            stops: const [0, 0.45, 0.9],
            transform: _SweepGradient((_shimmer.value * 2 - 1) * bounds.width),
          ).createShader(bounds),
          child: child,
        ),
        child: label,
      );
    }
    return Semantics(
      button: true,
      toggled: s.on,
      label: s.label,
      onTap: s.onToggle,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final travel = math.max(1.0, constraints.maxWidth - 64 - 10);
          return Listener(
            onPointerDown: _down,
            onPointerMove: (e) => _move(e, travel, rtl),
            onPointerUp: _up,
            onPointerCancel: _cancel,
            child: SizedBox(
              height: 74,
              child: GlassChrome(
                prefs: prefs,
                radius: 37,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AnimatedPadding(
                        duration: _reduced
                            ? Duration.zero
                            : const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        padding: EdgeInsetsDirectional.only(
                          start: s.on ? 0 : 72,
                          end: s.on ? 72 : 0,
                        ),
                        child: Center(child: label),
                      ),
                    ),
                    AnimatedPositioned(
                      duration: _reduced || _drag != null
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      left: 5 + travel * frac,
                      top: 5,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x40000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: s.busy
                              ? _BusyMark(color: markColor)
                              : CustomPaint(
                                  size: const Size(30, 30),
                                  painter: _ZMarkPainter(markColor),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The shimmer's travelling gradient: the α0.35 → 1 → α0.35 band
/// swept across the label by the animation's progress.
class _SweepGradient extends GradientTransform {
  const _SweepGradient(this.dx);

  final double dx;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(dx, 0, 0);
}

/// The Z glyph of the original's vector mark (viewBox origin
/// 98.5, 111; size 315×290), fitted into the knob's 30 dp box.
class _ZMarkPainter extends CustomPainter {
  const _ZMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(161, 111)
      ..lineTo(413.5, 111)
      ..lineTo(174.75, 331)
      ..lineTo(351, 331)
      ..lineTo(413.5, 401)
      ..lineTo(98.5, 401)
      ..lineTo(98.5, 298.5)
      ..lineTo(226, 181)
      ..lineTo(98.5, 181)
      ..close();
    final scale = size.width / 315;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    canvas.translate(-(98.5 + 315 / 2), -(111 + 290 / 2));
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ZMarkPainter old) => old.color != color;
}

/// The plain big button (Bento Button, Glass Button) and, smaller, the
/// Pixel Pill.
class _ButtonConnect extends StatelessWidget {
  const _ButtonConnect({required this.state, required this.big});

  final ZedConnectState state;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final color = _stateColor(context, s);
    return SizedBox(
      width: big ? double.infinity : null,
      height: big ? 64 : 48,
      child: FilledButton.icon(
        onPressed: s.onToggle,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: _onStateColor(context, s),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(big ? 32 : 24),
          ),
        ),
        icon: _busyMark(context, s, _onStateColor(context, s)),
        label: Text(
          s.label,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// Morph: the control changes shape with the state — a wide pill when
/// off, a circle while busy, a rounded square when live.
class _MorphConnect extends StatelessWidget {
  const _MorphConnect({required this.state});

  final ZedConnectState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final color = _stateColor(context, s);
    final onColor = _onStateColor(context, s);
    final radius = s.live ? 20.0 : (s.busy ? 40.0 : 32.0);
    final width = s.busy ? 80.0 : 220.0;
    return GestureDetector(
      onTap: s.onToggle,
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 340),
        curve: Curves.easeInOutCubic,
        width: width,
        height: 64,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Center(
          child: s.busy
              ? _busyMark(context, s, onColor)
              : Text(
                  s.label,
                  style: TextStyle(
                    color: onColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Rail: a vertical track with a thumb — the control stands upright at
/// the home's edge in its design; here it renders as a tall switch.
class _RailConnect extends StatelessWidget {
  const _RailConnect({required this.state});

  final ZedConnectState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final color = _stateColor(context, s);
    return GestureDetector(
      onTap: s.onToggle,
      child: Container(
        width: 64,
        height: 180,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 280),
              curve: Curves.easeOutBack,
              left: 4,
              right: 4,
              top: s.on ? 4 : null,
              bottom: s.on ? null : 4,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(
                  Icons.power_settings_new_rounded,
                  color: _onStateColor(context, s),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hold: press and hold 650 ms (§25); the ring shows the hold filling,
/// and releasing early cancels. A Listener is used instead of a
/// GestureDetector so press tracking stays outside the gesture arena and
/// cannot be canceled by the wrapping Tooltip's long-press recognizer.
class _HoldConnect extends StatefulWidget {
  const _HoldConnect({required this.state});

  final ZedConnectState state;

  @override
  State<_HoldConnect> createState() => _HoldConnectState();
}

class _HoldConnectState extends State<_HoldConnect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  Timer? _timer;

  /// The pointer performing the hold, if any. A Listener hears EVERY
  /// pointer: without tracking, a second finger would start a second
  /// timer (a double toggle) and the first finger's release would
  /// cancel the second's hold.
  int? _pointer;

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_HoldConnect old) {
    super.didUpdateWidget(old);
    // If the power state itself flipped mid-hold, the press belongs
    // to a state that no longer exists; completing it would act on
    // the new state unasked. (Mere rebuilds with an equal state —
    // the homes rebuild the snapshot often — must NOT cancel.)
    if (old.state.on != widget.state.on) {
      _pointer = null;
      _cancel();
    }
  }

  void _start(int pointer) {
    if (_pointer != null) return;
    _pointer = pointer;
    _c.forward(from: 0);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 650), () {
      _pointer = null;
      widget.state.onToggle();
      _c.reset();
    });
  }

  void _end(int pointer) {
    if (pointer != _pointer) return;
    _pointer = null;
    _cancel();
  }

  void _cancel() {
    _timer?.cancel();
    _c.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final color = _stateColor(context, s);
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) => _start(e.pointer),
      onPointerUp: (e) => _end(e.pointer),
      onPointerCancel: (e) => _end(e.pointer),
      child: SizedBox(
        width: 120,
        height: 120,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            painter: _RingPainter(color: color, progress: _c.value),
            child: Center(child: _busyMark(context, s, color)),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.color, required this.progress});

  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(size.center(Offset.zero), size.width / 2 - 4, paint);
    if (progress > 0) {
      final arc = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(
          center: size.center(Offset.zero),
          radius: size.width / 2 - 4,
        ),
        -1.5708,
        progress * 6.2832,
        false,
        arc,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

/// Tile: a square bento tile that IS the power control.
class _TileConnect extends StatelessWidget {
  const _TileConnect({required this.state});

  final ZedConnectState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final color = _stateColor(context, s);
    return AspectRatio(
      aspectRatio: 1.6,
      child: Material(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: s.onToggle,
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _busyMark(context, s, color),
              const SizedBox(height: 8),
              Text(
                s.label,
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hero: the large circular power core of the Pixel design.
class _HeroConnect extends StatelessWidget {
  const _HeroConnect({required this.state});

  final ZedConnectState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final color = _stateColor(context, s);
    return GestureDetector(
      onTap: s.onToggle,
      child: Container(
        width: 176,
        height: 176,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.14),
          border: Border.all(color: color, width: 2),
          boxShadow: s.live
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.45),
                    blurRadius: 36,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.power_settings_new_rounded, size: 52, color: color),
            const SizedBox(height: 6),
            Text(
              s.label,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ring: a progress-style ring around the power icon; live fills it.
class _RingConnect extends StatelessWidget {
  const _RingConnect({required this.state});

  final ZedConnectState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final color = _stateColor(context, s);
    return GestureDetector(
      onTap: s.onToggle,
      child: SizedBox(
        width: 120,
        height: 120,
        child: CustomPaint(
          painter: _RingPainter(
            color: color,
            progress: s.live ? 1 : (s.busy ? 0.45 : 0),
          ),
          child: Center(child: _busyMark(context, s, color)),
        ),
      ),
    );
  }
}

/// Bar: a slim full-width status bar that toggles.
class _BarConnect extends StatelessWidget {
  const _BarConnect({required this.state});

  final ZedConnectState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final color = _stateColor(context, s);
    return Material(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: s.onToggle,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              _busyMark(context, s, color),
              const SizedBox(width: 12),
              Text(
                s.label,
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon: just the power icon in a tonal circle.
class _IconConnect extends StatelessWidget {
  const _IconConnect({required this.state});

  final ZedConnectState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final color = _stateColor(context, s);
    return IconButton.filledTonal(
      onPressed: s.onToggle,
      iconSize: 34,
      style: IconButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.18),
        foregroundColor: color,
        fixedSize: const Size(76, 76),
      ),
      icon: _busyMark(context, s, color),
    );
  }
}

/// Switch: a large switch (the Glass one is the kit's glass switch).
class _SwitchConnect extends StatelessWidget {
  const _SwitchConnect({required this.state, this.prefs});

  final ZedConnectState state;
  final ZedPrefs? prefs;

  @override
  Widget build(BuildContext context) {
    final s = state;
    // While the state is busy the switch itself cannot show it, so
    // the wait's mark rides beside the label. The label is Flexible
    // so a long localized state word at a large text scale ellipsizes
    // instead of overflowing the row (round 3, ds3-02 finding 4).
    final row = <Widget>[
      Flexible(
        child: Text(
          s.label,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      if (s.busy) ...[
        const SizedBox(width: 10),
        _busyMark(context, s, _stateColor(context, s)),
      ],
      const SizedBox(width: 16),
    ];
    // MergeSemantics ties the state word to the switch, so a screen
    // reader announces "Connected, switch, on" as one control
    // instead of an unlabelled switch beside a stray text (ds3-02
    // finding 3).
    if (prefs != null) {
      return MergeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ...row,
            GlassSwitch(
              value: s.on,
              onChanged: (_) => s.onToggle(),
              prefs: prefs!,
            ),
          ],
        ),
      );
    }
    return MergeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ...row,
          Switch(value: s.on, onChanged: (_) => s.onToggle()),
        ],
      ),
    );
  }
}

/// The Glass "Z": a bold Z monogram in a glass chrome circle — the
/// design's signature connect control.
class _GlassZConnect extends StatelessWidget {
  const _GlassZConnect({required this.state});

  final ZedConnectState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final color = _stateColor(context, s);
    // The Z is a primary control, so it must read as a button with
    // a state to a screen reader and take keyboard activation on
    // desktop — a bare GestureDetector gives it neither (round 3,
    // DeepSeek ds3-02 finding 1).
    return FocusableActionDetector(
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => s.onToggle(),
        ),
      },
      child: Semantics(
        button: true,
        toggled: s.on,
        label: s.label,
        onTap: s.onToggle,
        child: GestureDetector(
          onTap: s.onToggle,
          child: Container(
            width: 168,
            height: 168,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1,
              ),
              boxShadow: s.live
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 40,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: s.busy
                  ? _BusyMark(color: color)
                  : Text(
                      'Z',
                      style: TextStyle(
                        fontSize: 84,
                        fontWeight: FontWeight.w800,
                        color: color,
                        height: 1,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
