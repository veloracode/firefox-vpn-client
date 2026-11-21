import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:material_ui/material_ui.dart';

import 'zed_connect.dart';
import 'zed_glass.dart';
import 'zed_motion.dart';
import 'zed_prefs.dart';
import 'zed_theme.dart';

/// The Glass connect controls (`ui/glass/GlassZ.kt`,
/// `ui/glass/GlassControls.kt`; ZED-TOKENS-EXTRACT §2.7).

class ZedGlassConnectControl extends StatelessWidget {
  const ZedGlassConnectControl({
    super.key,
    required this.prefs,
    required this.tokens,
    required this.spec,
    this.heroWidth = 176,
  });

  final GlassPrefs prefs;
  final GlassTokens tokens;
  final ZedConnectSpec spec;
  final double heroWidth;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: spec.hint,
    child: switch (prefs.connect) {
      GlassConnect.z => GlassZConnect(
        tokens: tokens,
        spec: spec,
        width: heroWidth,
        parallax: prefs.motionHighlights,
      ),
      GlassConnect.button => GlassButtonConnect(tokens: tokens, spec: spec),
      GlassConnect.switchStyle => GlassSwitchConnect(
        tokens: tokens,
        spec: spec,
      ),
      GlassConnect.slider => GlassSliderConnect(tokens: tokens, spec: spec),
    },
  );
}

/// The Z mark path (`GlassIcons.ZedMark`), bounds (98.5, 111) with
/// size 315×290.
Path zedMarkPath() => Path()
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

/// Per-phase Z look (`zLook(phase, dark, tint)` in GlassZ.kt).
class ZLook {
  const ZLook({
    required this.a,
    required this.b,
    required this.hi,
    required this.lo,
    required this.shade,
    required this.spec,
    required this.rim,
    required this.shadow,
    required this.caust,
    required this.shine,
    required this.glowA,
    required this.glowB,
    required this.glowC,
    required this.glow,
  });

  final Color a;
  final Color b;
  final double hi;
  final double lo;
  final double shade;
  final double spec;
  final Color rim;
  final Color shadow;
  final double caust;
  final double shine;
  final Color glowA;
  final Color glowB;
  final Color glowC;
  final double glow;

  static ZLook lerp(ZLook x, ZLook y, double t) => ZLook(
    a: Color.lerp(x.a, y.a, t)!,
    b: Color.lerp(x.b, y.b, t)!,
    hi: x.hi + (y.hi - x.hi) * t,
    lo: x.lo + (y.lo - x.lo) * t,
    shade: x.shade + (y.shade - x.shade) * t,
    spec: x.spec + (y.spec - x.spec) * t,
    rim: Color.lerp(x.rim, y.rim, t)!,
    shadow: Color.lerp(x.shadow, y.shadow, t)!,
    caust: x.caust + (y.caust - x.caust) * t,
    shine: x.shine + (y.shine - x.shine) * t,
    glowA: Color.lerp(x.glowA, y.glowA, t)!,
    glowB: Color.lerp(x.glowB, y.glowB, t)!,
    glowC: Color.lerp(x.glowC, y.glowC, t)!,
    glow: x.glow + (y.glow - x.glow) * t,
  );
}

Color _rgb(int r, int g, int b, double a) => Color.fromRGBO(r, g, b, a);

