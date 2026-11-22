import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:material_ui/material_ui.dart';

import 'zed_prefs.dart';

/// The motion system, reimplemented from `ui/motion/ScreenTransitions.kt`
/// (see ZED-TOKENS-EXTRACT §6). Compose springs are converted to
/// Flutter physics springs — `SpringDescription(mass: 1, stiffness: k,
/// damping: 2·ζ·√k)` — and run as [SpringSimulation]s, never as
/// look-alike easing curves.

/// Compose's default tween easing (FastOutSlowInEasing).
const zedFastOutSlowIn = Cubic(0.4, 0.0, 0.2, 1.0);

SpringDescription composeSpring(double dampingRatio, double stiffness) =>
    SpringDescription(
      mass: 1,
      stiffness: stiffness,
      damping: 2 * dampingRatio * math.sqrt(stiffness),
    );

/// Frequently used source springs.
final springMediumBouncyLow = composeSpring(0.5, 200); // Elastic
final springEntrance = composeSpring(0.62, 380); // server-list stagger
final springMediumLow = composeSpring(1.0, 400);
final springPlatter = composeSpring(0.72, 400); // glass platter / thumb
final springKnob = composeSpring(0.62, 400); // glass switch knob
final springPressGlass = composeSpring(0.5, 1500); // glass press 1.07
final springPressCard = composeSpring(0.62, 1500); // bento card press
final springDockHold = composeSpring(0.55, 1500); // dock item hold 1.03

/// Whether motion must collapse: the in-app pref OR the platform's
/// reduce-motion setting.
bool zedReduceMotion(BuildContext context, ZedPrefs prefs) =>
    prefs.reduceMotion || MediaQuery.disableAnimationsOf(context);

class _Entry {
  _Entry(this.key, this.child, this.entering, this.forward);
  final Key key;
  final Widget child;
  final bool entering;

  /// The navigation direction this entry belongs to. An exit
  /// already on screen keeps its direction even if the user
  /// reverses direction again; an exit created FOR a navigation
  /// takes that navigation's direction (the current widget.forward
  /// at creation time), matching how the source picks the exit
  /// spec from the navigation's (initial, target) pair.
  final bool forward;
  late final AnimationController controller;
}

/// A page-transition stack in the spirit of MainScaffold's
/// AnimatedContent: the outgoing page runs its exit transform while
/// the incoming page runs its enter transform, each with its own
/// duration (or spring), unclipped (`SizeTransform(clip = false)`).
class ZedPageTransition extends StatefulWidget {
  const ZedPageTransition({
    super.key,
    required this.child,
    required this.style,
    required this.forward,
    required this.reduceMotion,
  });

  /// The current page; must carry a stable [ValueKey].
  final Widget child;
  final ZedTransition style;
  final bool forward;
  final bool reduceMotion;

  @override
  State<ZedPageTransition> createState() => _ZedPageTransitionState();
}

