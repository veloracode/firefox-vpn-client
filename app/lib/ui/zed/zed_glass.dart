import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import 'zed_prefs.dart';
import 'zed_theme.dart';

/// The Liquid Glass rendering layer, reimplemented from
/// `ui/glass/GlassKit.kt`, `ui/glass/GlassChrome.kt` and
/// `ui/glass/GlassTheme.kt` (see LIQUID-GLASS.md).
///
/// The split that keeps it smooth: real backdrop blur exists ONLY in
/// [GlassChromeSurface] and [GlassTopEdge] — small floating chrome.
/// Everything else is [GlassSurface]: a flat translucent fill + a
/// five-stop gradient rim + a 1 dp specular sliver. No blur, no
/// shadow on cells/modules.

/// The rim gradient brush (`glassRimBrush`): bright at the top, dead
/// mid-way, weaker return at the bottom. Diagonal, top-left →
/// bottom-right, as Compose's default linearGradient.
LinearGradient glassRimGradient(GlassTokens c) => LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [c.rimHi, c.rimMid, Colors.transparent, Colors.transparent, c.rimLo],
  stops: const [0.0, 0.28, 0.48, 0.64, 1.0],
);

RRect _rrect(Size size, BorderRadiusGeometry radius, TextDirection dir) =>
    radius.resolve(dir).toRRect(Offset.zero & size);

/// Paints the specular sliver (top 1 dp band of the outline) and the
/// rim (1 dp gradient stroke) over a clipped surface.
class _GlassEdgePainter extends CustomPainter {
  _GlassEdgePainter({
    required this.radius,
    required this.tokens,
    required this.direction,
    required this.sliver,
  });

  final BorderRadiusGeometry radius;
  final GlassTokens tokens;
  final TextDirection direction;
  final bool sliver;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = _rrect(size, radius, direction);
    if (sliver) {
      // Outline minus (outline shifted down 1 dp) = the top band.
      final outer = Path()..addRRect(rrect);
      final shifted = Path()..addRRect(rrect.shift(const Offset(0, 1)));
      final band = Path.combine(PathOperation.difference, outer, shifted);
      canvas.drawPath(band, Paint()..color = tokens.highlight);
    }
    final strokeRect = rrect.deflate(0.5);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = glassRimGradient(tokens).createShader(Offset.zero & size);
    canvas.drawRRect(strokeRect, paint);
  }

  @override
  bool shouldRepaint(_GlassEdgePainter old) =>
      old.radius != radius ||
      old.tokens.rimHi != tokens.rimHi ||
      old.tokens.rimMid != tokens.rimMid ||
      old.tokens.rimLo != tokens.rimLo ||
      old.tokens.highlight != tokens.highlight ||
      old.sliver != sliver;
}

/// Simulated glass (`glassCell` / `glassModule`): clip → flat fill →
/// highlight → rim. When [tokens] is reduced, the fill is the solid
/// twin and no edge is drawn. When [grouped] is set (list cells under
/// glassLists=false) the fill is the solid cell colour.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.tokens,
    required this.child,
    this.radius = const BorderRadius.all(Radius.circular(24)),
    this.fill,
    this.module = true,
    this.padding,
  });

  final GlassTokens tokens;
  final Widget child;
  final BorderRadiusGeometry radius;

  /// Overrides the fill (defaults to module/cell token by [module]).
  final Color? fill;
  final bool module;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final dir = Directionality.of(context);
    final showEdge = module ? !tokens.reduced : tokens.translucent;
    final color = fill ?? (module ? tokens.module : tokens.cell);
    Widget content = child;
    if (padding != null) content = Padding(padding: padding!, child: content);
    return ClipRRect(
      borderRadius: radius,
      child: DecoratedBox(
        decoration: BoxDecoration(color: color),
        child: CustomPaint(
          foregroundPainter: showEdge
              ? _GlassEdgePainter(
                  radius: radius,
                  tokens: tokens,
                  direction: dir,
                  sliver: true,
                )
              : null,
          child: content,
        ),
      ),
    );
  }
}

/// Real glass (`glassChrome`): backdrop blur 12 + the chrome fill +
/// the same rim/highlight, reserved for small floating chrome (tab
/// pill, circle buttons, search capsule). Isolated behind a
/// RepaintBoundary so scrolling content does not repaint it. When
/// [tokens] is reduced, falls back to the solid chrome fill with the
/// same edge — the design never *requires* blur.
class GlassChromeSurface extends StatelessWidget {
  const GlassChromeSurface({
    super.key,
    required this.tokens,
    required this.child,
    this.radius = const BorderRadius.all(Radius.circular(999)),
    this.blur = 12,
    this.elevated = true,
  });

  final GlassTokens tokens;
  final Widget child;
  final BorderRadiusGeometry radius;
  final double blur;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final dir = Directionality.of(context);
    final Widget body;
    if (tokens.reduced) {
      body = DecoratedBox(
        decoration: BoxDecoration(color: tokens.chromeSolid),
        child: child,
      );
    } else {
      body = BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(color: tokens.chrome),
          child: child,
        ),
      );
    }
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: elevated
              ? [
                  BoxShadow(
                    color: tokens.shadow,
                    blurRadius: 24,
                    offset: Offset.zero,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: CustomPaint(
            foregroundPainter: _GlassEdgePainter(
              radius: radius,
              tokens: tokens,
              direction: dir,
              sliver: true,
            ),
            child: body,
          ),
        ),
      ),
    );
  }
}

