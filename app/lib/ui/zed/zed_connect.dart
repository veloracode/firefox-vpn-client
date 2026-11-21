import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'zed_motion.dart';
import 'zed_prefs.dart';
import 'zed_theme.dart';

/// The connect controls, reimplemented from `ui/bento/BentoConnectBar.kt`,
/// `ui/bento/BentoConnectVariants.kt`, `ui/home/ConnectControls.kt`,
/// `ui/home/HomeScreen.kt` and `ui/glass/GlassControls.kt`
/// (ZED-TOKENS-EXTRACT §§3–4). One spec, sixteen controls; the phase
/// model is the app's own (off / busy / on / error) — ZedSecure's
/// "active" keying means busy counts as active for container colours.

enum ZedPhase { off, busy, on, error }

class ZedConnectSpec {
  const ZedConnectSpec({
    required this.phase,
    required this.onToggle,
    required this.stateLabel,
    required this.actionLabel,
    required this.hint,
    this.elapsed = '',
    this.serverName = '',
    this.enabled = true,
  });

  final ZedPhase phase;

  /// The same toggle the classic power button calls.
  final VoidCallback onToggle;

  /// The state word (Connected / Connecting / the off-state label).
  final String stateLabel;

  /// The action verb for the current state (Connect / Disconnect).
  final String actionLabel;

  /// The "slide to connect" style hint for the current state.
  final String hint;

  /// Session elapsed text while connected.
  final String elapsed;

  /// Current server/location name, when a control shows it.
  final String serverName;

  final bool enabled;

  bool get active => phase == ZedPhase.on || phase == ZedPhase.busy;
  bool get on => phase == ZedPhase.on;
  bool get busy => phase == ZedPhase.busy;
}

/// Dispatches to the active design's chosen connect control.
class ZedConnectControl extends StatelessWidget {
  const ZedConnectControl({
    super.key,
    required this.prefs,
    required this.spec,
    this.compact = false,
  });

  final ZedPrefs prefs;
  final ZedConnectSpec spec;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Widget control;
    switch (prefs.design) {
      case ZedDesign.bento:
        control = switch (prefs.bento.connect) {
          BentoConnect.slide => BentoSlideConnect(
            prefs: prefs.bento,
            spec: spec,
          ),
          BentoConnect.button => BentoButtonConnect(
            prefs: prefs.bento,
            spec: spec,
          ),
          BentoConnect.morph => BentoMorphConnect(
            prefs: prefs.bento,
            spec: spec,
          ),
          BentoConnect.rail => BentoRailConnect(prefs: prefs.bento, spec: spec),
          BentoConnect.hold => BentoHoldConnect(prefs: prefs.bento, spec: spec),
          BentoConnect.tile => BentoTileConnect(prefs: prefs.bento, spec: spec),
        };
      case ZedDesign.pixel || ZedDesign.old:
        final p = prefs.activePixel;
        control = switch (p.connect) {
          PixelConnect.pill => PixelPillConnect(
            prefs: p,
            spec: spec,
            compact: compact,
          ),
          PixelConnect.hero => PixelHeroConnect(prefs: p, spec: spec),
          PixelConnect.ring => PixelRingConnect(
            prefs: p,
            spec: spec,
            compact: compact,
          ),
          PixelConnect.bar => PixelBarConnect(
            prefs: p,
            spec: spec,
            compact: compact,
          ),
          PixelConnect.icon => PixelIconConnect(
            prefs: p,
            spec: spec,
            compact: compact,
          ),
          PixelConnect.switchStyle => PixelSwitchConnect(
            prefs: p,
            spec: spec,
            compact: compact,
          ),
        };
      case ZedDesign.glass:
        // Glass controls live in zed_connect_glass.dart; the shell
        // routes through ZedGlassConnectControl for this design.
        throw StateError('Glass connect is dispatched by zed_connect_glass');
    }
    // The stock orb carried a tooltip; every zed control keeps it.
    return Tooltip(message: spec.hint, child: control);
  }
}

/// A small indeterminate spinner in the source's own metrics.
class ZedSpinner extends StatelessWidget {
  const ZedSpinner({
    super.key,
    required this.size,
    required this.stroke,
    required this.color,
  });

  final double size;
  final double stroke;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CircularProgressIndicator(strokeWidth: stroke, color: color),
  );
}

Color _readableOn(Color bg) =>
    bg.computeLuminance() > 0.5 ? const Color(0xFF10131A) : Colors.white;

// ---------------------------------------------------------------------------
// Bento controls (tokens: BentoColors of the active palette)
// ---------------------------------------------------------------------------

BentoTokens _bentoOf(BuildContext context) => ZedColors.of(context)!;

/// §4.1 Slide — the wave track bar. Drag crosses 0.72 to toggle; a
/// tap toggles (with the source's ±0.14 nudge as its feedback); a
/// busy tap cancels.
class BentoSlideConnect extends StatefulWidget {
  const BentoSlideConnect({super.key, required this.prefs, required this.spec});

