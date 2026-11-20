import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'zed_prefs.dart';

/// The central motion system, reimplemented from the documented
/// ZedSecure v3.2.0 spec (ZEDSECURE-MASTER.md §7/§25): one place decides
/// how pages change. Direction comes from the tab order; reduce-motion
/// (or the app's animations-off setting) collapses everything to a
/// 120/90 ms fade.

abstract final class ZedMotion {
  /// Wraps a page change between [forward] direction signs: the sign of
  /// (new index − old index) in tab order, flipped for RTL by the
  /// caller where the original flips it.
  static Widget transition({
    required ZedTransitionStyle style,
    required bool reduceMotion,
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
    required Widget child,
  }) {
    if (reduceMotion) {
      return FadeTransition(opacity: animation, child: child);
    }
    switch (style) {
      case ZedTransitionStyle.fade:
        return FadeTransition(opacity: animation, child: child);
      case ZedTransitionStyle.slide:
        // 320 ms at a third of the width (duration lives on the switcher).
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1 / 3, 0),
            end: Offset.zero,
          ).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        );
      case ZedTransitionStyle.push:
        // Enter full width, exit a third — the asymmetric Push pair is
        // approximated on the single switcher animation.
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        );
      case ZedTransitionStyle.depth:
        return ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        );
      case ZedTransitionStyle.elastic:
        return ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        );
      case ZedTransitionStyle.curtain:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.5),
            end: Offset.zero,
          ).animate(animation),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(animation),
            child: child,
          ),
        );
      case ZedTransitionStyle.flip:
        return AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) {
            final t = animation.value;
            final angle = (1 - t) * math.pi * (78 / 180);
            return Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0018)
                ..rotateY(angle),
              alignment: Alignment.center,
              child: child,
            );
          },
        );
    }
  }

  static Duration duration(ZedTransitionStyle style, bool reduceMotion) {
    if (reduceMotion) return const Duration(milliseconds: 120);
    return switch (style) {
      ZedTransitionStyle.fade => const Duration(milliseconds: 260),
      ZedTransitionStyle.slide => const Duration(milliseconds: 320),
      ZedTransitionStyle.push => const Duration(milliseconds: 340),
      ZedTransitionStyle.depth => const Duration(milliseconds: 340),
      ZedTransitionStyle.elastic => const Duration(milliseconds: 450),
      ZedTransitionStyle.curtain => const Duration(milliseconds: 340),
      ZedTransitionStyle.flip => const Duration(milliseconds: 360),
    };
  }

  static Duration reverseDuration(
    ZedTransitionStyle style,
    bool reduceMotion,
  ) {
    if (reduceMotion) return const Duration(milliseconds: 90);
    return switch (style) {
      ZedTransitionStyle.fade => const Duration(milliseconds: 180),
      _ => duration(style, reduceMotion),
    };
  }

  static Curve curve(ZedTransitionStyle style) => switch (style) {
    ZedTransitionStyle.elastic => Curves.elasticOut,
    ZedTransitionStyle.depth => Curves.easeOutCubic,
    ZedTransitionStyle.curtain => Curves.easeOutCubic,
    _ => Curves.easeInOutCubic,
  };
}

/// A page switcher with the nav chrome OUTSIDE it: the shell builds the
/// dock/rail as a sibling and only the page area goes through here —
/// the MainScaffold rule from the design study (§6).
class ZedPageSwitcher extends StatelessWidget {
  const ZedPageSwitcher({
    super.key,
    required this.prefs,
    required this.reduceMotion,
    required this.child,
  });

  final ZedPrefs prefs;
  final bool reduceMotion;

  /// The current page, keyed by its destination so the switcher can
  /// tell pages apart.
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: ZedMotion.duration(prefs.transitionStyle, reduceMotion),
    reverseDuration: ZedMotion.reverseDuration(
      prefs.transitionStyle,
      reduceMotion,
    ),
    switchInCurve: ZedMotion.curve(prefs.transitionStyle),
    switchOutCurve: Curves.easeIn,
    transitionBuilder: (child, animation) => ZedMotion.transition(
      style: prefs.transitionStyle,
      reduceMotion: reduceMotion,
      animation: animation,
      secondaryAnimation: const AlwaysStoppedAnimation(0),
      child: child,
    ),
    child: child,
  );
}

/// The one entrance stagger in the design system (server list, §25):
/// an 800 ms window, each row delayed min(index, 12) × 45 ms, rising
/// 26 dp with alpha and a 0.96→1 scale on a spring-like curve.
class ZedEntrance extends StatefulWidget {
  const ZedEntrance({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<ZedEntrance> createState() => _ZedEntranceState();
}

class _ZedEntranceState extends State<ZedEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  @override
  void initState() {
    super.initState();
    final delay = Duration(milliseconds: math.min(widget.index, 12) * 45);
    if (delay == Duration.zero) {
      _c.forward();
    } else {
      Future.delayed(delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (context, child) {
      final t = Curves.easeOutBack.transform(_c.value.clamp(0, 1));
      return Opacity(
        opacity: _c.value.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, 26 * (1 - t)),
          child: Transform.scale(scale: 0.96 + 0.04 * t, child: child),
        ),
      );
    },
  );
}