/// The status-bar top edge (`GlassTopEdge`): a strip of
/// status-inset + 14 dp, blur 10, wallpaper-top tone at 35%, fading
/// out at 55% of its height. Reduced transparency → tone gradient
/// 0.96 → 0.90 at 0.55 → 0.
class GlassTopEdge extends StatelessWidget {
  const GlassTopEdge({
    super.key,
    required this.tokens,
    required this.wallpaper,
  });

  final GlassTokens tokens;
  final GlassWallpaper wallpaper;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final tone = wallpaperTop(wallpaper, tokens.dark);
    return IgnorePointer(
      child: SizedBox(
        height: top + 14,
        child: tokens.reduced
            ? DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      tone.withValues(alpha: 0.96),
                      tone.withValues(alpha: 0.90),
                      tone.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.55, 1],
                  ),
                ),
              )
            : ClipRect(
                child: ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white, Colors.white, Colors.transparent],
                    stops: [0, 0.55, 1],
                  ).createShader(rect),
                  blendMode: BlendMode.dstIn,
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: tone.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// The tone at the top of each wallpaper (`wallpaperTop`).
Color wallpaperTop(GlassWallpaper kind, bool dark) => switch (kind) {
  GlassWallpaper.live =>
    dark ? const Color(0xFF17191E) : const Color(0xFFE4E8EF),
  GlassWallpaper.lagoon =>
    dark ? const Color(0xFF031327) : const Color(0xFFE2EFFF),
  GlassWallpaper.dusk =>
    dark ? const Color(0xFF1A0712) : const Color(0xFFFFF0E6),
  GlassWallpaper.graphite =>
    dark ? const Color(0xFF121317) : const Color(0xFFE1E5EC),
  GlassWallpaper.plain =>
    dark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
};

/// The procedural wallpaper (`drawGlassWallpaper`): vertical gradients
/// + elliptical radial glows. Zero assets, drawn once, static while
/// content scrolls — wrapped in a RepaintBoundary by the shells.
class GlassWallpaperView extends StatelessWidget {
  const GlassWallpaperView({
    super.key,
    required this.tokens,
    required this.wallpaper,
  });

  final GlassTokens tokens;
  final GlassWallpaper wallpaper;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: _WallpaperPainter(kind: wallpaper, dark: tokens.dark),
      size: Size.infinite,
    ),
  );
}

class _WallpaperPainter extends CustomPainter {
  _WallpaperPainter({required this.kind, required this.dark});

  final GlassWallpaper kind;
  final bool dark;

  void _glow(
    Canvas canvas,
    Size size,
    double cx,
    double cy,
    double rx,
    double ry,
    Color color,
  ) {
    final center = Offset(cx * size.width, cy * size.height);
    final radius = rx * size.width;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1, (ry * size.height) / radius);
    final rect = Rect.fromCircle(center: Offset.zero, radius: radius);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0)],
        stops: const [0, 0.72],
      ).createShader(rect);
    canvas.drawCircle(Offset.zero, radius, paint);
    canvas.restore();
  }

  void _base(
    Canvas canvas,
    Size size,
    List<Color> colors, [
    List<double>? stops,
  ]) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
          stops: stops,
        ).createShader(rect),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    switch (kind) {
      case GlassWallpaper.live:
        _base(
          canvas,
          size,
          [
            dark ? const Color(0xFF17191E) : const Color(0xFFE4E8EF),
            dark ? const Color(0xFF0B0C0F) : const Color(0xFFECEEF3),
            dark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
          ],
          const [0, 0.52, 1],
        );
      case GlassWallpaper.lagoon:
        _base(canvas, size, [
          dark ? const Color(0xFF031327) : const Color(0xFFE2EFFF),
          dark ? const Color(0xFF010812) : const Color(0xFFEEF5FA),
        ]);
        _glow(
          canvas,
          size,
          0.82,
          0.06,
          0.85,
          0.42,
          dark ? const Color(0x730091FF) : const Color(0x5C0088FF),
        );
        _glow(
          canvas,
          size,
          0.08,
          0.58,
          0.80,
          0.40,
          dark ? const Color(0x4700D2E0) : const Color(0x4700C3D0),
        );
      case GlassWallpaper.dusk:
        _base(canvas, size, [
          dark ? const Color(0xFF1A0712) : const Color(0xFFFFF0E6),
          dark ? const Color(0xFF0A0410) : const Color(0xFFF6EDFB),
        ]);
        _glow(
          canvas,
          size,
          0.20,
          0.06,
          0.85,
          0.42,
          dark ? const Color(0x61FF9230) : const Color(0x5CFF8D28),
        );
        _glow(
          canvas,
          size,
          0.90,
          0.60,
          0.80,
          0.40,
          dark ? const Color(0x52DB34F2) : const Color(0x3DCB30E0),
        );
      case GlassWallpaper.graphite:
        _base(canvas, size, [
          dark ? const Color(0xFF121317) : const Color(0xFFE1E5EC),
          dark ? const Color(0xFF050506) : const Color(0xFFECEEF2),
        ]);
        _glow(
          canvas,
          size,
          0.80,
          0.08,
          0.85,
          0.42,
          dark ? const Color(0x3D98989D) : const Color(0xE6FFFFFF),
        );
      case GlassWallpaper.plain:
        canvas.drawRect(
          Offset.zero & size,
          Paint()
            ..color = dark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
        );
    }
  }

  // Value comparison, never identity (a repaint bug in the previous
  // attempt came from list-identity shouldRepaint).
  @override
  bool shouldRepaint(_WallpaperPainter old) =>
      old.kind != kind || old.dark != dark;
}