ZLook zLook(ZedPhase phase, bool dark, Color tint) {
  switch (phase) {
    case ZedPhase.on:
      return ZLook(
        a: dark ? _rgb(196, 140, 255, 0.55) : _rgb(190, 135, 255, 0.80),
        b: dark ? _rgb(255, 100, 180, 0.24) : _rgb(255, 105, 180, 0.52),
        hi: 1,
        lo: 0.6,
        shade: dark ? 0.10 : 0.16,
        spec: 0.6,
        rim: dark ? _rgb(255, 255, 255, 0.78) : _rgb(120, 60, 180, 0.42),
        shadow: dark ? _rgb(180, 80, 230, 0.26) : _rgb(170, 70, 220, 0.32),
        caust: 0.18,
        shine: 0.85,
        glowA: const Color(0xFFB06CFF),
        glowB: const Color(0xFFE05BE6),
        glowC: const Color(0xFFFF6FB5),
        glow: 1,
      );
    case ZedPhase.busy:
      return ZLook(
        a: tint.withValues(alpha: dark ? 0.36 : 0.52),
        b: tint.withValues(alpha: dark ? 0.12 : 0.22),
        hi: 0.95,
        lo: 0.6,
        shade: dark ? 0.12 : 0.18,
        spec: 0.5,
        rim: dark ? _rgb(255, 255, 255, 0.65) : tint.withValues(alpha: 0.5),
        shadow: tint.withValues(alpha: 0.22),
        caust: 0.28,
        shine: 0.75,
        glowA: tint.withValues(alpha: 0.75),
        glowB: tint.withValues(alpha: 0.75),
        glowC: tint.withValues(alpha: 0.75),
        glow: 0.7,
      );
    case ZedPhase.off || ZedPhase.error:
      return ZLook(
        a: dark ? _rgb(255, 255, 255, 0.26) : _rgb(255, 255, 255, 0.84),
        b: dark ? _rgb(255, 255, 255, 0.07) : _rgb(158, 172, 200, 0.52),
        hi: dark ? 0.85 : 1,
        lo: dark ? 0.35 : 0.85,
        shade: dark ? 0.35 : 0.22,
        spec: dark ? 0.45 : 0.72,
        rim: dark ? _rgb(255, 255, 255, 0.5) : _rgb(40, 55, 85, 0.32),
        shadow: dark ? _rgb(0, 0, 0, 0.55) : _rgb(30, 40, 80, 0.20),
        caust: dark ? 0.16 : 0.42,
        shine: dark ? 0.60 : 0.95,
        glowA: Colors.transparent,
        glowB: Colors.transparent,
        glowC: Colors.transparent,
        glow: 0,
      );
  }
}

/// The Glass Z hero control. One lifecycle-gated clock drives all
/// ambient cycles (caustics 7000 ms, shine 4400/1700 ms, scan
/// 1200 ms, trace 1500 ms, breathe 3200 ms — §6.3); reduced motion
/// or a disabled budget renders the source's static values.
class GlassZConnect extends StatefulWidget {
  const GlassZConnect({
    super.key,
    required this.tokens,
    required this.spec,
    this.width = 176,
    this.parallax = false,
  });

  final GlassTokens tokens;
  final ZedConnectSpec spec;
  final double width;

  /// GlassPrefs.motionHighlights: the pointer stands in for the
  /// source's device tilt — the shine follows it across the Z.
  final bool parallax;

  @override
  State<GlassZConnect> createState() => _GlassZConnectState();
}

