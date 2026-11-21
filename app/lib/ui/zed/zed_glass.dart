import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import 'zed_prefs.dart';

/// The Liquid Glass kit, reimplemented in Dart from the documented
/// ZedSecure v3.2.0 recipe (LIQUID-GLASS.md): real backdrop blur ONLY on
/// floating chrome (dock pill, circle buttons, tool groups, the top
/// edge); everything else is simulated glass — a translucent fill, a
/// 1 dp five-stop gradient rim, and a cached 1 dp specular sliver.
/// Sheets and menus stay solid. Press feedback is scale/flash, never a
/// ripple, and the press scale is 1.07.

abstract final class GlassTokens {
  /// Module fill: dark Clear 0x612C2C30 (38%), light Clear 50% white;
  /// Tinted ≈ 85% on both.
  static Color moduleFill(bool dark, GlassMaterial material) =>
      switch (material) {
        GlassMaterial.tinted =>
          dark ? const Color(0xDB28282C) : const Color(0xD6FFFFFF),
        GlassMaterial.clear =>
          dark ? const Color(0x612C2C30) : const Color(0x80FFFFFF),
      };

  /// Chrome fill (the floating pieces that also blur), exact (§2.1):
  /// Clear 40% #1E1E20 dark / 38% white light; Tinted ≈ 86%/80%.
  static Color chromeFill(bool dark, GlassMaterial material) =>
      switch (material) {
        GlassMaterial.tinted =>
          dark ? const Color(0xDB242426) : const Color(0xCCFFFFFF),
        GlassMaterial.clear =>
          dark ? const Color(0x661E1E20) : const Color(0x61FFFFFF),
      };

  /// The reduced-transparency solids (§2.1).
  static Color solidCell(bool dark) =>
      dark ? const Color(0xFF1C1C1E) : Colors.white;
  static Color chromeSolid(bool dark) =>
      dark ? const Color(0xFF2C2C2E) : const Color(0xFFF9F9FB);

  static const double cellRadius = 26;
  static const double moduleRadius = 24;
  static const double sheetRadius = 38;
  static const double menuRadius = 24;

  /// The dock's total reserved height: 62 bar + 22 breathing room, plus
  /// the recipe's 10 dp clearance — pages honour a 94 dp bottom inset.
  static const double dockInset = 94;
  static const double dockHeight = 62;

  /// The rim (§2.2): rimHi → rimMid at 0.28 → transparent at 0.48/0.64
  /// → rimLo, in the recipe's exact alphas (dark #94/#12/#42 white;
  /// light full / #47 / #CC white).
  static Gradient rimGradient(
    bool dark, {
    Alignment begin = Alignment.topLeft,
    Alignment end = Alignment.bottomRight,
  }) {
    final hi = Colors.white.withValues(alpha: dark ? 0.58 : 1);
    final mid = Colors.white.withValues(alpha: dark ? 0.07 : 0.28);
    final lo = Colors.white.withValues(alpha: dark ? 0.26 : 0.80);
    // The clear stops are white at zero alpha, NOT Colors.transparent
    // (black at zero alpha): interpolating toward black would drag
    // the rim's fade through a dark tint.
    final clear = Colors.white.withValues(alpha: 0);
    return LinearGradient(
      begin: begin,
      end: end,
      colors: [hi, mid, clear, clear, lo],
      stops: const [0, 0.28, 0.48, 0.64, 1],
    );
  }

  /// The specular sliver along the top edge (#38 white dark, #F2 white
  /// light — §2.1's highlight token).
  static Color highlight(bool dark) =>
      Colors.white.withValues(alpha: dark ? 0.22 : 0.95);
}

/// The procedural, static wallpaper behind Glass pages. Captured once
/// at the scaffold; it never scrolls or animates (the recipe's
/// smoothness rule).
class GlassWallpaperView extends StatelessWidget {
  const GlassWallpaperView({
    super.key,
    required this.prefs,
    required this.dark,
  });

