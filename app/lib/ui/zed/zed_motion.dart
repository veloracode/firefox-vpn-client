import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'zed_prefs.dart';

/// The central motion system, reimplemented from the documented
/// ZedSecure v3.2.0 spec (ZEDSECURE-MASTER.md §7/§25): one place decides
/// how pages change. Direction comes from the tab order; reduce-motion
/// (or the app's animations-off setting) collapses everything to a
/// 120/90 ms fade.

abstract final class ZedMotion {
  /// True while [animation] belongs to the OUTGOING page: the
  /// switcher runs the same builder for both pages, the incoming one
  /// driving its animation forward, the outgoing one in reverse.
  /// The reference gives enter and exit SEPARATE transforms (§6.1),
  /// so the branches below pick the transform by this test (proven
  /// by zed_motion_exits_test.dart: mid-transition the outgoing
  /// page's transform is the exit one, not the reversed enter).
  static bool _exiting(Animation<double> animation) =>
      animation.status == AnimationStatus.reverse ||
      animation.status == AnimationStatus.dismissed;

  /// The spec's fades are SHORTER than the transforms they ride
  /// with (§6.1: Slide fades 220/180 within 320, Push 120/340,
  /// Depth 160/200 within 300, Elastic 180 in / 160 out, Curtain
  /// 200/260 within 360): the fade completes early and the
  /// transform finishes alone. Maps the shared progress onto the
  /// fade's own window (DeepSeek's round-3 draft formulation).
  static double _fade(
    double v, {
    required bool exiting,
    required double total,
    required double fadeIn,
    required double fadeOut,
  }) {
    if (exiting) {
      final f = fadeOut / total;
      return ((v - (1 - f)) / f).clamp(0.0, 1.0);
    }
    return (v / (fadeIn / total)).clamp(0.0, 1.0);
  }