class _GlassZConnectState extends State<GlassZConnect>
    with TickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(vsync: this);
  late final AnimationController _blend = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
    value: 1,
  );
  late ZLook _from;
  late ZLook _to;
  bool _animate = false;

  /// Pointer parallax in -1..1 (motionHighlights only).
  double _tiltX = 0;

  @override
  void initState() {
    super.initState();
    _to = zLook(widget.spec.phase, widget.tokens.dark, widget.tokens.tint);
    _from = _to;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate = !MediaQuery.disableAnimationsOf(context);
    if (animate != _animate) {
      _animate = animate;
      if (animate) {
        _clock.repeat();
      } else {
        _clock.stop();
      }
    }
  }

  @override
  void didUpdateWidget(GlassZConnect old) {
    super.didUpdateWidget(old);
    final next = zLook(
      widget.spec.phase,
      widget.tokens.dark,
      widget.tokens.tint,
    );
    if (widget.spec.phase != old.spec.phase ||
        widget.tokens.dark != old.tokens.dark) {
      _from = ZLook.lerp(_from, _to, _blend.value);
      _to = next;
      _blend.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    _blend.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final w = widget.width;
    final h = w * 290 / 315;
    return Semantics(
      button: true,
      toggled: spec.on,
      label: spec.stateLabel,
      child: ZedPressScale(
        pressedScale: 1.06,
        spring: springPressGlass,
        child: GestureDetector(
          onTap: spec.enabled ? spec.onToggle : null,
          child: MouseRegion(
            onHover: widget.parallax
                ? (e) => setState(
                    () => _tiltX = ((e.localPosition.dx / (w + 44)) * 2 - 1)
                        .clamp(-1.0, 1.0),
                  )
                : null,
            onExit: widget.parallax ? (_) => setState(() => _tiltX = 0) : null,
            child: SizedBox(
              width: w + 44,
              height: h + 48,
              child: AnimatedBuilder(
                animation: Listenable.merge([_clock, _blend]),
                builder: (context, _) {
                  final look = ZLook.lerp(_from, _to, _blend.value);
                  return CustomPaint(
                    painter: _ZPainter(
                      look: look,
                      tint: widget.tokens.tint,
                      elapsedMs: _animate
                          ? _clock.lastElapsedDuration?.inMilliseconds ?? 0
                          : null,
                      busy: spec.busy,
                      glyphWidth: w,
                      tiltX: _tiltX,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ZPainter extends CustomPainter {
  _ZPainter({
    required this.look,
    required this.tint,
    required this.elapsedMs,
    required this.busy,
    required this.glyphWidth,
    this.tiltX = 0,
  });

  final ZLook look;
  final Color tint;
  final int? elapsedMs;
  final bool busy;
  final double glyphWidth;

  /// Pointer parallax (motionHighlights): shifts the shine band.
  final double tiltX;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = glyphWidth / 315;
    final origin = Offset(
      (size.width - glyphWidth) / 2,
      (size.height - glyphWidth * 290 / 315) / 2,
    );
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(scale);
    canvas.translate(-98.5, -111);
    final path = zedMarkPath();
    final bounds = Rect.fromLTWH(98.5, 111, 315, 290);

    // Motion values (§6.3): cycles from the single clock, or the
    // source's static values when animation is off.
    double caustMotion, shinePos, scanPos, trace, breathe;
    if (elapsedMs == null) {
      caustMotion = 157;
      shinePos = -400;
      scanPos = 113;
      trace = 0;
      breathe = 0.75;
    } else {
      final e = elapsedMs!.toDouble();
      final caustT = (e % 14000) / 7000;
      caustMotion = 315 * (caustT < 1 ? caustT : 2 - caustT);
      final shineCycle = busy ? 1700.0 : 4400.0;
      final shineT = (e % shineCycle) / shineCycle;
      shinePos = shineT < 0.55 ? -380 + 760 * (shineT / 0.55) : 380;
      final scanT = (e % 2400) / 1200;
      scanPos = -20 + 270 * (scanT < 1 ? scanT : 2 - scanT);
      trace = (e % 1500) / 1500;
      final breatheT = (e % 6400) / 3200;
      breathe = 0.45 + 0.45 * (breatheT < 1 ? breatheT : 2 - breatheT);
    }

    // Under-glow: a blurred copy of the shape (a static-shape blur,
    // not backdrop blur), offset +14 units down.
    if (look.glow > 0) {
      canvas.save();
      canvas.translate(0, 14);
      canvas.drawPath(
        path,
        Paint()
          ..color = look.shadow.withValues(alpha: look.shadow.a * look.glow)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
      );
      canvas.restore();
    } else {
      canvas.save();
      canvas.translate(0, 14);
      canvas.drawPath(path, Paint()..color = look.shadow);
      canvas.restore();
    }

    // Body.
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [look.a, look.b],
        ).createShader(bounds),
    );

    canvas.save();
    canvas.clipPath(path);
    // Caustics band (1260 units wide, offset animated).
    final caustRect = Rect.fromLTWH(98.5 - 531.5 + caustMotion, 111, 1260, 290);
    canvas.drawRect(
      caustRect,
      Paint()
        ..shader = LinearGradient(
          colors: const [
            Color(0xFF00C3FF),
            Color(0xFF9A7CFF),
            Color(0xFFC7F24E),
            Color(0xFFFF8DC7),
            Color(0xFF00C3FF),
          ],
          stops: const [0, 0.25, 0.5, 0.75, 1],
        ).createShader(caustRect)
        ..color = Colors.white.withValues(alpha: look.caust),
    );
    // Shine sweep.
    final shineRect = Rect.fromLTWH(
      98.5 + shinePos - 190 + tiltX * 60,
      111,
      380,
      290,
    );
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.transparent,
            Colors.white.withValues(alpha: 0.35 * look.shine * breathe),
            Colors.transparent,
          ],
        ).createShader(shineRect),
    );
    // Busy scan band (64 units high).
    if (busy) {
      canvas.drawRect(
        Rect.fromLTWH(98.5, 111 + scanPos, 315, 64),
        Paint()..color = Colors.white.withValues(alpha: 0.7 * 0.35),
      );
    }
    // Specular radial.
    final specCenter = Offset(98.5 + 0.28 * 315, 111 + 0.08 * 290);
    final specRect = Rect.fromCircle(
      center: specCenter,
      radius: 0.6 * (315 + 290) / 2,
    );
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: look.spec),
            Colors.transparent,
          ],
        ).createShader(specRect),
    );
    canvas.restore();

    // Inner shade stroke (18 units).
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black.withValues(alpha: 0.45),
            Colors.black.withValues(alpha: look.shade),
          ],
        ).createShader(bounds),
    );
    // Inner highlight stroke (12 units).
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: look.hi),
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: look.lo),
          ],
          stops: const [0, 0.42, 0.72, 1],
        ).createShader(bounds),
    );
    // Rim stroke (1.3 dp in source units).
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3 * 315 / glyphWidth
        ..strokeJoin = StrokeJoin.round
        ..color = look.rim,
    );
    // Busy trace: a dashed segment travelling the outline.
    if (busy) {
      for (final metric in path.computeMetrics()) {
        final start = trace * metric.length;
        final end = math.min(start + 0.19 * metric.length, metric.length);
        canvas.drawPath(
          metric.extractPath(start, end),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..shader = LinearGradient(colors: [Colors.white, tint])
                .createShader(bounds),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ZPainter old) =>
      old.elapsedMs != elapsedMs ||
      old.busy != busy ||
      old.tiltX != tiltX ||
      old.look.a != look.a ||
      old.look.b != look.b ||
      old.look.glow != look.glow;
}

/// §2.7 Button — 56 dp capsule; tint fill off/busy, chrome on.
class GlassButtonConnect extends StatelessWidget {
  const GlassButtonConnect({
    super.key,
    required this.tokens,
    required this.spec,
  });

  final GlassTokens tokens;
  final ZedConnectSpec spec;

  @override
  Widget build(BuildContext context) {
    final on = spec.on;
    final Widget inner = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (spec.busy)
          ZedSpinner(
            size: 17,
            stroke: 2.2,
            color: on ? tokens.red : Colors.white,
          )
        else
          Icon(
            Icons.power_settings_new_rounded,
            size: 20,
            color: on ? tokens.red : Colors.white,
          ),
        const SizedBox(width: 10),
        Text(
          spec.actionLabel,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: on ? tokens.red : Colors.white,
          ),
        ),
      ],
    );
    return Semantics(
      button: true,
      toggled: on,
      label: spec.stateLabel,
      child: ZedPressScale(
        pressedScale: 1.07,
        spring: springPressGlass,
        child: GestureDetector(
          onTap: spec.enabled ? spec.onToggle : null,
          child: on
              ? GlassChromeSurface(
                  tokens: tokens,
                  child: SizedBox(height: 56, child: inner),
                )
              : DecoratedBox(
                  decoration: BoxDecoration(
                    color: tokens.tint.withValues(alpha: spec.busy ? 0.72 : 1),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: tokens.tint.withValues(alpha: 0.5),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(
                                    alpha: spec.busy ? 0.18 : 0.26,
                                  ),
                                  Colors.transparent,
                                ],
                                stops: const [0, 0.52],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 56, child: inner),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// The GlassSwitch itself (63×28 track, 37×24 knob, press squash).
class GlassSwitch extends StatefulWidget {
  const GlassSwitch({
    super.key,
    required this.tokens,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final GlassTokens tokens;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;

  @override
  State<GlassSwitch> createState() => _GlassSwitchState();
}

class _GlassSwitchState extends State<GlassSwitch>
    with TickerProviderStateMixin {
  late final AnimationController _knob = AnimationController(
    vsync: this,
    value: 0,
  );
  late final AnimationController _squash = AnimationController(
    vsync: this,
    value: 0,
  );

  @override
  void initState() {
    super.initState();
    _knob.value = widget.value ? 1 : 0;
  }

  @override
  void didUpdateWidget(GlassSwitch old) {
    super.didUpdateWidget(old);
    if (widget.value != old.value) {
      _knob.animateWith(
        SpringSimulation(springKnob, _knob.value, widget.value ? 1 : 0, 0),
      );
    }
  }

  @override
  void dispose() {
    _knob.dispose();
    _squash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.tokens;
    return Opacity(
      opacity: widget.enabled ? 1 : 0.4,
      child: Semantics(
        toggled: widget.value,
        child: Listener(
          onPointerDown: (_) => _squash.animateWith(
            SpringSimulation(composeSpring(1.0, 1500), _squash.value, 1, 0),
          ),
          onPointerUp: (_) => _squash.animateWith(
            SpringSimulation(composeSpring(1.0, 1500), _squash.value, 0, 0),
          ),
          onPointerCancel: (_) => _squash.value = 0,
          child: GestureDetector(
            onTap: widget.enabled && widget.onChanged != null
                ? () => widget.onChanged!(!widget.value)
                : null,
            child: AnimatedBuilder(
              animation: Listenable.merge([_knob, _squash]),
              builder: (context, _) {
                final trackColor = Color.lerp(c.fill, c.green, _knob.value)!;
                return Container(
                  width: 63,
                  height: 28,
                  decoration: BoxDecoration(
                    color: trackColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Stack(
                    children: [
                      PositionedDirectional(
                        start: 2 + 22 * _knob.value,
                        top: 2,
                        child: Transform.scale(
                          scaleX: 1 + 0.22 * _squash.value,
                          scaleY: 1 + 0.12 * _squash.value,
                          child: Container(
                            width: 37,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(
                                alpha: _squash.value > 0.05
                                    ? 0.55 + 0.45 * (1 - _squash.value)
                                    : 1,
                              ),
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x33000000),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
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
      ),
    );
  }
}

/// §2.7 Switch — the VPN card with icon disc + the GlassSwitch.
class GlassSwitchConnect extends StatelessWidget {
  const GlassSwitchConnect({
    super.key,
    required this.tokens,
    required this.spec,
  });

  final GlassTokens tokens;
  final ZedConnectSpec spec;

  @override
  Widget build(BuildContext context) {
    final on = spec.on;
    return GlassSurface(
      tokens: tokens,
      radius: BorderRadius.circular(26),
      child: SizedBox(
        height: 74,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: on ? tokens.green : tokens.fill,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shield_rounded,
                  size: 22,
                  color: on ? Colors.white : tokens.label,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spec.stateLabel,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: tokens.label,
                      ),
                    ),
                    Text(
                      spec.serverName.isNotEmpty ? spec.serverName : spec.hint,
                      style: TextStyle(fontSize: 15, color: tokens.label2),
                    ),
                  ],
                ),
              ),
              GlassSwitch(
                tokens: tokens,
                value: spec.active,
                enabled: spec.enabled,
                onChanged: (_) => spec.onToggle(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// §2.7 Slider — 74 dp chrome capsule, 64 dp knob, 0.70/0.30 flips.
class GlassSliderConnect extends StatefulWidget {
  const GlassSliderConnect({
    super.key,
    required this.tokens,
    required this.spec,
  });

  final GlassTokens tokens;
  final ZedConnectSpec spec;

  @override
  State<GlassSliderConnect> createState() => _GlassSliderConnectState();
}

class _GlassSliderConnectState extends State<GlassSliderConnect>
    with TickerProviderStateMixin {
  late final AnimationController _pos = AnimationController(vsync: this);
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  bool _dragging = false;
  double _startPos = 0;
  double _startX = 0;

  bool get _engaged => widget.spec.active;

  @override
  void initState() {
    super.initState();
    _pos.value = _engaged ? 1 : 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncShimmer();
  }

  @override
  void didUpdateWidget(GlassSliderConnect old) {
    super.didUpdateWidget(old);
    if (!_dragging && _engaged != old.spec.active) {
      _settle(_engaged ? 1 : 0, flip: true);
    }
    _syncShimmer();
  }

  void _syncShimmer() {
    final animate =
        !widget.spec.busy && !MediaQuery.disableAnimationsOf(context);
    if (animate && !_shimmer.isAnimating) {
      _shimmer.repeat();
    } else if (!animate && _shimmer.isAnimating) {
      _shimmer.stop();
    }
  }

  void _settle(double target, {bool flip = false}) {
    _pos.animateWith(
      SpringSimulation(
        flip ? composeSpring(1.0, 1500) : composeSpring(0.6, 400),
        _pos.value,
        target,
        0,
      ),
    );
  }

  @override
  void dispose() {
    _pos.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final tokens = widget.tokens;
    return Semantics(
      button: true,
      toggled: spec.on,
      label: spec.stateLabel,
      child: GlassChromeSurface(
        tokens: tokens,
        child: SizedBox(
          height: 74,
          child: LayoutBuilder(
            builder: (context, box) {
              final travel = math.max(1.0, box.maxWidth - 74);
              return Listener(
                onPointerDown: (e) {
                  if (!spec.enabled) return;
                  _dragging = true;
                  _startPos = _pos.value;
                  _startX = e.localPosition.dx;
                  _pos.stop();
                },
                onPointerMove: (e) {
                  if (!_dragging) return;
                  final rtl = Directionality.of(context) == TextDirection.rtl;
                  var dx = e.localPosition.dx - _startX;
                  if (rtl) dx = -dx;
                  _pos.value = (_startPos + dx / travel).clamp(0.0, 1.0);
                },
                onPointerUp: (_) {
                  if (!_dragging) return;
                  _dragging = false;
                  final moved = (_pos.value - _startPos).abs();
                  if (moved < 0.02) {
                    // A tap toggles (a busy tap cancels the attempt).
                    spec.onToggle();
                    _settle(_engaged ? 0 : 1, flip: true);
                    return;
                  }
                  final crossed = _engaged
                      ? _pos.value < 0.30
                      : _pos.value > 0.70;
                  if (crossed) {
                    spec.onToggle();
                    _settle(_engaged ? 0 : 1, flip: true);
                  } else {
                    _settle(_engaged ? 1 : 0);
                  }
                },
                onPointerCancel: (_) {
                  _dragging = false;
                  _settle(_engaged ? 1 : 0);
                },
                child: AnimatedBuilder(
                  animation: Listenable.merge([_pos, _shimmer]),
                  builder: (context, _) => Stack(
                    children: [
                      Center(
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(
                            start: 72,
                            end: 72,
                          ),
                          child: ShaderMask(
                            shaderCallback: (rect) {
                              final p = -1 + 3 * _shimmer.value;
                              return LinearGradient(
                                colors: [
                                  tokens.label.withValues(alpha: 0.35),
                                  tokens.label,
                                  tokens.label.withValues(alpha: 0.35),
                                ],
                                stops: const [0, 0.5, 1],
                                begin: Alignment(p - 1, 0),
                                end: Alignment(p + 1, 0),
                              ).createShader(rect);
                            },
                            blendMode: BlendMode.srcIn,
                            child: Text(
                              spec.hint,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                                color: tokens.label,
                              ),
                            ),
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        start: 5 + travel * _pos.value,
                        top: 5,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x40000000),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: CustomPaint(
                            painter: _MiniZPainter(
                              color: spec.on
                                  ? const Color(0xFFB06CFF)
                                  : tokens.tint,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MiniZPainter extends CustomPainter {
  _MiniZPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = 30 / 315;
    canvas.translate((size.width - 30) / 2, (size.height - 30 * 290 / 315) / 2);
    canvas.scale(s);
    canvas.translate(-98.5, -111);
    canvas.drawPath(zedMarkPath(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_MiniZPainter old) => old.color != color;
}