  final ZedPrefs prefs;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    // The five wallpapers, exact (§2.6): fixed vertical gradients —
    // the tint never recolours them — plus soft ellipse glows on
    // Lagoon, Dusk and Graphite.
    final (colors, stops, glows, solid) = switch (prefs.glassWallpaper) {
      GlassWallpaper.live => (
        dark
            ? const [Color(0xFF17191E), Color(0xFF0B0C0F), Color(0xFF000000)]
            : const [Color(0xFFE4E8EF), Color(0xFFECEEF3), Color(0xFFF2F2F7)],
        const [0.0, 0.52, 1.0],
        const <_Glow>[],
        null,
      ),
      GlassWallpaper.lagoon => (
        dark
            ? const [Color(0xFF031327), Color(0xFF010812)]
            : const [Color(0xFFE2EFFF), Color(0xFFEEF5FA)],
        const [0.0, 1.0],
        [
          _Glow(0.82, 0.06, 0.85, 0.42, Color(dark ? 0x730091FF : 0x5C0088FF)),
          _Glow(0.08, 0.58, 0.80, 0.40, Color(dark ? 0x4700D2E0 : 0x4700C3D0)),
        ],
        null,
      ),
      GlassWallpaper.dusk => (
        dark
            ? const [Color(0xFF1A0712), Color(0xFF0A0410)]
            : const [Color(0xFFFFF0E6), Color(0xFFF6EDFB)],
        const [0.0, 1.0],
        [
          _Glow(0.20, 0.06, 0.85, 0.42, Color(dark ? 0x61FF9230 : 0x5CFF8D28)),
          _Glow(0.90, 0.60, 0.80, 0.40, Color(dark ? 0x52DB34F2 : 0x3DCB30E0)),
        ],
        null,
      ),
      GlassWallpaper.graphite => (
        dark
            ? const [Color(0xFF121317), Color(0xFF050506)]
            : const [Color(0xFFE1E5EC), Color(0xFFECEEF2)],
        const [0.0, 1.0],
        [_Glow(0.80, 0.08, 0.85, 0.42, Color(dark ? 0x3D98989D : 0xE6FFFFFF))],
        null,
      ),
      GlassWallpaper.plain => (
        const <Color>[],
        const <double>[],
        const <_Glow>[],
        dark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: solid == null
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: colors,
                stops: stops,
              )
            : null,
        color: solid,
      ),
      child: glows.isEmpty
          ? const SizedBox.expand()
          : CustomPaint(
              painter: _GlowPainter(glows),
              child: const SizedBox.expand(),
            ),
    );
  }
}

/// One wallpaper glow: an ellipse centred at (cx, cy) of the size,
/// radii (rx, ry), fading to nothing at 72% of its radius (§2.6).
class _Glow {
  const _Glow(this.cx, this.cy, this.rx, this.ry, this.color);

  final double cx;
  final double cy;
  final double rx;
  final double ry;
  final Color color;
}

class _GlowPainter extends CustomPainter {
  const _GlowPainter(this.glows);

  final List<_Glow> glows;