  /// Wraps a page change. [direction] is the sign of (new index − old
  /// index) in tab order, already flipped for RTL by the caller:
  /// horizontal transitions enter from the side the destination sits
  /// on; scale/vertical styles are direction-neutral.
  static Widget transition({
    required ZedTransitionStyle style,
    required bool reduceMotion,
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
    required Widget child,
    double direction = 1,
  }) {
    if (reduceMotion) {
      return FadeTransition(opacity: animation, child: child);
    }
    switch (style) {
      case ZedTransitionStyle.fade:
        return FadeTransition(opacity: animation, child: child);
      case ZedTransitionStyle.slide:
        // Spec (§6.1): enter slides from sign × width/3, exit slides
        // to −sign × width/3 — opposite directions, so the offset is
        // chosen by the page's role, not by reversing one tween
        // (round 3: the exit used to slide back out the way it came).
        return AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) {
            final v = animation.value;
            final dx = _exiting(animation)
                ? -direction * (1 - v) / 3
                : direction * (1 - v) / 3;
            return FractionalTranslation(
              translation: Offset(dx, 0),
              child: Opacity(
                opacity: _fade(
                  v,
                  exiting: _exiting(animation),
                  total: 320,
                  fadeIn: 220,
                  fadeOut: 180,
                ),
                child: child,
              ),
            );
          },
        );
      case ZedTransitionStyle.push:
        // Spec (§6.1): the asymmetric Push pair — enter from the
        // FULL width, exit to a THIRD of the width on the opposite
        // side. Chosen by role like Slide (round 3).
        return AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) {
            final v = animation.value;
            final dx = _exiting(animation)
                ? -direction * (1 - v) / 3
                : direction * (1 - v);
            return FractionalTranslation(
              translation: Offset(dx, 0),
              child: Opacity(
                opacity: _fade(
                  v,
                  exiting: _exiting(animation),
                  total: 340,
                  fadeIn: 120,
                  fadeOut: 340,
                ),
                child: child,
              ),
            );
          },
        );
      case ZedTransitionStyle.depth:
        // Spec (§6.1): forward, enter scales 0.88 → 1 and the exit
        // grows to 1.12; back, the pair swaps (enter from 1.12, exit
        // to 0.88). The switcher runs this same builder in reverse
        // for the outgoing page, so the tween is chosen by the
        // animation's direction (round-2 finding M3: the exit used
        // to shrink back to 0.88; round 3: the back pair was the
        // forward pair).
        return AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) {
            final v = animation.value;
            final forward = direction > 0;
            final scale = _exiting(animation)
                ? (forward ? 1 + (1 - v) * 0.12 : 1 - (1 - v) * 0.12)
                : (forward ? 0.88 + v * 0.12 : 1.12 - v * 0.12);
            return Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: _fade(
                  v,
                  exiting: _exiting(animation),
                  total: 300,
                  fadeIn: 160,
                  fadeOut: 200,
                ),
                child: child,
              ),
            );
          },
        );
      case ZedTransitionStyle.elastic:
        // Spec (§6.1): enter slides from height/8 and scales from
        // 0.9 on a bouncy spring, with a plain fade. The fade must
        // ride the RAW progress: an overshooting curve on opacity
        // exceeds 1.0 mid-flight and asserts in debug builds
        // (round-2 finding M1 — the old code also scaled from 0).
        // The EXIT is its own transform — scale to 0.96, no slide —
        // not the enter reversed (round 3; the exit's 220 ms lives
        // in reverseDuration).
        return AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) {
            if (_exiting(animation)) {
              final v = animation.value;
              return Transform.scale(
                scale: 1 - (1 - v) * 0.04,
                child: Opacity(
                  opacity: _fade(
                    v,
                    exiting: true,
                    total: 220,
                    fadeIn: 180,
                    fadeOut: 160,
                  ),
                  child: child,
                ),
              );
            }
            final spring = CurvedAnimation(
              parent: animation,
              curve: Curves.elasticOut,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.125),
                end: Offset.zero,
              ).animate(spring),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.9, end: 1).animate(spring),
                child: Opacity(
                  opacity: _fade(
                    animation.value,
                    exiting: false,
                    total: 450,
                    fadeIn: 180,
                    fadeOut: 160,
                  ),
                  child: child,
                ),
              ),
            );
          },
        );
      case ZedTransitionStyle.curtain:
        // Spec (§6.1): forward, the new page slides up from
        // height/2 while the old one scales to 0.94; back, the new
        // page scales in from 0.94 while the old one slides away to
        // height/2. Each page gets its own half of the pair, chosen
        // by role and direction (round 3: both pages used to slide
        // and scale together).
        return AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) {
            final v = animation.value;
            final forward = direction > 0;
            final slides = _exiting(animation) ? !forward : forward;
            final opacity = _fade(
              v,
              exiting: _exiting(animation),
              total: 360,
              fadeIn: 200,
              fadeOut: 260,
            );
            if (slides) {
              return FractionalTranslation(
                translation: Offset(0, (1 - v) * 0.5),
                child: Opacity(opacity: opacity, child: child),
              );
            }
            return Transform.scale(
              scale: 0.94 + v * 0.06,
              child: Opacity(opacity: opacity, child: child),
            );
          },
        );
      case ZedTransitionStyle.flip:
        return AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) {
            final t = animation.value;
            // Spec (§6.1 + transitionDecoration): the entering page
            // turns from +78° × sign to 0; the LEAVING page turns to
            // −78° × sign (PostExit), not back the way it came
            // (round 3).
            final angle =
                (_exiting(animation) ? -1 : 1) *
                (1 - t) *
                math.pi *
                (78 / 180) *
                direction;
            // Spec (§6.1): the pivot sits near the leading edge
            // (transformOrigin 0.15 / 0.85 by sign) and the page
            // fades as it turns, alpha = 1 − |angle| / 110
            // (round-2 finding M2: centre pivot, fully opaque).
            final alpha = (1 - angle.abs() * 180 / math.pi / 110).clamp(
              0.0,
              1.0,
            );
            return Opacity(
              opacity: alpha,
              child: Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0018)
                  ..rotateY(angle),
                alignment: Alignment(direction > 0 ? -0.7 : 0.7, 0),
                child: child,
              ),
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
      // Spec (§6.1): Depth's scale tween is 300 ms, Curtain's is
      // 360 ms — both were 340 in the port (round-2 finding M3).
      ZedTransitionStyle.depth => const Duration(milliseconds: 300),
      ZedTransitionStyle.elastic => const Duration(milliseconds: 450),
      ZedTransitionStyle.curtain => const Duration(milliseconds: 360),
      ZedTransitionStyle.flip => const Duration(milliseconds: 360),
    };
  }

  static Duration reverseDuration(ZedTransitionStyle style, bool reduceMotion) {
    if (reduceMotion) return const Duration(milliseconds: 90);
    return switch (style) {
      ZedTransitionStyle.fade => const Duration(milliseconds: 180),
      // Spec (§6.1): Elastic's exit is a 220 ms tween (its fade is
      // 160 ms, riding the same progress) — the enter's spring
      // window does not apply to the way out.
      ZedTransitionStyle.elastic => const Duration(milliseconds: 220),
      _ => duration(style, reduceMotion),
    };
  }

  static Curve curve(ZedTransitionStyle style) => switch (style) {
    // Every spec tween without an explicit easing uses Compose's
    // default FastOutSlowInEasing (§6.1) — the port ran the styles
    // on easeInOutCubic / easeOutCubic (round 3, finding M-7).
    // Elastic keeps a non-overshooting curve at the switcher level:
    // it drives the fade (the elastic branch of transition() puts
    // the spring curve on scale/slide only).
    ZedTransitionStyle.elastic => Curves.easeOut,
    _ => Curves.fastOutSlowIn,
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
    this.direction = 1,
  });

  final ZedPrefs prefs;
  final bool reduceMotion;

  /// The sign of the tab-order delta for this change (already flipped
  /// for RTL by the shell): horizontal transitions enter from the
  /// destination's side.
  final double direction;

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
    // Reduced motion is a plain fade: an overshooting curve (Elastic)
    // must not drive it, or the fade flashes instead of fading.
    switchInCurve: reduceMotion
        ? Curves.easeOut
        : ZedMotion.curve(prefs.transitionStyle),
    // The spec's exit tweens ride the same FastOutSlowIn default;
    // the port hardcoded easeIn for every style (finding M-7).
    switchOutCurve: reduceMotion
        ? Curves.easeIn
        : ZedMotion.curve(prefs.transitionStyle),
    transitionBuilder: (child, animation) => ZedMotion.transition(
      style: prefs.transitionStyle,
      reduceMotion: reduceMotion,
      animation: animation,
      secondaryAnimation: const AlwaysStoppedAnimation(0),
      direction: direction,
      child: child,
    ),
    child: child,
  );
}