class _ZedPageTransitionState extends State<ZedPageTransition>
    with TickerProviderStateMixin {
  final List<_Entry> _entries = [];

  @override
  void initState() {
    super.initState();
    _add(widget.child, entering: true, first: true);
  }

  void _add(Widget child, {required bool entering, bool first = false}) {
    final entry = _Entry(child.key!, child, entering, widget.forward);
    final spec = _specFor(widget.style, entering, widget.reduceMotion);
    // Spring-driven entries need an unbounded controller: a bounded
    // one clamps the simulation at 1.0 and the overshoot (the whole
    // point of the spring) never renders.
    entry.controller = spec.spring != null && entering
        ? AnimationController.unbounded(vsync: this)
        : AnimationController(vsync: this);
    _entries.add(entry);
    if (first) {
      entry.controller.value = 1;
      return;
    }
    if (spec.spring != null && entering) {
      entry.controller
          .animateWith(SpringSimulation(spec.spring!, 0, 1, 0))
          .whenComplete(() => _cleanup(entry));
    } else {
      entry.controller.duration = spec.duration;
      entry.controller.forward().whenComplete(() => _cleanup(entry));
    }
  }

  void _cleanup(_Entry entry) {
    if (!mounted) return;
    setState(() {
      _entries.removeWhere((e) {
        if (!e.entering && e.controller.isCompleted) {
          e.controller.dispose();
          return true;
        }
        return false;
      });
    });
  }

  @override
  void didUpdateWidget(ZedPageTransition old) {
    super.didUpdateWidget(old);
    final newKey = widget.child.key;
    if (_entries.isEmpty || _entries.last.key != newKey) {
      // A page whose exit is still running and is being returned
      // to: cancel the stale exit, or the stack would hold two
      // entries (and two sibling keys) for the same page.
      _entries.removeWhere((e) {
        if (e.key == newKey && !e.entering) {
          e.controller.dispose();
          return true;
        }
        return false;
      });
      // Current top becomes an exit.
      if (_entries.isNotEmpty) {
        final top = _entries.last;
        final exit = _Entry(top.key, top.child, false, widget.forward);
        exit.controller = AnimationController(vsync: this);
        top.controller.dispose();
        _entries[_entries.length - 1] = exit;
        final spec = _specFor(widget.style, false, widget.reduceMotion);
        exit.controller.duration = spec.duration;
        exit.controller.forward().whenComplete(() => _cleanup(exit));
      }
      _add(widget.child, entering: true);
    } else {
      final old = _entries.last;
      _entries[_entries.length - 1] = _Entry(
        newKey!,
        widget.child,
        true,
        old.forward,
      )..controller = old.controller;
    }
  }

  @override
  void dispose() {
    for (final e in _entries) {
      e.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final layoutSign = rtl ? -1 : 1;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final e in _entries)
          Positioned.fill(
            key: ValueKey(e.key),
            child: AnimatedBuilder(
              animation: e.controller,
              builder: (context, child) => _transform(
                context,
                e.controller.value,
                e.entering,
                (e.forward ? 1 : -1) * layoutSign,
                e.forward,
                child!,
                elapsed: e.controller.lastElapsedDuration ?? Duration.zero,
              ),
              child: e.child,
            ),
          ),
      ],
    );
  }

  Widget _transform(
    BuildContext context,
    double rawT,
    bool entering,
    int sign,
    bool forward,
    Widget child, {
    Duration elapsed = Duration.zero,
  }) {
    if (widget.reduceMotion) {
      return Opacity(
        opacity: (entering ? rawT : 1 - rawT).clamp(0.0, 1.0),
        child: child,
      );
    }
    // Only the elastic entrance consumes t raw (its dy/scale are
    // linear in the spring value, overshoot included). Every other
    // branch feeds t to easing curves, which assert outside [0, 1].
    final t = entering && widget.style == ZedTransition.elastic
        ? rawT
        : rawT.clamp(0.0, 1.0);
    final size = MediaQuery.sizeOf(context);
    // Sub-window fade: opacity runs on its own duration inside the
    // controller's total duration.
    double fade(double durMs, double totalMs) =>
        (t * totalMs / durMs).clamp(0.0, 1.0);
    switch (widget.style) {
      case ZedTransition.fade:
        return Opacity(
          opacity: entering ? fade(260, 260) : 1 - fade(180, 180),
          child: child,
        );
      case ZedTransition.slide:
        final dx = entering
            ? sign * size.width / 3 * (1 - zedFastOutSlowIn.transform(t))
            : -sign * size.width / 3 * zedFastOutSlowIn.transform(t);
        return Transform.translate(
          offset: Offset(dx, 0),
          child: Opacity(
            opacity: entering ? fade(220, 320) : 1 - fade(180, 320),
            child: child,
          ),
        );
      case ZedTransition.push:
        final dx = entering
            ? sign * size.width * (1 - zedFastOutSlowIn.transform(t))
            : -sign * size.width / 3 * zedFastOutSlowIn.transform(t);
        return Transform.translate(
          offset: Offset(dx, 0),
          child: Opacity(
            opacity: entering ? fade(120, 340) : 1 - t,
            child: child,
          ),
        );
      case ZedTransition.depth:
        final (from, to) = forward ? (0.88, 1.12) : (1.12, 0.88);
        final scale = entering
            ? from + (1 - from) * zedFastOutSlowIn.transform(t)
            : 1 + (to - 1) * zedFastOutSlowIn.transform(t);
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: entering ? fade(220, 300) : 1 - fade(180, 300),
            child: child,
          ),
        );
      case ZedTransition.elastic:
        if (entering) {
          // t is the spring simulation's value (may overshoot).
          // The fade is a separate 180 ms tween in the source, so
          // it runs on elapsed time — feeding it the spring value
          // saturated it within the first frames.
          final dy = size.height / 8 * (1 - t);
          final scale = 0.9 + 0.1 * t;
          return Transform.translate(
            offset: Offset(0, dy),
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: (elapsed.inMilliseconds / 180).clamp(0.0, 1.0),
                child: child,
              ),
            ),
          );
        }
        final scale = 1 - 0.04 * zedFastOutSlowIn.transform(t);
        return Transform.scale(
          scale: scale,
          child: Opacity(opacity: 1 - fade(160, 220), child: child),
        );
      case ZedTransition.curtain:
        if (forward) {
          if (entering) {
            final dy = size.height / 2 * (1 - zedFastOutSlowIn.transform(t));
            return Transform.translate(
              offset: Offset(0, dy),
              child: Opacity(opacity: fade(200, 360), child: child),
            );
          }
          final scale = 1 - 0.06 * zedFastOutSlowIn.transform(t);
          return Transform.scale(
            scale: scale,
            child: Opacity(opacity: 1 - fade(260, 360), child: child),
          );
        }
        if (entering) {
          final scale = 0.94 + 0.06 * zedFastOutSlowIn.transform(t);
          return Transform.scale(
            scale: scale,
            child: Opacity(opacity: fade(200, 360), child: child),
          );
        }
        final dy = size.height / 2 * zedFastOutSlowIn.transform(t);
        return Transform.translate(
          offset: Offset(0, dy),
          child: Opacity(opacity: 1 - fade(260, 360), child: child),
        );
      case ZedTransition.flip:
        // The ContentTransform is only a delayed fade; the 3D part is
        // this decoration, applied to both pages (ScreenTransitions.kt).
        final angleDeg = entering ? 78.0 * sign * (1 - t) : -78.0 * sign * t;
        final alpha = 1 - angleDeg.abs() / 110;
        final opacity = entering
            ? ((t * 360 - 90) / 220).clamp(0.0, 1.0)
            : 1 - fade(160, 360);
        return Opacity(
          opacity: opacity * alpha.clamp(0.0, 1.0),
          child: Transform(
            alignment: Alignment(sign > 0 ? -0.7 : 0.7, 0),
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0018)
              ..rotateY(angleDeg * math.pi / 180),
            child: child,
          ),
        );
    }
  }
}

