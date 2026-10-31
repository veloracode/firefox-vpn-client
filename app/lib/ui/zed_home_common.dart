import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';

import '../core/core_controller.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';
import 'connection_mode.dart';
import 'format.dart';
import 'signin_dialog.dart';
import 'widgets.dart';

/// Shared pieces of the three phone designs (Pixel, Portal, Old) ported
/// from FoxyVPN's Android app: the state they all read, the morphing
/// connect core at their center, and the rows they share (server,
/// accounts, speeds, error). The designs' own files only arrange these.
/// Nothing here decides anything about the VPN itself: every action is
/// the core's, through the same controller calls the other homes make.

/// The connection state in the phone designs' terms, derived exactly
/// as every other home derives it (the shared helpers in widgets.dart):
/// on from the engine's phase, connected only once a connection test
/// has confirmed the running engine — until then the designs show
/// Connecting, like the classic desktop home, instead of claiming a
/// connection the test has not confirmed yet.
class ZedHomeData {
  ZedHomeData(this.core, this.status, this.l, {this.animationsEnabled = true});

  final CoreController core;
  final CoreStatus status;
  final AppLocalizations l;

  /// The user's Home animations setting, for the connect core.
  final bool animationsEnabled;

  bool get canSwitch => status.systemProxySupported;

  /// On: the proxy's power, the engine's phase — the shared [engineOn],
  /// as on the classic desktop home. (The phone home's switch reads the
  /// system-proxy mode instead; on a computer that made these designs
  /// report "on" while the engine was off, and vice versa.)
  bool get on => engineOn(status);

  bool get running => status.state.phase == Phase.running;

  /// Connected: the shared [connectionLive] — the engine runs and a
  /// test since it started passed.
  bool get live => connectionLive(status, core.lastTest);

  /// Connecting: starting, running but not yet confirmed by a test, on
  /// but held up (waiting for a network or an account), or the switch
  /// itself is being changed.
  bool get busy =>
      !live &&
      (status.state.phase == Phase.starting ||
          status.state.phase == Phase.running ||
          status.state.phase == Phase.waiting ||
          core.switchingProxy);

  PhaseLook get look => PhaseLook.of(l, status);

  HomePlace get place => homeLocation(l, status, connected: live);

  int get total => status.totalAccounts;

  int get ready => status.readyAccounts;

  /// The ping the phone designs show: the same number the classic
  /// desktop home shows — the controller's latest test and its
  /// response time, the leg of the test that runs through the
  /// standing tunnel (request to first byte). These designs once read
  /// the core status's test total instead (tunnel setup, TLS and
  /// response together), which reads about three times the desktop
  /// home's number for one and the same test.
  int? get pingMs {
    final t = core.lastTest;
    return t != null && t.ok ? t.responseMs : null;
  }

  bool get hasError => status.state.phase == Phase.error;

  String get errorText =>
      look.hint.isNotEmpty ? look.hint : status.state.message;

  /// When the running phase began: the connected session's start.
  DateTime? get since => live ? status.state.since : null;

  List<Account> get accounts => core.accounts?.accounts ?? const [];

  /// The server row's second line: the exit city while connected, else
  /// the invitation to choose. Mozilla's locations name no host to show.
  String get locationDetail {
    final p = status.proxy;
    if (live && p != null && p.cityName.isNotEmpty) return p.cityName;
    return l.zedTapToChooseLocation;
  }

  /// Where a design's connect button goes with no accounts yet: the
  /// accounts page, as the Foxy home does.
  void openAccounts(BuildContext context, VoidCallback? callback) {
    if (callback != null) {
      callback();
    } else {
      showSignInDialog(context, core);
    }
  }

  /// The connect button pressed: the one power behavior every home
  /// shares ([homePowerPressed]) — the power, never the connection
  /// mode. The core starts or stops the proxy and applies the chosen
  /// mode (system proxy or TUN) itself. (These designs once copied the
  /// phone home's switch, which flips the system-proxy mode where one
  /// exists: on Windows the tap only changed the mode and the engine
  /// never started, so nothing ever connected.)
  void toggle(BuildContext context, VoidCallback? onOpenAccounts) {
    homePowerPressed(
      context,
      core,
      onNoAccounts: () => openAccounts(context, onOpenAccounts),
    );
  }
}