  final BentoPrefs prefs;
  final ZedConnectSpec spec;

  @override
  State<BentoSlideConnect> createState() => _BentoSlideConnectState();
}

class _BentoSlideConnectState extends State<BentoSlideConnect>
    with TickerProviderStateMixin {
  late final AnimationController _pos = AnimationController(
    vsync: this,
    value: 0,
  );
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _dragging = false;
  double _dragStartPos = 0;
  double _dragStartX = 0;
  double _travel = 1;

  bool get _engaged => widget.spec.active;

  @override
  void initState() {
    super.initState();
    _pos.value = _engaged ? 1 : 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncWave();
  }

  @override
  void didUpdateWidget(BentoSlideConnect old) {
    super.didUpdateWidget(old);
    if (!_dragging && _engaged != old.spec.active) {
      _settleTo(_engaged ? 1 : 0);
    }
    _syncWave();
  }

  void _syncWave() {
    final animate =
        widget.prefs.wave &&
        !MediaQuery.disableAnimationsOf(context) &&
        (widget.spec.busy || widget.spec.on);
    if (animate && !_wave.isAnimating) {
      _wave.repeat();
    } else if (!animate && _wave.isAnimating) {
      _wave.stop();
    }
  }

  void _settleTo(double target) {
    _pos.animateWith(
      SpringSimulation(composeSpring(0.7, 400), _pos.value, target, 0),
    );
  }

  @override
  void dispose() {
    _pos.dispose();
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _bentoOf(context);
    final spec = widget.spec;
    final radius = BorderRadius.circular(
      bentoBlockRadius(widget.prefs.corners),
    );
    final dotColor = switch (spec.phase) {
      ZedPhase.on => c.stage,
      ZedPhase.error => c.bad,
      ZedPhase.busy => c.stage.withValues(alpha: 0.65),
      ZedPhase.off => c.onLime.withValues(alpha: 0.4),
    };
    return Semantics(
      button: true,
      toggled: spec.on,
      label: spec.stateLabel,
      child: Listener(
        onPointerDown: (e) {
          if (!spec.enabled) return;
          _dragging = true;
          _dragStartPos = _pos.value;
          _dragStartX = e.localPosition.dx;
          _pos.stop();
        },
        onPointerMove: (e) {
          if (!_dragging || spec.busy) return;
          final rtl = Directionality.of(context) == TextDirection.rtl;
          var dx = e.localPosition.dx - _dragStartX;
          if (rtl) dx = -dx;
          _pos.value = (_dragStartPos + dx / _travel).clamp(0.0, 1.0);
        },
        onPointerUp: (e) {
          if (!_dragging) return;
          _dragging = false;
          final moved = (_pos.value - _dragStartPos).abs();
          if (moved < 0.02) {
            // A tap toggles (a busy tap cancels the attempt), with
            // the nudge as feedback; the settle follows the spec.
            spec.onToggle();
            _nudge();
            return;
          }
          final crossed = _engaged ? _pos.value < 1 - 0.72 : _pos.value > 0.72;
          if (crossed) {
            spec.onToggle();
            _settleTo(_engaged ? 0 : 1);
          } else {
            _settleTo(_engaged ? 1 : 0);
          }
        },
        onPointerCancel: (_) {
          _dragging = false;
          _settleTo(_engaged ? 1 : 0);
        },
        child: Container(
          height: 84,
          decoration: BoxDecoration(color: c.lime, borderRadius: radius),
          padding: const EdgeInsets.fromLTRB(14, 9, 14, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // The state word itself is the hero's headline above
                    // the control; the slide's header carries the dot
                    // and the hint only, so the state is never printed
                    // twice on one screen.
                    const Spacer(),
                    Flexible(
                      child: Text(
                        spec.hint,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: c.onLime.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 44,
                child: LayoutBuilder(
                  builder: (context, box) {
                    _travel = box.maxWidth - 40;
                    return AnimatedBuilder(
                      animation: Listenable.merge([_pos, _wave]),
                      builder: (context, _) => CustomPaint(
                        painter: _SlidePainter(
                          colors: c,
                          pos: _pos.value,
                          wave: widget.prefs.wave,
                          wavePhase: _wave.value,
                          busy: spec.busy,
                          connected: spec.on,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _nudge() {
    final dir = _engaged ? -0.14 : 0.14;
    final from = _pos.value;
    _pos
        .animateTo(
          (from + dir).clamp(0.0, 1.0),
          duration: const Duration(milliseconds: 140),
        )
        .whenComplete(() {
          if (mounted && !_dragging) {
            _pos.animateWith(
              SpringSimulation(
                composeSpring(0.45, 400),
                _pos.value,
                _engaged ? 1 : 0,
                0,
              ),
            );
          }
        });
  }
}

class _SlidePainter extends CustomPainter {
  _SlidePainter({
    required this.colors,
    required this.pos,
    required this.wave,
    required this.wavePhase,
    required this.busy,
    required this.connected,
  });

  final BentoTokens colors;
  final double pos;
  final bool wave;
  final double wavePhase;
  final bool busy;
  final bool connected;

  @override
  void paint(Canvas canvas, Size size) {
    final knobR = 20.0;
    final cy = size.height / 2;
    final range = size.width - knobR * 2;
    final knobX = knobR + range * pos;
    if (wave) {
      // Wavelength snapped to an even number of half-waves (32 dp
      // preferred) so the wave starts/ends at a zero crossing.
      var halves = (range / 16).round();
      if (halves < 2) halves = 2;
      if (halves.isOdd) halves += 1;
      final wavelength = range * 2 / halves;
      Path wavePath(double from, double to) {
        final p = Path();
        final start = math.max(from, knobR - knobR);
        final end = math.min(to, size.width);
        if (end <= start) return p;
        p.moveTo(start, cy);
        final steps = ((end - start) / 2).ceil();
        for (var i = 1; i <= steps; i++) {
          final x = start + (end - start) * i / steps;
          final y =
              cy +
              4.5 *
                  math.sin(
                    2 * math.pi * (x - knobR) / wavelength -
                        2 * math.pi * wavePhase,
                  );
          p.lineTo(x, y);
        }
        return p;
      }

      final behindPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = colors.onLime.withValues(alpha: connected ? 1 : 0.85);
      canvas.drawPath(wavePath(0, knobX), behindPaint);
      final aheadPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = colors.onLime.withValues(alpha: busy ? 0.9 : 0.3);
      final ahead = wavePath(knobX, size.width);
      if (busy) {
        // Dashed 10 on / 9 off (Flutter has no path effects; walk the
        // path metrics and draw the "on" segments).
        for (final metric in ahead.computeMetrics()) {
          var d = 0.0;
          var draw = true;
          while (d < metric.length) {
            final len = draw ? 10.0 : 9.0;
            if (draw) {
              canvas.drawPath(
                metric.extractPath(d, math.min(d + len, metric.length)),
                aheadPaint,
              );
            }
            d += len;
            draw = !draw;
          }
        }
      } else {
        canvas.drawPath(ahead, aheadPaint);
      }
      // Knob rides the wave.
      final rideY =
          4.5 *
          math.sin(
            2 * math.pi * (knobX - knobR) / wavelength -
                2 * math.pi * wavePhase,
          );
      _knob(canvas, Offset(knobX, cy + rideY), knobR);
    } else {
      _knob(canvas, Offset(knobX, cy), knobR);
    }
  }

  void _knob(Canvas canvas, Offset center, double r) {
    canvas.drawCircle(center, r, Paint()..color = colors.onLime);
    final icon = Icons.power_settings_new_rounded;
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 20,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: colors.lime,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_SlidePainter old) =>
      old.pos != pos ||
      old.wavePhase != wavePhase ||
      old.busy != busy ||
      old.connected != connected ||
      old.colors.lime != colors.lime ||
      old.colors.onLime != colors.onLime;
}

/// §4.2 Button — 72 dp block, disc + action/state text, busy spinner.
class BentoButtonConnect extends StatelessWidget {
  const BentoButtonConnect({
    super.key,
    required this.prefs,
    required this.spec,
  });

  final BentoPrefs prefs;
  final ZedConnectSpec spec;

  @override
  Widget build(BuildContext context) {
    final c = _bentoOf(context);
    final bg = spec.active ? c.stage : c.lime;
    final fg = spec.active ? c.onStage : c.onLime;
    return ZedPressScale(
      pressedScale: 0.97,
      spring: composeSpring(0.6, 1500),
      child: Semantics(
        button: true,
        toggled: spec.on,
        label: spec.stateLabel,
        child: GestureDetector(
          onTap: spec.enabled ? spec.onToggle : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 72,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(
                bentoBlockRadius(prefs.corners),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
                  child: Icon(
                    Icons.power_settings_new_rounded,
                    size: 24,
                    color: bg,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spec.actionLabel,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: fg,
                        ),
                      ),
                      Text(
                        spec.stateLabel,
                        style: TextStyle(
                          fontSize: 13,
                          color: fg.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                if (spec.busy) ZedSpinner(size: 22, stroke: 2.5, color: fg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A rotating-polygon blob whose radius modulation morphs with
/// [progress] (the MorphingBlob stand-in: Cookie/SoftBurst/Clover
/// families are N-point polygons with alternating radii).
class BlobPainter extends CustomPainter {
  BlobPainter({
    required this.color,
    required this.points,
    required this.morph,
    required this.rotation,
  });

  final Color color;
  final int points;

  /// 0 → the "from" polygon, 1 → the "to" polygon.
  final double morph;
  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final base = math.min(size.width, size.height) / 2;
    final path = Path();
    final n = points * 2;
    for (var i = 0; i <= n; i++) {
      final idx = i % n;
      final angle = rotation + idx * math.pi / points;
      // Alternating radii: from-shape shallow, to-shape deep.
      final depth = idx.isEven ? 0.0 : (0.06 + 0.13 * morph);
      final r = base * (1 - depth);
      final p = center + Offset(math.cos(angle), math.sin(angle)) * r;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(BlobPainter old) =>
      old.morph != morph || old.rotation != rotation || old.color != color;
}

/// §4.3 Morph — 112 dp block with a 90 dp morphing blob.
class BentoMorphConnect extends StatefulWidget {
  const BentoMorphConnect({super.key, required this.prefs, required this.spec});

  final BentoPrefs prefs;
  final ZedConnectSpec spec;

  @override
  State<BentoMorphConnect> createState() => _BentoMorphConnectState();
}

class _BentoMorphConnectState extends State<BentoMorphConnect>
    with TickerProviderStateMixin {
  late final AnimationController _morph = AnimationController(vsync: this);
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 24000),
  );

  @override
  void initState() {
    super.initState();
    _morph.value = widget.spec.active ? 1 : 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncLoops();
  }

  @override
  void didUpdateWidget(BentoMorphConnect old) {
    super.didUpdateWidget(old);
    if (widget.spec.active != old.spec.active) {
      _morph.animateWith(
        SpringSimulation(
          composeSpring(0.5, 200),
          _morph.value,
          widget.spec.active ? 1 : 0,
          0,
        ),
      );
    }
    _syncLoops();
  }

  void _syncLoops() {
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (widget.spec.busy && !reduce) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      _spin.stop();
    }
    if (widget.spec.on && widget.prefs.playfulTouch && !reduce) {
      if (!_drift.isAnimating) _drift.repeat();
    } else {
      _drift.stop();
    }
  }

  @override
  void dispose() {
    _morph.dispose();
    _spin.dispose();
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _bentoOf(context);
    final spec = widget.spec;
    final bg = spec.active ? c.stage : c.surface;
    final fg = spec.active ? c.onStage : c.ink;
    return Semantics(
      button: true,
      toggled: spec.on,
      label: spec.stateLabel,
      child: GestureDetector(
        onTap: spec.enabled ? spec.onToggle : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 112,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(
              bentoBlockRadius(widget.prefs.corners),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: Listenable.merge([_morph, _spin, _drift]),
                builder: (context, _) {
                  final rotation =
                      _spin.value * 2 * math.pi + _drift.value * 2 * math.pi;
                  return ZedPressScale(
                    pressedScale: 0.94,
                    spring: composeSpring(0.5, 1500),
                    child: SizedBox(
                      width: 90,
                      height: 90,
                      child: CustomPaint(
                        painter: BlobPainter(
                          color: c.lime,
                          points: 9,
                          morph: _morph.value,
                          rotation: rotation,
                        ),
                        child: Transform.rotate(
                          angle: -rotation,
                          child: Icon(
                            Icons.power_settings_new_rounded,
                            size: 34,
                            color: c.onLime,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spec.stateLabel,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: fg,
                      ),
                    ),
                    Text(
                      spec.on && spec.elapsed.isNotEmpty
                          ? spec.elapsed
                          : (spec.serverName.isNotEmpty
                                ? spec.serverName
                                : spec.hint),
                      style: TextStyle(
                        fontSize: 15,
                        color: fg.withValues(alpha: 0.8),
                      ),
                    ),
                    if (spec.active)
                      Text(
                        spec.hint,
                        style: TextStyle(
                          fontSize: 13,
                          color: fg.withValues(alpha: 0.65),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// §4.4 Rail — 80 dp pill; the knob travels; the centre carries a
/// wave while on (phase runs busy-only) or centred text.
class BentoRailConnect extends StatefulWidget {
  const BentoRailConnect({super.key, required this.prefs, required this.spec});

  final BentoPrefs prefs;
  final ZedConnectSpec spec;

  @override
  State<BentoRailConnect> createState() => _BentoRailConnectState();
}

class _BentoRailConnectState extends State<BentoRailConnect>
    with TickerProviderStateMixin {
  late final AnimationController _travel = AnimationController(
    vsync: this,
    value: 0,
  );
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    _travel.value = widget.spec.active ? 1 : 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(BentoRailConnect old) {
    super.didUpdateWidget(old);
    if (widget.spec.active != old.spec.active) {
      _travel.animateWith(
        SpringSimulation(
          composeSpring(0.62, 400),
          _travel.value,
          widget.spec.active ? 1 : 0,
          0,
        ),
      );
    }
    _sync();
  }

  void _sync() {
    if (widget.spec.busy && !MediaQuery.disableAnimationsOf(context)) {
      if (!_wave.isAnimating) _wave.repeat();
    } else {
      _wave.stop();
      _wave.value = 0; // Phase resets to 0 outside busy (source).
    }
  }

  @override
  void dispose() {
    _travel.dispose();
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _bentoOf(context);
    final spec = widget.spec;
    final on = spec.active;
    return Semantics(
      button: true,
      toggled: spec.on,
      label: spec.stateLabel,
      child: GestureDetector(
        onTap: spec.enabled ? spec.onToggle : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 80,
          decoration: BoxDecoration(
            color: on ? c.lime : c.surface2,
            borderRadius: BorderRadius.circular(40),
          ),
          padding: const EdgeInsets.all(8),
          child: LayoutBuilder(
            builder: (context, box) {
              final travel = box.maxWidth - 64;
              return AnimatedBuilder(
                animation: Listenable.merge([_travel, _wave]),
                builder: (context, _) => Stack(
                  children: [
                    if (on && widget.prefs.wave)
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 74),
                          child: CustomPaint(
                            painter: _RailWavePainter(
                              color: c.onLime.withValues(
                                alpha: spec.on ? 0.9 : 0.55,
                              ),
                              phase: _wave.value,
                            ),
                          ),
                        ),
                      )
                    else
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 72),
                          child: Text(
                            spec.on && spec.elapsed.isNotEmpty
                                ? spec.elapsed
                                : (spec.busy ? spec.stateLabel : spec.hint),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: on ? c.onLime : c.muted,
                            ),
                          ),
                        ),
                      ),
                    PositionedDirectional(
                      start: travel * _travel.value,
                      top: 0,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: on ? c.onLime : c.lime,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.power_settings_new_rounded,
                          size: 28,
                          color: on ? c.lime : c.onLime,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RailWavePainter extends CustomPainter {
  _RailWavePainter({required this.color, required this.phase});

  final Color color;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final path = Path()..moveTo(0, cy);
    final steps = (size.width / 2).ceil();
    for (var i = 1; i <= steps; i++) {
      final x = size.width * i / steps;
      path.lineTo(
        x,
        cy + 6 * math.sin(2 * math.pi * x / 30 - 2 * math.pi * phase),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RailWavePainter old) =>
      old.phase != phase || old.color != color;
}

/// §4.5 Hold — hold 650 ms (linear fill) to toggle; a busy tap
/// cancels; the dial shows track + progress arcs.
class BentoHoldConnect extends StatefulWidget {
  const BentoHoldConnect({super.key, required this.prefs, required this.spec});

  final BentoPrefs prefs;
  final ZedConnectSpec spec;

  @override
  State<BentoHoldConnect> createState() => _BentoHoldConnectState();
}

class _BentoHoldConnectState extends State<BentoHoldConnect>
    with TickerProviderStateMixin {
  late final AnimationController _fill = AnimationController(vsync: this);
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  bool _holding = false;
  bool _fired = false;
  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSpin();
  }

  @override
  void didUpdateWidget(BentoHoldConnect old) {
    super.didUpdateWidget(old);
    _syncSpin();
  }

  void _syncSpin() {
    if (widget.spec.busy && !MediaQuery.disableAnimationsOf(context)) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      _spin.stop();
    }
  }

  void _pressDown() {
    if (!widget.spec.enabled || widget.spec.busy) return;
    _holding = true;
    _fired = false;
    _fill.animateTo(
      1,
      duration: const Duration(milliseconds: 650),
      curve: Curves.linear,
    );
    _holdTimer = Timer(const Duration(milliseconds: 650), () {
      if (_holding && mounted) {
        _fired = true;
        HapticFeedback.mediumImpact();
        widget.spec.onToggle();
      }
    });
  }

  void _pressUp({required bool cancelled}) {
    _holdTimer?.cancel();
    if (widget.spec.busy && !cancelled && _holding) {
      // A busy tap (up without cancellation) cancels the attempt.
      widget.spec.onToggle();
    }
    _holding = false;
    if (!_fired) {
      _fill.animateWith(
        SpringSimulation(composeSpring(1.0, 1500), _fill.value, 0, 0),
      );
    } else {
      _fill.value = 0;
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _fill.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _bentoOf(context);
    final spec = widget.spec;
    final on = spec.on;
    final bg = on ? c.stage : c.lime;
    final ink = on ? c.onStage : c.onLime;
    final knob = on ? c.lime : c.onLime;
    final glyph = on ? c.onLime : c.lime;
    return Semantics(
      button: true,
      toggled: on,
      label: spec.stateLabel,
      child: Listener(
        onPointerDown: (_) => _pressDown(),
        onPointerUp: (_) => _pressUp(cancelled: false),
        onPointerCancel: (_) => _pressUp(cancelled: true),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 104,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(
              bentoBlockRadius(widget.prefs.corners),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: Listenable.merge([_fill, _spin]),
                builder: (context, _) => CustomPaint(
                  painter: _HoldDialPainter(
                    track: ink.withValues(alpha: 0.22),
                    arc: on ? c.lime : ink,
                    disc: knob,
                    glyph: glyph,
                    progress: on ? 1 : (spec.busy ? 0.25 : _fill.value),
                    rotation: _spin.value * 2 * math.pi,
                    busy: spec.busy,
                  ),
                  size: const Size(76, 76),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spec.busy
                          ? spec.stateLabel
                          : (on ? 'Hold to disconnect' : 'Hold to connect'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                    if (on && spec.elapsed.isNotEmpty)
                      Text(
                        spec.elapsed,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          color: ink,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      )
                    else
                      Text(
                        spec.serverName.isNotEmpty
                            ? spec.serverName
                            : spec.hint,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: ink.withValues(alpha: 0.78),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HoldDialPainter extends CustomPainter {
  _HoldDialPainter({
    required this.track,
    required this.arc,
    required this.disc,
    required this.glyph,
    required this.progress,
    required this.rotation,
    required this.busy,
  });

  final Color track;
  final Color arc;
  final Color disc;
  final Color glyph;
  final double progress;
  final double rotation;
  final bool busy;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2 - 3;
    canvas.drawCircle(center, r, Paint()..color = disc);
    final rect = Rect.fromCircle(center: center, radius: r);
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = track,
    );
    canvas.save();
    if (busy) {
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rotation);
      canvas.translate(-center.dx, -center.dy);
    }
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = arc,
    );
    canvas.restore();
    final icon = Icons.power_settings_new_rounded;
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 30,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: glyph,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_HoldDialPainter old) =>
      old.progress != progress || old.rotation != rotation || old.arc != arc;
}

/// §4.6 Tile — 132 dp prominent tile with a morphing badge.
class BentoTileConnect extends StatefulWidget {
  const BentoTileConnect({super.key, required this.prefs, required this.spec});

  final BentoPrefs prefs;
  final ZedConnectSpec spec;

  @override
  State<BentoTileConnect> createState() => _BentoTileConnectState();
}

class _BentoTileConnectState extends State<BentoTileConnect>
    with TickerProviderStateMixin {
  late final AnimationController _morph = AnimationController(vsync: this);
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    _morph.value = widget.spec.active ? 1 : 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSpin();
  }

  @override
  void didUpdateWidget(BentoTileConnect old) {
    super.didUpdateWidget(old);
    if (widget.spec.active != old.spec.active) {
      _morph.animateWith(
        SpringSimulation(
          composeSpring(0.55, 200),
          _morph.value,
          widget.spec.active ? 1 : 0,
          0,
        ),
      );
    }
    _syncSpin();
  }

  void _syncSpin() {
    if (widget.spec.busy && !MediaQuery.disableAnimationsOf(context)) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _morph.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _bentoOf(context);
    final spec = widget.spec;
    final on = spec.active;
    final bg = on ? c.lime : c.stage;
    final ink = on ? c.onLime : c.onStage;
    return ZedPressScale(
      pressedScale: 0.97,
      spring: composeSpring(0.55, 1500),
      child: Semantics(
        button: true,
        toggled: spec.on,
        label: spec.stateLabel,
        child: GestureDetector(
          onTap: spec.enabled ? spec.onToggle : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 132,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: bentoTileRadius(
                widget.prefs.corners,
                prominent: true,
              ),
            ),
            padding: const EdgeInsets.all(18),
            child: Stack(
              children: [
                if (widget.prefs.motifs)
                  PositionedDirectional(
                    end: -60,
                    bottom: -70,
                    child: Transform.rotate(
                      angle: 18 * math.pi / 180,
                      child: CustomPaint(
                        size: const Size(190, 190),
                        painter: BlobPainter(
                          color: ink.withValues(alpha: 0.09),
                          points: 6,
                          morph: 0.5,
                          rotation: 0,
                        ),
                      ),
                    ),
                  ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 72),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            spec.stateLabel.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.9,
                              color: ink.withValues(alpha: 0.8),
                            ),
                          ),
                          Text(
                            on && spec.elapsed.isNotEmpty
                                ? spec.elapsed
                                : spec.actionLabel,
                            style: TextStyle(
                              fontSize: on && spec.elapsed.isNotEmpty ? 40 : 34,
                              fontWeight: FontWeight.w700,
                              color: ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 72),
                      child: Text(
                        spec.serverName.isNotEmpty
                            ? spec.serverName
                            : spec.hint,
                        style: TextStyle(
                          fontSize: 14,
                          color: ink.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
                PositionedDirectional(
                  end: 0,
                  top: 0,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_morph, _spin]),
                    builder: (context, _) => SizedBox(
                      width: 64,
                      height: 64,
                      child: CustomPaint(
                        painter: BlobPainter(
                          color: on ? c.onLime : c.lime,
                          points: 4,
                          morph: _morph.value,
                          rotation: _spin.value * 2 * math.pi,
                        ),
                        child: Transform.rotate(
                          angle: -_spin.value * 2 * math.pi,
                          child: Icon(
                            Icons.power_settings_new_rounded,
                            size: 26,
                            color: on ? c.lime : c.onLime,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pixel / Old controls (§3.3). Container rule: idle = custom connect
// colour or scheme primary; active (on OR busy) = custom connected
// colour or secondaryContainer; error = errorContainer.
// ---------------------------------------------------------------------------

({Color bg, Color fg}) _pixelColors(
  BuildContext context,
  PixelPrefs prefs,
  ZedConnectSpec spec,
) {
  final scheme = Theme.of(context).colorScheme;
  if (spec.phase == ZedPhase.error) {
    return (bg: scheme.errorContainer, fg: scheme.onErrorContainer);
  }
  if (spec.active) {
    final bg = prefs.customConnected != null
        ? Color(prefs.customConnected!)
        : scheme.secondaryContainer;
    final fg = prefs.customConnected != null
        ? _readableOn(bg)
        : scheme.onSecondaryContainer;
    return (bg: bg, fg: fg);
  }
  final bg = prefs.customConnect != null
      ? Color(prefs.customConnect!)
      : scheme.primary;
  final fg = prefs.customConnect != null ? _readableOn(bg) : scheme.onPrimary;
  return (bg: bg, fg: fg);
}

Widget _pixelGlyph(ZedConnectSpec spec, Color fg, double size, double spinner) {
  if (spec.busy) return ZedSpinner(size: spinner, stroke: 2.5, color: fg);
  return Icon(
    spec.active ? Icons.close_rounded : Icons.bolt_rounded,
    size: size,
    color: fg,
  );
}

/// §3.3 Pill — 72 dp bar; corner radius animates by state
/// (pressed 44 / transitioning 36 / active 20 / idle 30).
class PixelPillConnect extends StatefulWidget {
  const PixelPillConnect({
    super.key,
    required this.prefs,
    required this.spec,
    this.compact = false,
  });

  final PixelPrefs prefs;
  final ZedConnectSpec spec;
  final bool compact;

  @override
  State<PixelPillConnect> createState() => _PixelPillConnectState();
}

class _PixelPillConnectState extends State<PixelPillConnect> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final (:bg, :fg) = _pixelColors(context, widget.prefs, spec);
    final radius = _pressed
        ? 44.0
        : spec.busy
        ? 36.0
        : spec.active
        ? 20.0
        : 30.0;
    return Semantics(
      button: true,
      toggled: spec.on,
      label: spec.stateLabel,
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1,
          duration: const Duration(milliseconds: 200),
          child: GestureDetector(
            onTap: spec.enabled ? spec.onToggle : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: zedFastOutSlowIn,
              height: widget.compact ? 56 : 72,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(radius),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _pixelGlyph(spec, fg, 26, 28),
                  const SizedBox(width: 10),
                  Text(
                    spec.actionLabel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The ZedSecure session gradients (`ZedGradients`).
LinearGradient zedGradientFor(ZedPhase phase, int session) {
  const violet = Color(0xFF7A5CFF);
  const hotPink = Color(0xFFFF5FA2);
  const lime = Color(0xFFC7F24E);
  const cyan = Color(0xFF37E0D8);
  const deep = Color(0xFF2A1361);
  const sessions = [
    [violet, hotPink, lime],
    [deep, violet, cyan],
    [hotPink, violet, cyan],
    [violet, cyan, lime],
    [deep, hotPink, violet],
  ];
  final colors = switch (phase) {
    ZedPhase.on => [deep, ...sessions[session % sessions.length]],
    ZedPhase.busy => [violet, cyan, lime],
    _ => [deep, violet, hotPink.withValues(alpha: 0.7)],
  };
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: colors,
  );
}

/// §3.3 Hero — the morphing blob IS the button.
class PixelHeroConnect extends StatefulWidget {
  const PixelHeroConnect({super.key, required this.prefs, required this.spec});

  final PixelPrefs prefs;
  final ZedConnectSpec spec;

  @override
  State<PixelHeroConnect> createState() => _PixelHeroConnectState();
}

class _PixelHeroConnectState extends State<PixelHeroConnect>
    with TickerProviderStateMixin {
  late final AnimationController _morph = AnimationController(vsync: this);
  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );

  @override
  void initState() {
    super.initState();
    _morph.value = widget.spec.active ? 1 : 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(PixelHeroConnect old) {
    super.didUpdateWidget(old);
    if (widget.spec.active != old.spec.active) {
      // slowSpatialSpec ≈ a long, soft spring in the port.
      _morph.animateWith(
        SpringSimulation(
          composeSpring(0.9, 120),
          _morph.value,
          widget.spec.active ? 1 : 0,
          0,
        ),
      );
    }
    _sync();
  }

  void _sync() {
    if (widget.spec.on && !MediaQuery.disableAnimationsOf(context)) {
      if (!_breathe.isAnimating) _breathe.repeat(reverse: true);
    } else {
      _breathe.stop();
      _breathe.value = 0;
    }
  }

  @override
  void dispose() {
    _morph.dispose();
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final height = MediaQuery.sizeOf(context).height;
    final size = math.min(216.0, height * 0.29);
    return Semantics(
      button: true,
      toggled: spec.on,
      label: spec.stateLabel,
      child: GestureDetector(
        onTap: spec.enabled ? spec.onToggle : null,
        // Long-press is a particle burst in the source and never a
        // toggle; the burst is decorative and not ported.
        onLongPress: () {},
        child: AnimatedBuilder(
          animation: Listenable.merge([_morph, _breathe]),
          builder: (context, _) {
            final breathe = 0.97 + 0.07 * _breathe.value;
            return Transform.scale(
              scale: spec.on ? breathe : 1,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  gradient: zedGradientFor(spec.phase, 0),
                  shape: BoxShape.circle,
                ),
                child: CustomPaint(
                  painter: BlobPainter(
                    color: Colors.white.withValues(alpha: 0.10),
                    points: 9,
                    morph: _morph.value,
                    rotation: _morph.value * 0.6,
                  ),
                  child: Center(
                    child: spec.busy
                        ? ZedSpinner(
                            size: size * 0.39,
                            stroke: 3,
                            color: Colors.white,
                          )
                        : spec.on && spec.elapsed.isNotEmpty
                        ? Text(
                            spec.elapsed,
                            style: TextStyle(
                              fontSize: size * 0.194,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          )
                        : Text(
                            'Z',
                            style: TextStyle(
                              fontSize: size * 0.315,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// §3.3 Ring — 132 dp circle, border 3→8 dp by state.
class PixelRingConnect extends StatelessWidget {
  const PixelRingConnect({
    super.key,
    required this.prefs,
    required this.spec,
    this.compact = false,
  });

  final PixelPrefs prefs;
  final ZedConnectSpec spec;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (:bg, :fg) = _pixelColors(context, prefs, spec);
    final size = compact ? 104.0 : 132.0;
    return Semantics(
      button: true,
      toggled: spec.on,
      label: spec.stateLabel,
      child: ZedPressScale(
        pressedScale: 0.94,
        spring: composeSpring(0.62, 1500),
        child: GestureDetector(
          onTap: spec.enabled ? spec.onToggle : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: zedFastOutSlowIn,
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: Border.all(
                color: fg.withValues(alpha: 0.35),
                width: spec.active ? 8 : 3,
              ),
            ),
            child: Center(
              child: _pixelGlyph(
                spec,
                fg,
                compact ? 38 : 46,
                compact ? 32 : 38,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// §3.3 Bar — 54 dp, fixed 14 dp radius.
class PixelBarConnect extends StatelessWidget {
  const PixelBarConnect({
    super.key,
    required this.prefs,
    required this.spec,
    this.compact = false,
  });

  final PixelPrefs prefs;
  final ZedConnectSpec spec;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (:bg, :fg) = _pixelColors(context, prefs, spec);
    return Semantics(
      button: true,
      toggled: spec.on,
      label: spec.stateLabel,
      child: GestureDetector(
        onTap: spec.enabled ? spec.onToggle : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: compact ? 48 : 54,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (spec.busy)
                ZedSpinner(size: 20, stroke: 2.5, color: fg)
              else
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: spec.active ? 1 : 0.55),
                    shape: BoxShape.circle,
                  ),
                ),
              const SizedBox(width: 12),
              Text(
                spec.stateLabel,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// §3.3 Icon — 76 dp square, radius 24→34 while pressed.
class PixelIconConnect extends StatefulWidget {
  const PixelIconConnect({
    super.key,
    required this.prefs,
    required this.spec,
    this.compact = false,
  });

  final PixelPrefs prefs;
  final ZedConnectSpec spec;
  final bool compact;

  @override
  State<PixelIconConnect> createState() => _PixelIconConnectState();
}

class _PixelIconConnectState extends State<PixelIconConnect> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final (:bg, :fg) = _pixelColors(context, widget.prefs, spec);
    final size = widget.compact ? 64.0 : 76.0;
    return Semantics(
      button: true,
      toggled: spec.on,
      label: spec.stateLabel,
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: GestureDetector(
          onTap: spec.enabled ? spec.onToggle : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: zedFastOutSlowIn,
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(_pressed ? 34 : 24),
            ),
            child: Center(child: _pixelGlyph(spec, fg, 30, 26)),
          ),
        ),
      ),
    );
  }
}

/// §3.3 Switch — 68 dp track, knob disc travels start→end.
class PixelSwitchConnect extends StatelessWidget {
  const PixelSwitchConnect({
    super.key,
    required this.prefs,
    required this.spec,
    this.compact = false,
  });

  final PixelPrefs prefs;
  final ZedConnectSpec spec;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (:bg, :fg) = _pixelColors(context, prefs, spec);
    final height = compact ? 56.0 : 68.0;
    final knob = compact ? 44.0 : 52.0;
    return Semantics(
      button: true,
      toggled: spec.on,
      label: spec.stateLabel,
      child: GestureDetector(
        onTap: spec.enabled ? spec.onToggle : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: height,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(34),
          ),
          padding: EdgeInsets.all(compact ? 6 : 8),
          child: Stack(
            children: [
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    spec.stateLabel,
                    key: ValueKey(spec.stateLabel),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ),
              ),
              AnimatedAlign(
                alignment: AlignmentDirectional(spec.active ? 1 : -1, 0),
                duration: const Duration(milliseconds: 300),
                curve: zedFastOutSlowIn,
                child: Container(
                  width: knob,
                  height: knob,
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: _pixelGlyph(spec, fg, 24, 22)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