({Duration duration, SpringDescription? spring}) _specFor(
  ZedTransition style,
  bool entering,
  bool reduceMotion,
) {
  if (reduceMotion) {
    return (
      duration: Duration(milliseconds: entering ? 120 : 90),
      spring: null,
    );
  }
  return switch (style) {
    ZedTransition.fade => (
      duration: Duration(milliseconds: entering ? 260 : 180),
      spring: null,
    ),
    ZedTransition.slide => (
      duration: const Duration(milliseconds: 320),
      spring: null,
    ),
    ZedTransition.push => (
      duration: const Duration(milliseconds: 340),
      spring: null,
    ),
    ZedTransition.depth => (
      duration: const Duration(milliseconds: 300),
      spring: null,
    ),
    ZedTransition.elastic =>
      entering
          ? (
              duration: const Duration(milliseconds: 1000),
              spring: springMediumBouncyLow,
            )
          : (duration: const Duration(milliseconds: 220), spring: null),
    ZedTransition.curtain => (
      duration: const Duration(milliseconds: 360),
      spring: null,
    ),
    ZedTransition.flip => (
      duration: const Duration(milliseconds: 360),
      spring: null,
    ),
  };
}

/// The server-list entrance (`springEntrance` in ServersScreen):
/// active only within an 800 ms window from the list's first build,
/// delay min(index,12)×45 ms, spring (0.62, 380) driving alpha +
/// 26 dp rise + scale 0.96→1. Only for Pixel/Bento/Glass designs;
/// still under reduced motion.
class ZedEntrance extends StatefulWidget {
  const ZedEntrance({
    super.key,
    required this.index,
    required this.enabled,
    required this.child,
  });

  final int index;
  final bool enabled;
  final Widget child;

