import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'zed_glass.dart';
import 'zed_prefs.dart';

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
    canvas.drawArc(
      Offset.zero & size,
      -1.5708,
      4.5239,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_BusyArcPainter old) => old.color != color;
}

Widget _busyMark(BuildContext context, ZedConnectState s, Color color) =>
    s.busy
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
      GlassConnectStyle.slider => _SlideConnect(state: state, glass: true),
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
  const _SlideConnect({required this.state, this.glass = false});

  final ZedConnectState state;
  final bool glass;

  @override
  State<_SlideConnect> createState() => _SlideConnectState();
}

class _SlideConnectState extends State<_SlideConnect> {
  double _drag = 0;

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final color = _stateColor(context, s);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const knob = 56.0;
        final travel = (width - knob - 8).clamp(0, double.infinity);
        final rest = s.on ? 1.0 : 0.0;
        final frac = _drag == 0 ? rest : _drag;
        return GestureDetector(
          // A plain tap toggles too — the power has always answered a
          // tap; the slide is the deliberate gesture on top of it.
          onTap: s.onToggle,
          onHorizontalDragUpdate: (d) {
            setState(() => _drag = (frac + d.delta.dx / travel).clamp(0, 1));
          },
          onHorizontalDragEnd: (_) {
            final target = s.on ? _drag < 0.28 : _drag > 0.72;
            if (target != s.on) s.onToggle();
            setState(() => _drag = 0);
          },
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
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  left: 4 + travel * frac,
                  top: 4,
                  child: Container(
                    width: knob,
                    height: knob,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: _busyMark(
                        context,
                        s,
                        Theme.of(context).colorScheme.onPrimary,
                      ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(big ? 32 : 24),
          ),
        ),
        icon: _busyMark(
          context,
          s,
          Theme.of(context).colorScheme.onPrimary,
        ),
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
    final radius = s.live ? 20.0 : (s.busy ? 40.0 : 32.0);
    final width = s.busy ? 80.0 : 220.0;
    return GestureDetector(
      onTap: s.onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 340),
        curve: Curves.easeInOutCubic,
        width: width,
        height: 64,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Center(
          child: s.busy
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  s.label,
                  style: const TextStyle(
                    color: Colors.white,
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
              duration: const Duration(milliseconds: 280),
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
                child: const Icon(
                  Icons.power_settings_new_rounded,
                  color: Colors.white,
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
/// and releasing early cancels.
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

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _start() {
    _c.forward(from: 0);
    _timer = Timer(const Duration(milliseconds: 650), () {
      widget.state.onToggle();
      _c.reset();
    });
  }

  void _cancel() {
    _timer?.cancel();
    _c.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final color = _stateColor(context, s);
    return GestureDetector(
      onTapDown: (_) => _start(),
      onTapUp: (_) => _cancel(),
      onTapCancel: _cancel,
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
        Rect.fromCircle(center: size.center(Offset.zero), radius: size.width / 2 - 4),
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
              ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 36)]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.power_settings_new_rounded,
              size: 52,
              color: color,
            ),
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
    if (prefs != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(s.label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width: 16),
          GlassSwitch(value: s.on, onChanged: (_) => s.onToggle(), prefs: prefs!),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(s.label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(width: 16),
        Switch(value: s.on, onChanged: (_) => s.onToggle()),
      ],
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
    return GestureDetector(
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
              ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 40)]
              : null,
        ),
        child: Center(
          child: s.busy
              ? CircularProgressIndicator(color: color)
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
    );
  }
}