  @override
  void paint(Canvas canvas, Size size) {
    for (final g in glows) {
      final center = Offset(g.cx * size.width, g.cy * size.height);
      final rx = g.rx * size.width;
      final ry = g.ry * size.height;
      if (rx <= 0 || ry <= 0) continue;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(1, ry / rx);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [g.color, g.color.withValues(alpha: 0)],
          stops: const [0, 0.72],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: rx));
      canvas.drawCircle(Offset.zero, rx, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.glows != glows;
}

/// A simulated-glass module: translucent fill + 1 dp gradient rim + the
/// top specular sliver. No blur — modules scroll, and the recipe never
/// blurs scrolling content.
class GlassModule extends StatelessWidget {
  const GlassModule({
    super.key,
    required this.child,
    this.radius = GlassTokens.moduleRadius,
    this.padding,
    this.onTap,
    this.solid = false,
    this.reduced = false,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  /// The solid-cell form (the original's `glassLists` off state):
  /// list cells stop being glass — the solid cell fill, no rim
  /// gradient, no specular sliver (the recipe draws highlight and
  /// rim only on translucent surfaces).
  final bool solid;

  /// Reduce-transparency: the recipe draws highlight and rim only
  /// "if not reduced" (§2.2), so a reduced module is the solid fill
  /// alone — the theme already resolves that fill into the card
  /// colour (round-2 finding G1: the rim and sliver used to paint
  /// anyway, over the solid fill).
  final bool reduced;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (solid || reduced) {
      final body = DecoratedBox(
        decoration: BoxDecoration(
          color: solid
              ? GlassTokens.solidCell(dark)
              : (Theme.of(context).cardTheme.color ??
                    GlassTokens.solidCell(dark)),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      );
      final tap = onTap;
      if (tap == null) return body;
      return ZedPressable(onTap: tap, child: body);
    }
    // Prefs reach the kit through the theme's card colour alpha for the
    // material; the rim/highlight are pure recipe constants.
    final fill =
        Theme.of(context).cardTheme.color ??
        GlassTokens.moduleFill(dark, GlassMaterial.clear);
    final body = DecoratedBox(
      decoration: BoxDecoration(
        gradient: GlassTokens.rimGradient(dark),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(radius - 1),
          ),
          child: Stack(
            children: [
              Padding(padding: padding ?? EdgeInsets.zero, child: child),
              // The specular sliver: the top 1 dp slice of the
              // module's own outline (the original's glassHighlight
              // draws outline − outline-shifted-1dp, so the line
              // follows the corner arcs across the full width —
              // round 3, finding G-3: the port drew a straight
              // inset bar that stopped short of the corners).
              Positioned.fill(
                child: CustomPaint(
                  painter: _SliverPainter(
                    radius: radius - 1,
                    color: GlassTokens.highlight(dark),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final tap = onTap;
    if (tap == null) return body;
    return ZedPressable(onTap: tap, child: body);
  }
}

/// Paints the specular sliver as the top 1 dp slice of a rounded
/// rect's outline: the shape minus itself shifted down 1 dp.
class _SliverPainter extends CustomPainter {
  const _SliverPainter({required this.radius, required this.color});

  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    final slice = Path.combine(
      PathOperation.difference,
      outline,
      outline.shift(const Offset(0, 1)),
    );
    canvas.drawPath(slice, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SliverPainter old) =>
      old.radius != radius || old.color != color;
}

/// Real-glass chrome: the ONLY pieces allowed a backdrop blur (~12 dp).
/// Used for the dock pill, circle buttons and the top edge. With
/// reduce-transparency the blur goes away and the fill turns solid.
/// With the Glass "Motion highlights" preference on, the rim's light
/// follows the pointer over the chrome (the original drives the same
/// highlight from device tilt; a pointer is this kit's input on every
/// platform) — off, the rim is the recipe's static gradient.
class GlassChrome extends StatefulWidget {
  const GlassChrome({
    super.key,
    required this.child,
    required this.prefs,
    this.radius = 32,
    this.blur = 12,
  });

  final Widget child;
  final ZedPrefs prefs;
  final double radius;
  final double blur;

  @override
  State<GlassChrome> createState() => _GlassChromeState();
}

class _GlassChromeState extends State<GlassChrome> {
  /// The pointer's position over the chrome, as fractions of the
  /// chrome's size minus 0.5 (so 0 is centred); (0, 0) at rest.
  Offset _tilt = Offset.zero;

  void _track(PointerEvent e) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final local = box.globalToLocal(e.position);
    final dx = (local.dx / box.size.width - 0.5).clamp(-0.5, 0.5);
    final dy = (local.dy / box.size.height - 0.5).clamp(-0.5, 0.5);
    final next = Offset(dx, dy);
    if (next != _tilt) setState(() => _tilt = next);
  }

  @override
  Widget build(BuildContext context) {
    final prefs = widget.prefs;
    final radius = widget.radius;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final solid = prefs.reduceTransparency;
    final fill = solid
        ? GlassTokens.chromeSolid(dark)
        : GlassTokens.chromeFill(dark, prefs.glassMaterial);
    final motion = prefs.glassMotionHighlights && !solid;
    Widget body = DecoratedBox(
      decoration: BoxDecoration(
        gradient: GlassTokens.rimGradient(
          dark,
          begin: Alignment(-1 + 0.6 * _tilt.dx, -1 + 0.6 * _tilt.dy),
          end: Alignment(1 + 0.6 * _tilt.dx, 1 + 0.6 * _tilt.dy),
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(radius - 1),
          ),
          child: widget.child,
        ),
      ),
    );
    if (!solid) {
      body = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
          child: body,
        ),
      );
    }
    // The drop shadow lives OUTSIDE the clip: a shadow painted by
    // the clipped body is cut off at the chrome's own outline, so
    // the floating chrome used to lose its shadow exactly when the
    // blur was on (round-2 finding G3).
    body = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            // The recipe's shadow token (§2.1): 50% black in the
            // dark, 12% in the light — the port used a fixed 20%
            // for both (round 3, finding G-2).
            color: dark ? const Color(0x80000000) : const Color(0x1F000000),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: body,
    );
    if (!motion) return body;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerMove: _track,
      onPointerHover: _track,
      onPointerUp: (_) {
        if (_tilt != Offset.zero) setState(() => _tilt = Offset.zero);
      },
      onPointerCancel: (_) {
        if (_tilt != Offset.zero) setState(() => _tilt = Offset.zero);
      },
      child: body,
    );
  }
}

/// Press feedback the glass way: scale to 1.07 on a 0.5/Medium spring,
/// no ripple. Outside Glass the same widget gives the subtler 1.03.
class ZedPressable extends StatefulWidget {
  const ZedPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.glass = true,
    this.pressScale,
  });