/// The phone designs' elapsed time: hours when there are any, else
/// minutes, both padded (`1:02:03`, `04:05`).
String formatZedElapsed(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final ss = s % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(ss)}' : '${two(m)}:${two(ss)}';
}

/// The elapsed time since [since], ticking each second on its own, as
/// the Portal and Old designs show it under the title. Nothing when
/// there is no session start to count from.
class ZedElapsedText extends StatefulWidget {
  const ZedElapsedText({
    super.key,
    required this.since,
    this.style,
    this.color,
    this.prefix = '',
  });

  final DateTime? since;
  final TextStyle? style;
  final Color? color;
  final String prefix;

  @override
  State<ZedElapsedText> createState() => _ZedElapsedTextState();
}

class _ZedElapsedTextState extends State<ZedElapsedText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final since = widget.since;
    if (since == null) return const SizedBox.shrink();
    return Text(
      '${widget.prefix}${formatZedElapsed(DateTime.now().difference(since))}',
      style: (widget.style ?? const TextStyle()).copyWith(
        color: widget.color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

// ─── The connect core ─────────────────────────────────────────────────────

/// A door shape as the phone's core draws it: a rounded polygon read as a
/// radius around the circle, deepest at [depth] over [lobes] waves.
class _DoorShape {
  const _DoorShape(this.lobes, this.depth);

  final int lobes;
  final double depth;

  double radius(double theta) => 1 - depth + depth * math.cos(lobes * theta);
}

/// Idle: the twelve-sided cookie. Connected: the soft burst.
const _cookie12 = _DoorShape(12, 0.055);
const _softBurst = _DoorShape(12, 0.15);

/// The shapes the core cycles through while connecting, one every
/// 0.72 s, in the phone's order.
const _searchShapes = <_DoorShape>[
  _softBurst,
  _DoorShape(9, 0.09),
  _DoorShape(5, 0.16),
  _DoorShape(2, 0.12),
  _DoorShape(16, 0.13),
  _DoorShape(4, 0.15),
  _DoorShape(1, 0.06),
];

const _samples = 180;

/// The shapes' radii, computed once each and kept: a shape never
/// changes, so its 180 radii are built the first time it is drawn.
/// (The door once rebuilt a fresh list on every widget build.)
final _radiiCache = <_DoorShape, List<double>>{};

List<double> _radiiOf(_DoorShape shape) => _radiiCache.putIfAbsent(
  shape,
  () => List<double>.generate(
    _samples,
    (i) => shape.radius(i / _samples * 2 * math.pi),
  ),
);

/// The phone's connect core: a morphing gradient door. Idle it rests as
/// a cookie polygon; connecting, it cycles shapes every 0.72 s under a
/// sweep gradient, turning fast; connected, it settles into the soft
/// burst and stands still, showing the session's elapsed time where
/// the power sign was. A burst of bits celebrates a fresh connection.
/// All of the motion is the user's Home animations setting, off by
/// default: a door that kept moving repainted forever and kept a CPU
/// core busy (the classic home's power button is still for the same
/// reason); the elapsed time ticks on its own one-second timer.
class ZedConnectCore extends StatefulWidget {
  const ZedConnectCore({
    super.key,
    required this.live,
    required this.busy,
    required this.onToggle,
    this.size = 208,
    this.since,
    this.animationsEnabled = true,
  });

  final bool live;
  final bool busy;
  final VoidCallback onToggle;

  /// The door's motion (the user's Home animations setting). On —
  /// the default — the full motion: the morph cycle and fast turn
  /// while connecting, the slow turn while connected. Off, the door
  /// stands still in every phase: no ticker runs, the shape is the
  /// phase's own, and only the elapsed time ticks, once a second.
  final bool animationsEnabled;

  /// The door's box; the Android door is the content width's 0.52,
  /// kept between 116 and 208.
  final double size;

  /// When the session began, for the center's elapsed time.
  final DateTime? since;

  @override
  State<ZedConnectCore> createState() => _ZedConnectCoreState();
}

/// The door's current picture, shared with its painter: the two shapes
/// it blends between (the shapes' cached radii lists), the blend the
/// morph spring has reached, and the rotation. The connect core's
/// state mutates this and bumps its frame listenable; the painter
/// reads it at paint time, so a frame of the door's motion repaints
/// the door without rebuilding the widget.
class _DoorFrame {
  List<double> from = _radiiOf(_cookie12);
  List<double> to = _radiiOf(_cookie12);
  double t = 1;
  double rotation = 0;
}

class _ZedConnectCoreState extends State<ZedConnectCore>
    with TickerProviderStateMixin {
  late final Ticker _ticker;
  late final AnimationController _morph;
  late final AnimationController _burst;
  final _DoorFrame _frameState = _DoorFrame();
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);
  double _seconds = 0;
  Duration _lastTick = Duration.zero;
  bool _pressed = false;
  bool _wasBusy = false;
  DateTime? _liveSince;
  _DoorShape _targetShape = _cookie12;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _morph = AnimationController.unbounded(vsync: this)..addListener(_onMorph);
    _burst = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..value = 1;
    _wasBusy = widget.busy;
    if (widget.live) _liveSince = DateTime.now();
    // A core created already connected (the app reopened onto a
    // standing connection) starts settled on its shape, not on the
    // cookie it would otherwise keep without a transition.
    _targetShape = _desiredShape;
    _frameState.from = _radiiOf(_targetShape);
    _frameState.to = _frameState.from;
    _syncClock();
  }

  @override
  void didUpdateWidget(ZedConnectCore old) {
    super.didUpdateWidget(old);
    if (widget.live && !old.live) {
      _liveSince = DateTime.now();
      if (_wasBusy && widget.animationsEnabled) _burst.forward(from: 0);
    }
    if (widget.busy) _wasBusy = true;
    if (!widget.live && !widget.busy) _wasBusy = false;
    _syncClock();
    _syncShape();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _morph.dispose();
    _burst.dispose();
    _frame.dispose();
    super.dispose();
  }

  /// The morph spring moves the blend and asks for a repaint — at the
  /// display's cadence, uncapped, but the repaint is now only the
  /// door's own layer redrawing (see _DoorFrame), not a rebuild of the
  /// widget. At rest the blend lands exactly on the target shape.
  void _onMorph() {
    final f = _frameState;
    if (_morph.status == AnimationStatus.completed) {
      f.from = f.to;
      f.t = 1;
    } else {
      f.t = _morph.value.clamp(-0.1, 1.1);
    }
    _frame.value++;
  }

  /// The clock runs only while the animation is on and the door has
  /// somewhere to go: connecting (the morph cycle, the fast turn) or
  /// connected (the slow turn). With the animation off no ticker runs
  /// at all, in any phase; the elapsed text keeps its own one-second
  /// timer either way.
  void _syncClock() {
    final active =
        widget.animationsEnabled && (widget.busy || widget.live);
    if (active && !_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    } else if (!active && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    final delta = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    _seconds += delta;
    _frameState.rotation +=
        delta * (widget.busy ? 150 : 9) * math.pi / 180;
    _syncShape();
    _frame.value++;
  }

  _DoorShape get _desiredShape {
    if (widget.live) return _softBurst;
    if (widget.busy && widget.animationsEnabled) {
      final step = (_seconds / 0.72).floor() % _searchShapes.length;
      return _searchShapes[step];
    }
    return _cookie12;
  }

  /// With the animation off, the door takes the phase's shape at
  /// once: no spring, no turn — and the morph stops wherever it was,
  /// so turning the setting off stills the door mid-motion too.
  void _snapToDesired() {
    final shape = _desiredShape;
    if (identical(shape, _targetShape) &&
        _frameState.t == 1 &&
        _frameState.rotation == 0) {
      return;
    }
    _morph.stop();
    _targetShape = shape;
    _frameState.from = _radiiOf(shape);
    _frameState.to = _frameState.from;
    _frameState.t = 1;
    _frameState.rotation = 0;
    _frame.value++;
  }

  void _syncShape() {
    if (!widget.animationsEnabled) {
      _snapToDesired();
      return;
    }
    final shape = _desiredShape;
    if (identical(shape, _targetShape)) return;
    _frameState.from = _blendedRadii();
    _targetShape = shape;
    _frameState.to = _radiiOf(shape);
    _frameState.t = 0;
    _morph
      ..stop()
      ..value = 0
      ..animateWith(
        SpringSimulation(
          const SpringDescription(mass: 1, stiffness: 260, damping: 19.4),
          0,
          1,
          0,
        ),
      );
  }

  /// The blend the door shows now, as its own list: the frame's two
  /// ends are the shapes' cached lists, which a new morph must not
  /// rewrite. Computed only when a morph starts, never per frame.
  List<double> _blendedRadii() {
    final f = _frameState;
    return List<double>.generate(
      _samples,
      (i) => f.from[i] + (f.to[i] - f.from[i]) * f.t,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final live = widget.live;
    final busy = widget.busy;
    final end = live || busy ? scheme.tertiary : scheme.primary;
    final since = widget.since ?? _liveSince;
    final size = widget.size;
    return GestureDetector(
      onTap: widget.onToggle,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1,
        duration: const Duration(milliseconds: 140),
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              RepaintBoundary(
                child: CustomPaint(
                  size: Size.square(size),
                  painter: _DoorPainter(
                    frame: _frameState,
                    sweep: busy,
                    start: scheme.primary,
                    end: end,
                    repaint: _frame,
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                reverseDuration: const Duration(milliseconds: 200),
                child: live
                    ? ZedElapsedText(
                        key: const ValueKey('elapsed'),
                        since: since,
                        style: TextStyle(
                          fontSize: size * 0.14,
                          fontWeight: FontWeight.w700,
                        ),
                        color: scheme.onPrimary,
                      )
                    : Icon(
                        Icons.power_settings_new_rounded,
                        key: const ValueKey('power'),
                        size: size * 0.32,
                        color: scheme.onPrimary,
                      ),
              ),
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _burst,
                  builder: (context, _) => CustomPaint(
                    painter: _BurstPainter(
                      progress: _burst.value,
                      colors: [
                        scheme.primary,
                        scheme.tertiary,
                        scheme.secondary,
                        scheme.tertiaryContainer,
                        scheme.secondaryContainer,
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
  }
}

class _DoorPainter extends CustomPainter {
  _DoorPainter({
    required this.frame,
    required this.sweep,
    required this.start,
    required this.end,
    super.repaint,
  });

  /// The blend and rotation to draw, mutated by the core's state and
  /// read at paint time; [repaint] says when to draw again.
  final _DoorFrame frame;
  final bool sweep;
  final Color start;
  final Color end;

  /// The gradient, built once per (size, colors, kind) and reused:
  /// creating a shader was half of what a door paint cost, and the
  /// picture it fills changes every frame while connecting. The
  /// rotation is a canvas transform applied to the whole drawing, so
  /// it never enters the shader.
  Shader? _shader;
  Size? _shaderSize;
  Color? _shaderStart;
  Color? _shaderEnd;
  bool? _shaderSweep;

  Shader _shaderFor(Size size) {
    final cached = _shader;
    if (cached != null &&
        _shaderSize == size &&
        _shaderStart == start &&
        _shaderEnd == end &&
        _shaderSweep == sweep) {
      return cached;
    }
    final r = size.shortestSide / 2;
    final shader = sweep
        ? SweepGradient(
            colors: [start, end, start],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: r))
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [start, end],
          ).createShader(Rect.fromLTWH(-r, -r, 2 * r, 2 * r));
    _shader = shader;
    _shaderSize = size;
    _shaderStart = start;
    _shaderEnd = end;
    _shaderSweep = sweep;
    return shader;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final f = frame;
    final from = f.from;
    final to = f.to;
    final t = f.t;
    final r = size.shortestSide / 2;
    final path = Path();
    for (var i = 0; i <= _samples; i++) {
      final theta = i / _samples * 2 * math.pi;
      final rad = (from[i % _samples] + (to[i % _samples] - from[i % _samples]) * t) * r;
      final p = Offset(math.cos(theta) * rad, math.sin(theta) * rad);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(f.rotation);
    canvas.drawPath(
      path,
      Paint()..shader = _shaderFor(size)..isAntiAlias = true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DoorPainter old) =>
      old.frame != frame ||
      old.sweep != sweep ||
      old.start != start ||
      old.end != end;
}

/// The celebration on a fresh connection: sixteen bits — circles and
/// rounded squares in the theme's colors — flying out and fading over
/// 950 ms. Draws nothing at rest.
class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.progress, required this.colors});

  final double progress;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress;
    if (p >= 1) return;
    final center = size.center(Offset.zero);
    final min = size.shortestSide;
    final bit = min * 5 / 208;
    final reach = min * 0.9;
    for (var i = 0; i < 16; i++) {
      final a = i * (2 * math.pi / 16) + 0.35;
      final d = min * 0.42 + reach * p;
      final pos = center + Offset(math.cos(a) * d, math.sin(a) * d);
      final color = colors[i % colors.length].withValues(
        alpha: (1 - p).clamp(0, 1),
      );
      final s = bit * (1 - p * 0.35);
      final paint = Paint()..color = color;
      if (i.isEven) {
        canvas.drawCircle(pos, s, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: pos, width: s * 2, height: s * 2),
            Radius.circular(s * 0.6),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.progress != progress;
}

// ─── Shared rows and cards ────────────────────────────────────────────────

/// The designs' page frame: the shell's page margin, the content a
/// centered column at most 560 wide — how ZedSecure's own desktop app
/// lays these same designs out in its wide window.
class ZedHomeScaffold extends StatelessWidget {
  const ZedHomeScaffold({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return ListView(
      padding: pagePadding(context) + EdgeInsets.only(top: top),
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

/// The connection mode section the designs share with every home: the
/// one selector (Proxy / System proxy / TUN, in that order), its hint,
/// and the TUN note. Nothing where this computer has proxy only.
class ZedModeSection extends StatelessWidget {
  const ZedModeSection({super.key, required this.data});

  final ZedHomeData data;

  @override
  Widget build(BuildContext context) {
    final status = data.status;
    if (!status.systemProxySupported && !status.tunSupported) {
      return const SizedBox.shrink();
    }
    final l = data.l;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ConnectionModeSelector(
            core: data.core,
            status: status,
            card: scheme.surfaceContainerHigh,
            cardBorder: scheme.outlineVariant,
            text: scheme.onSurface,
            muted: scheme.onSurfaceVariant,
            accent: scheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          connectionModeHint(
            l,
            status,
            installing: data.core.installingTun,
            windows: defaultTargetPlatform == TargetPlatform.windows,
          ),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        TunNote(
          core: data.core,
          box: (text, tooltip) => Tooltip(
            message: tooltip,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: StatusColors.busy.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: StatusColors.busy.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The designs' error card: the message centered on the error colors.
class ZedErrorCard extends StatelessWidget {
  const ZedErrorCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: scheme.onErrorContainer),
      ),
    );
  }
}

/// The server row: a primary badge with the flag, the location's name
/// and its detail; a tap opens the servers page.
class ZedServerRow extends StatelessWidget {
  const ZedServerRow({
    super.key,
    required this.data,
    required this.onTap,
  });

  final ZedHomeData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final place = data.place;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: place.flag.length == 2
                    ? CountryFlag(code: place.flag, width: 30)
                    : Icon(Icons.public_rounded, color: scheme.onPrimary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      data.locationDetail,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// The accounts row: a tertiary badge, the word and the summary, one dot
/// per account in its state color; a tap opens the accounts page.
class ZedAccountsRow extends StatelessWidget {
  const ZedAccountsRow({
    super.key,
    required this.data,
    required this.onTap,
  });

  final ZedHomeData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accounts = data.accounts;
    final enabled = accounts.where((a) => a.enabled).length;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.account_circle_rounded,
                  color: scheme.onTertiaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.navAccounts,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      accounts.isEmpty
                          ? l.zedAddFirstAccount
                          : l.zedAccountsSummary(
                              enabled,
                              data.live ? data.ready : 0,
                            ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final a in accounts.take(8))
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsetsDirectional.only(start: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: !a.enabled
                            ? scheme.outlineVariant
                            : data.live && a.status == AccountStatus.ready
                            ? StatusColors.good
                            : scheme.outline,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// The speeds row: download and upload tiles side by side, live rates
/// while connected and a dash otherwise.
class ZedSpeedRow extends StatelessWidget {
  const ZedSpeedRow({super.key, required this.data});

  final ZedHomeData data;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final traffic = data.status.traffic;
    Widget tile(IconData icon, String label, String value, Color badge, Color onBadge) =>
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: badge,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 18, color: onBadge),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      Text(
                        value,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
    return Row(
      children: [
        tile(
          Icons.download_rounded,
          l.zedDownload,
          data.live && traffic != null ? formatRate(traffic.downRate) : '—',
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
        ),
        const SizedBox(width: 6),
        tile(
          Icons.upload_rounded,
          l.zedUpload,
          data.live && traffic != null ? formatRate(traffic.upRate) : '—',
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
        ),
      ],
    );
  }
}