  /// The shared window anchor: set by the first entrance of a mount
  /// group. A group is delimited by mounted-ness: while any entrance
  /// of the group is still mounted, later mounts (lazy rows built
  /// during a scroll) share the anchor and do NOT restart it; when
  /// nothing is mounted, the next mount is a new screen and starts
  /// a fresh window.
  static DateTime? windowStart;

  /// Entrances currently mounted across the app.
  static int mountedCount = 0;

  /// When the most recent entrance mounted (kept for tests/debug).
  static DateTime? lastEntranceInit;

  /// Test hook: forget the window.
  static void resetWindow() {
    windowStart = null;
    lastEntranceInit = null;
  }

  @override
  State<ZedEntrance> createState() => _ZedEntranceState();
}

class _ZedEntranceState extends State<ZedEntrance>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Timer? _timer;
  bool _animate = false;

  @override
  void initState() {
    super.initState();
    // The mount group is delimited by mounted-ness: every mounted
    // entrance holds it open, enabled or not.
    if (ZedEntrance.mountedCount == 0) {
      ZedEntrance.windowStart = DateTime.now();
    }
    ZedEntrance.mountedCount++;
    if (widget.enabled) _start();
  }

  @override
  void didUpdateWidget(ZedEntrance old) {
    super.didUpdateWidget(old);
    if (widget.enabled == old.enabled) return;
    if (widget.enabled) {
      _start();
    } else {
      _stop();
    }
  }

  void _start() {
    final now = DateTime.now();
    ZedEntrance.lastEntranceInit = now;
    final start = ZedEntrance.windowStart ??= now;
    if (now.difference(start) > const Duration(milliseconds: 800)) {
      return; // Outside the window: render unanimated.
    }
    _animate = true;
    _controller = AnimationController.unbounded(vsync: this);
    final delay = Duration(
      milliseconds: (widget.index < 12 ? widget.index : 12) * 45,
    );
    _timer = Timer(delay, () {
      if (!mounted) return;
      _controller!.animateWith(SpringSimulation(springEntrance, 0, 1, 0));
    });
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _controller?.dispose();
    _controller = null;
    _animate = false;
  }

  @override
  void dispose() {
    ZedEntrance.mountedCount--;
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_animate) return widget.child;
    return AnimatedBuilder(
      animation: _controller!,
      builder: (context, child) {
        final t = _controller!.value;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 26 * (1 - t)),
            child: Transform.scale(scale: 0.96 + 0.04 * t, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Press feedback as a physics spring toward [pressedScale] while
/// pressed (Bento card 0.965/0.985, Glass 1.07, …). Uses a Listener so
/// it never enters the gesture arena — it cannot eat the child's own
/// taps, drags or long-presses.
class ZedPressScale extends StatefulWidget {
  const ZedPressScale({
    super.key,
    required this.child,
    required this.pressedScale,
    required this.spring,
    this.enabled = true,
  });

  final Widget child;
  final double pressedScale;
  final SpringDescription spring;
  final bool enabled;

  @override
  State<ZedPressScale> createState() => _ZedPressScaleState();
}

class _ZedPressScaleState extends State<ZedPressScale>
    with SingleTickerProviderStateMixin {
  int _pointers = 0;

  // Unbounded: the Glass press target is 1.07 — a bounded controller
  // clamps the spring at 1.0 and the press never renders.
  late final AnimationController _controller = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  void _to(double target) {
    // Returning to rest is always allowed: if the widget is
    // disabled mid-press, the release must still spring back or
    // the child stays scaled forever.
    if (!widget.enabled && target != 1) return;
    _controller.animateWith(
      SpringSimulation(widget.spring, _controller.value, target, 0),
    );
  }

  @override
  void didUpdateWidget(ZedPressScale old) {
    super.didUpdateWidget(old);
    if (!widget.enabled &&
        (_controller.value != 1 || _controller.isAnimating)) {
      _to(1);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _release() {
    if (_pointers > 0) _pointers--;
    if (_pointers == 0) _to(1);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) {
      _pointers++;
      _to(widget.pressedScale);
    },
    onPointerUp: (_) => _release(),
    onPointerCancel: (_) => _release(),
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, child) =>
          Transform.scale(scale: _controller.value, child: child),
      child: widget.child,
    ),
  );
}