  final Widget child;
  final VoidCallback onTap;
  final bool glass;

  /// The pressed scale when the design's own rule differs from the
  /// glass grow (1.07): Bento cards shrink to 0.965, Pixel/Old to
  /// 0.985 (§1.5).
  final double? pressScale;

  @override
  State<ZedPressable> createState() => _ZedPressableState();
}

class _ZedPressableState extends State<ZedPressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: widget.onTap,
    onTapDown: (_) => setState(() => _down = true),
    onTapUp: (_) => setState(() => _down = false),
    onTapCancel: () => setState(() => _down = false),
    child: AnimatedScale(
      scale: _down ? (widget.pressScale ?? (widget.glass ? 1.07 : 1.03)) : 1,
      // Reduced motion kills the press grow, as it does in the
      // kit's own press wrappers (round 3, finding G-1: this one
      // animated under the OS setting).
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      child: widget.child,
    ),
  );
}

/// The glass switch: a platter and knob on the recipe's springs
/// (knob 0.62/MediumLow, thumb+platter 0.72/MediumLow — expressed here
/// as the matching ease curves, since Flutter springs are curve-driven
/// in this kit).
class GlassSwitch extends StatelessWidget {
  const GlassSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.prefs,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final ZedPrefs prefs;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final duration = reduced
        ? Duration.zero
        : const Duration(milliseconds: 240);
    // The original's switch geometry (§2.7, exact source values):
    // a 63×28 capsule track — green when on (the iOS green pair,
    // NOT the user's glass tint), the neutral `fill` token when
    // off — and a 37×24 capsule knob travelling 2dp → 24dp.
    // (Round 2, finding G2: the port had a 52×32 tint-coloured
    // switch with a round knob.)
    // A disabled switch dims to 40% (§2.7) — the port only detached
    // the tap handler and rendered it fully opaque (round 3, G-4).
    return Opacity(
      opacity: onChanged == null ? 0.4 : 1,
      child: Semantics(
        toggled: value,
        child: GestureDetector(
          onTap: onChanged == null ? null : () => onChanged!(!value),
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.easeOut,
            width: 63,
            height: 28,
            decoration: BoxDecoration(
              color: value
                  ? (dark ? const Color(0xFF30D158) : const Color(0xFF34C759))
                  : (dark ? const Color(0x5C787880) : const Color(0x33787880)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: duration,
                  curve: Curves.easeOut,
                  left: value ? 24 : 2,
                  top: 2,
                  child: Container(
                    width: 37,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
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
