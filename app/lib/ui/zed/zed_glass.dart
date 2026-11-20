import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import 'zed_prefs.dart';
import 'zed_theme.dart';

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
  static Gradient rimGradient(bool dark) {
    final hi = Colors.white.withValues(alpha: dark ? 0.58 : 1);
    final mid = Colors.white.withValues(alpha: dark ? 0.07 : 0.28);
    final lo = Colors.white.withValues(alpha: dark ? 0.26 : 0.80);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [hi, mid, Colors.transparent, Colors.transparent, lo],
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
  const GlassWallpaperView({super.key, required this.prefs, required this.dark});

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
        [
          _Glow(0.80, 0.08, 0.85, 0.42, Color(dark ? 0x3D98989D : 0xE6FFFFFF)),
        ],
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
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Prefs reach the kit through the theme's card colour alpha for the
    // material; the rim/highlight are pure recipe constants.
    final fill = Theme.of(context).cardTheme.color ??
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
              Padding(
                padding: padding ?? EdgeInsets.zero,
                child: child,
              ),
              // The specular sliver: one cached 1 dp line at the top.
              Positioned(
                top: 0,
                left: radius * 0.6,
                right: radius * 0.6,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        GlassTokens.highlight(dark),
                        Colors.transparent,
                      ],
                    ),
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

/// Real-glass chrome: the ONLY pieces allowed a backdrop blur (~12 dp).
/// Used for the dock pill, circle buttons and the top edge. With
/// reduce-transparency the blur goes away and the fill turns solid.
class GlassChrome extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final solid = prefs.reduceTransparency;
    final fill = solid
        ? GlassTokens.chromeSolid(dark)
        : GlassTokens.chromeFill(dark, prefs.glassMaterial);
    Widget body = DecoratedBox(
      decoration: BoxDecoration(
        gradient: GlassTokens.rimGradient(dark),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 8)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(radius - 1),
          ),
          child: child,
        ),
      ),
    );
    if (solid) return body;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: body,
      ),
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
      duration: const Duration(milliseconds: 180),
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
    final tint = glassTintColor(prefs.glassTint, dark);
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
        width: 52,
        height: 32,
        decoration: BoxDecoration(
          color: value
              ? tint.withValues(alpha: 0.85)
              : GlassTokens.moduleFill(dark, prefs.glassMaterial),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: dark ? 0.18 : 0.4),
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutBack,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