/// The one entrance stagger in the design system (server list, §25):
/// an 800 ms window, each row delayed min(index, 12) × 45 ms, rising
/// 26 dp with alpha and a 0.96→1 scale on a spring-like curve.
class ZedEntrance extends StatefulWidget {
  const ZedEntrance({
    super.key,
    required this.index,
    required this.child,
    this.reduceMotion = false,
  });

  final int index;
  final Widget child;

  /// The caller's reduced-motion verdict (the app's animations
  /// setting OR-ed with the platform's, the same value the shells
  /// hand the page switcher). The platform flag alone is also read
  /// directly in [State.didChangeDependencies], so a caller that
  /// passes nothing still honours the OS setting.
  final bool reduceMotion;

  @override
  State<ZedEntrance> createState() => _ZedEntranceState();
}

class _ZedEntranceState extends State<ZedEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  bool _reduced = false;
  bool _started = false;
  Timer? _startTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = widget.reduceMotion || MediaQuery.disableAnimationsOf(context);
    if (_reduced) {
      // Reduced motion: render the end state and never schedule the
      // staggered start at all (a pending start timer outliving the
      // row was real, if benign, lifecycle debt — round-2 D4 test).
      _startTimer?.cancel();
      _c.value = 1;
      return;
    }
    if (_started) return;
    _started = true;
    final delay = Duration(milliseconds: math.min(widget.index, 12) * 45);
    if (delay == Duration.zero) {
      _c.forward();
    } else {
      _startTimer = Timer(delay, () {
        if (mounted && !_reduced) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduced) return widget.child;
    return AnimatedBuilder(
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
}
