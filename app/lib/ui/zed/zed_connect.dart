import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import 'zed_glass.dart';
import 'zed_prefs.dart';
import 'zed_theme.dart';

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
    this.hint = '',
    this.error = false,
    this.serverName,
    this.since,
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

  /// The short instruction the fuller controls show beside the state
  /// word (the slide's header hint, the tile's bottom line): the
  /// tap-to-connect / tap-to-disconnect phrase, the cancel word
  /// while busy, the retry word on error. Localized by the home.
  final String hint;

  /// The engine reported a failure (the Bento slide's dot and the
  /// Pixel controls' error container wear it).
  final bool error;

  /// The chosen place's name, for the controls whose second line
  /// names the server while idle.
  final String? serverName;

  /// When the live session began, for the controls that show the
  /// elapsed time as their big line.
  final DateTime? since;

  final VoidCallback onToggle;
}

/// A ticking session clock (HH:MM:SS, tabular figures) with its own
/// 1 s timer in its own State — the same scoping as the homes'
/// status-line timer, so a tick rebuilds this text alone.
class ZedElapsedText extends StatefulWidget {
  const ZedElapsedText({super.key, required this.since, this.style});

  final DateTime? since;
  final TextStyle? style;

  @override
  State<ZedElapsedText> createState() => _ZedElapsedTextState();
}

class _ZedElapsedTextState extends State<ZedElapsedText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(ZedElapsedText old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.since != null && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (widget.since == null) {
      _timer?.cancel();
      _timer = null;
    }
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
    final s = DateTime.now().difference(since).inSeconds.clamp(0, 1 << 31);
    String two(int v) => v.toString().padLeft(2, '0');
    final text = '${two(s ~/ 3600)}:${two((s % 3600) ~/ 60)}:${two(s % 60)}';
    return Text(
      text,
      style: (widget.style ?? const TextStyle()).copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

Color _stateColor(BuildContext context, ZedConnectState s) {
  final scheme = Theme.of(context).colorScheme;
  if (s.live) return scheme.primary;
  if (s.busy) return scheme.tertiary;
  return scheme.onSurfaceVariant;
}

/// The foreground that belongs ON [_stateColor]'s background for the
/// same state — pairing onPrimary with the busy (tertiary) or off
/// (onSurfaceVariant) backgrounds mismatches the colour roles and can
/// fail contrast (e.g. white on the Bento lime).
Color _onStateColor(BuildContext context, ZedConnectState s) {
  final scheme = Theme.of(context).colorScheme;
  if (s.live) return scheme.onPrimary;
  if (s.busy) return scheme.onTertiary;
  return scheme.onSurface;
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
    canvas.drawArc(Offset.zero & size, -1.5708, 4.5239, false, paint);
  }

  @override
  bool shouldRepaint(_BusyArcPainter old) => old.color != color;
}

Widget _busyMark(BuildContext context, ZedConnectState s, Color color) => s.busy
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
    // Every control may carry the tooltip: the drag-primary controls
    // (Slide/Slider) and the Hold track their pointers through a
    // Listener, OUTSIDE the gesture arena, so the Tooltip's
    // long-press recognizer can never cancel them (a press that
    // pauses before sliding used to lose the arena to the tooltip
    // and the drag silently died — round-2 regression, proven by
    // zed_tooltip_slide_test.dart). Tap-primary controls follow the
    // platform's accepted behaviour: press-and-hold shows the hint
    // instead of activating.
    return state.tooltip.isEmpty
        ? control
        : Tooltip(message: state.tooltip, child: control);
  }

  Widget _control(BuildContext context) => switch (prefs.design) {
    ZedDesign.bento => switch (prefs.bentoConnect) {
      BentoConnectStyle.slide => _SlideConnect(state: state, prefs: prefs),
      BentoConnectStyle.button => _BentoButtonConnect(
        state: state,
        prefs: prefs,
      ),
      BentoConnectStyle.morph => _MorphConnect(state: state, prefs: prefs),
      BentoConnectStyle.rail => _RailConnect(state: state, prefs: prefs),
      BentoConnectStyle.hold => _HoldConnect(state: state, prefs: prefs),
      BentoConnectStyle.tile => _TileConnect(state: state, prefs: prefs),
    },
    ZedDesign.pixel => _pixelControl(prefs.pixelConnect),
    ZedDesign.old => _pixelControl(prefs.oldConnect),
    ZedDesign.glass => switch (prefs.glassConnect) {
      GlassConnectStyle.z => _GlassZConnect(state: state, prefs: prefs),
      GlassConnectStyle.button => _GlassButtonConnect(
        state: state,
        prefs: prefs,
      ),
      GlassConnectStyle.switchStyle => _GlassCardConnect(
        state: state,
        prefs: prefs,
      ),
      GlassConnectStyle.slider => _GlassSlideConnect(
        state: state,
        prefs: prefs,
      ),
    },
  };

  Widget _pixelControl(PixelConnectStyle style) => switch (style) {
    PixelConnectStyle.pill => _ButtonConnect(state: state, big: false),
    PixelConnectStyle.hero => _HeroConnect(state: state),
    PixelConnectStyle.ring => _RingConnect(state: state),
    PixelConnectStyle.bar => _BarConnect(state: state),
    PixelConnectStyle.icon => _IconConnect(state: state),
    PixelConnectStyle.switchStyle => _PixelSwitchConnect(state: state),
  };
}

/// The Bento Slide (BentoConnectBar.kt) — the design's DEFAULT
/// connect control, reimplemented to the source in round 4 (rounds
/// 1–3 ran a generic 64 dp state-coloured bar): an 84 dp LIME block
/// (block radius), padding (14, 9, 14, 8); a header row — 9 dp
/// status dot, the state word at 15sp Bold, the hint at 12sp/75% —
/// over a 44 dp track carrying a sine WAVE the knob rides. The whole
/// track drags (Listener, outside the gesture arena, so the wrapping
/// Tooltip can never cancel a paused drag — the round-2 rule);
/// thresholds are the slide's own 0.72 / 0.28; a tap nudges the knob
/// (±0.14 and back) instead of toggling — except while busy, where a
/// tap is the cancel. Dragging is disabled while busy. While busy
/// the wave's untravelled part dashes (10/9 dp, 900 ms phase).
class _SlideConnect extends StatefulWidget {
  const _SlideConnect({required this.state, required this.prefs});

  final ZedConnectState state;
  final ZedPrefs prefs;

  @override
  State<_SlideConnect> createState() => _SlideConnectState();
}

class _SlideConnectState extends State<_SlideConnect>
    with TickerProviderStateMixin {
  /// The knob's displayed fraction. Drags set it directly; releases,
  /// nudges and state changes animate it (the source's settle spring
  /// (0.7, MediumLow), as the kit's ease curves).
  late final AnimationController _frac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: widget.state.on ? 1 : 0,
  );

  /// The busy wave's dash phase (900 ms linear loop); runs only
  /// while busy and motion is allowed.
  late final AnimationController _phase = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  bool _dragging = false;
  int? _pointer;
  double _downX = 0;
  double _lastBeyond = 0;
  DateTime? _downAt;
  bool _reduced = false;

  /// Invalidates an in-flight nudge chain when a newer gesture or
  /// state change supersedes it.
  int _gestureGen = 0;

  double get _rest => widget.state.on ? 1.0 : 0.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    _syncPhase();
  }

  @override
  void didUpdateWidget(_SlideConnect old) {
    super.didUpdateWidget(old);
    _syncPhase();
    if (old.state.on != widget.state.on && !_dragging) {
      _gestureGen++;
      if (_reduced) {
        _frac.value = _rest;
      } else {
        _frac.animateTo(_rest, curve: Curves.easeOut);
      }
    }
  }

  void _syncPhase() {
    if (widget.state.busy && !_reduced) {
      if (!_phase.isAnimating) _phase.repeat();
    } else if (_phase.isAnimating) {
      _phase.stop();
    }
  }

  @override
  void dispose() {
    _frac.dispose();
    _phase.dispose();
    super.dispose();
  }

  void _down(PointerDownEvent e) {
    if (_pointer != null) return;
    _pointer = e.pointer;
    _downX = e.position.dx;
    _lastBeyond = 0;
    _downAt = DateTime.now();
    _gestureGen++;
    _frac.stop();
  }

  void _move(PointerMoveEvent e, double travel, bool rtl) {
    if (e.pointer != _pointer) return;
    // Dragging is disabled while busy (the source locks the track);
    // the pointer is still tracked so the release reads as a tap.
    if (widget.state.busy) return;
    final total = e.position.dx - _downX;
    if (!_dragging && total.abs() <= 18) return;
    final beyond = total - 18 * total.sign;
    final dBeyond = beyond - _lastBeyond;
    _lastBeyond = beyond;
    if (travel <= 0 || dBeyond == 0) return;
    _dragging = true;
    final dx = rtl ? -dBeyond : dBeyond;
    _frac.value = (_frac.value + dx / travel).clamp(0.0, 1.0);
  }

  void _up(PointerUpEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    final s = widget.state;
    if (!_dragging) {
      // A tap. Held past the long-press deadline it was the user
      // reading the tooltip, not a tap (the round-2 rule).
      final held = _downAt == null
          ? Duration.zero
          : DateTime.now().difference(_downAt!);
      if (held >= const Duration(milliseconds: 500)) return;
      if (s.busy) {
        // The busy tap is the cancel.
        s.onToggle();
      } else if (!_reduced) {
        _nudge();
      }
      return;
    }
    _dragging = false;
    final drag = _frac.value;
    final endOn = s.on ? drag >= 0.28 : drag > 0.72;
    if (endOn != s.on) s.onToggle();
    if (_reduced) {
      _frac.value = _rest;
    } else {
      _frac.animateTo(_rest, curve: Curves.easeOut);
    }
  }

  void _nudge() {
    final gen = ++_gestureGen;
    final dir = widget.state.on ? -0.14 : 0.14;
    final target = (_rest + dir).clamp(0.0, 1.0);
    _frac
        .animateTo(
          target,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
        )
        .whenComplete(() {
          if (!mounted || gen != _gestureGen) return;
          _frac.animateTo(_rest, curve: Curves.easeOut);
        });
  }

  void _cancel(PointerCancelEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    if (_dragging) {
      _dragging = false;
      if (_reduced) {
        _frac.value = _rest;
      } else {
        _frac.animateTo(_rest, curve: Curves.easeOut);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final tokens = ZedColors.of(context);
    if (tokens == null) {
      // The Bento controls only exist under the Bento theme (which
      // always installs the tokens); keep a sane fallback anyway.
      return _ButtonConnect(state: s, big: true);
    }
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final dot = s.live
        ? tokens.stage
        : s.error
        ? tokens.bad
        : s.busy
        ? tokens.stage.withValues(alpha: 0.65)
        : tokens.onLime.withValues(alpha: 0.40);
    return Semantics(
      button: true,
      label: s.label,
      onTap: s.onToggle,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final travel = math.max(0.0, constraints.maxWidth - 28 - 40);
          return Container(
              height: 84,
              decoration: BoxDecoration(
                color: tokens.lime,
                borderRadius: bentoBlockRadius(widget.prefs.bentoCorner),
              ),
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
                            color: dot,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tokens.onLime,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (s.hint.isNotEmpty)
                          // The hint ellipsizes when the row is tight
                          // (the source gives it maxLines 1 + ellipsis
                          // in the same weighted row).
                          Flexible(
                            child: Text(
                              s.hint,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: tokens.onLime.withValues(alpha: 0.75),
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // The gestures live on the TRACK alone (the
                  // source's tap/drag detectors sit on the 44 dp
                  // track box; the header is inert).
                  Expanded(
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: _down,
                      onPointerMove: (e) => _move(e, travel, rtl),
                      onPointerUp: _up,
                      onPointerCancel: _cancel,
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_frac, _phase]),
                        builder: (context, _) {
                          final frac = _frac.value;
                          return LayoutBuilder(
                          builder: (context, track) {
                            final w = track.maxWidth;
                            final h = track.maxHeight;
                            // The knob's centre, measured from the
                            // START edge (the source measures the
                            // position from the start and mirrors
                            // the whole track in RTL).
                            final cx = 20 + frac * math.max(0.0, w - 40);
                            final physicalCx = rtl ? w - cx : cx;
                            return Stack(
                              children: [
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: _WavePainter(
                                      frac: frac,
                                      rtl: rtl,
                                      color: tokens.onLime,
                                      connected: s.live,
                                      busy: s.busy,
                                      phase: _phase.value,
                                      // BentoPrefs.wave defaults ON
                                      // in the source; the port's
                                      // prefs carry no wave toggle
                                      // yet (documented, round 4), so
                                      // the control renders the
                                      // source's default config.
                                      wave: true,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: physicalCx - 20,
                                  top: (h - 40) / 2,
                                  child: Transform.translate(
                                    offset: Offset(0, _waveY(frac, w)),
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: tokens.onLime,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.power_settings_new_rounded,
                                        size: 20,
                                        color: tokens.lime,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                        },
                      ),
                    ),
                  ),
                ],
              ),
          );
        },
      ),
    );
  }

  /// The wave's y offset at the knob: the source rides the knob at
  /// `waveOffset(position * range)` — the sine of the DISTANCE
  /// TRAVELLED, not of the physical x (BentoConnectBar.kt).
  double _waveY(double frac, double width) {
    final range = math.max(0.0, width - 40);
    if (range <= 0) return 0;
    final halves = math.max(1, (range / 16).round());
    final wavelength = 2 * range / halves;
    return 4.5 * math.sin(2 * math.pi * frac * range / wavelength);
  }
}

/// The Bento slide's sine wave (BentoConnectBar.kt's WaveTrack):
/// drawn in START coordinates — the wave spans only the knob's
/// travel, [knob/2, width − knob/2]; the part behind the knob is
/// solid (alpha 1 connected, 0.85 otherwise), the part ahead at
/// 0.3 — or 0.9 and DASHED (10 dp on, 9 dp off, phase scrolling)
/// while busy. Amplitude 4.5 dp; the wavelength is the preferred
/// 32 dp adjusted so a whole number of half-waves fits the travel
/// range (`waveLength`). The sine's phase is measured from the
/// start of the travel. In RTL the canvas flips around the centre,
/// exactly the source's `scale(if (rtl) -1f else 1f)` (round 4 —
/// rounds 1–3's port drew edge-to-edge, unflipped, with the phase
/// measured from the physical left).
class _WavePainter extends CustomPainter {
  const _WavePainter({
    required this.frac,
    required this.rtl,
    required this.color,
    required this.connected,
    required this.busy,
    required this.phase,
    required this.wave,
  });

  /// The knob's position, 0..1 of the travel.
  final double frac;
  final bool rtl;
  final Color color;
  final bool connected;
  final bool busy;
  final double phase;
  final bool wave;

  Path _wavePath(double from, double to, Size size, double start) {
    final path = Path();
    if (to <= from) return path;
    final mid = size.height / 2;
    if (!wave) {
      path.moveTo(from, mid);
      path.lineTo(to, mid);
      return path;
    }
    final range = math.max(1.0, size.width - 40);
    final halves = math.max(1, (range / 16).round());
    final wavelength = 2 * range / halves;
    double y(double x) =>
        mid + 4.5 * math.sin(2 * math.pi * (x - start) / wavelength);
    path.moveTo(from, y(from));
    for (var x = from + 2; x < to; x += 2) {
      path.lineTo(x, y(x));
    }
    path.lineTo(to, y(to));
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 40) return;
    canvas.save();
    if (rtl) {
      // The source flips the wave canvas in RTL (pivot = centre).
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    const start = 20.0;
    final end = size.width - 20;
    final knobU = start + frac * (size.width - 40);
    // Behind the knob (toward the start edge).
    if (knobU > start + 1) {
      stroke.color = color.withValues(alpha: connected ? 1 : 0.85);
      canvas.drawPath(_wavePath(start, knobU, size, start), stroke);
    }
    // Ahead of the knob.
    if (knobU < end - 1) {
      final ahead = _wavePath(knobU, end, size, start);
      if (busy) {
        stroke.color = color.withValues(alpha: 0.9);
        // Dash 10 / gap 9, the phase scrolling one full pattern per
        // 900 ms cycle (the painter's [phase] is that cycle's 0..1).
        final shift = phase * 19;
        for (final metric in ahead.computeMetrics()) {
          var d = -shift;
          while (d < metric.length) {
            final dStart = math.max(0.0, d);
            final dEnd = math.min(metric.length, d + 10);
            if (dEnd > dStart) {
              canvas.drawPath(metric.extractPath(dStart, dEnd), stroke);
            }
            d += 19;
          }
        }
      } else {
        stroke.color = color.withValues(alpha: 0.3);
        canvas.drawPath(ahead, stroke);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.frac != frac ||
      old.rtl != rtl ||
      old.color != color ||
      old.connected != connected ||
      old.busy != busy ||
      old.phase != phase ||
      old.wave != wave;
}

/// The Glass slider: the original's dedicated GlassSlideControl
/// (§2 of the extract, GlassControls.kt) — NOT the shared Bento
/// slide with a glass flag, which is what the port ran through
/// round 2. Its own geometry: a 74 dp glass-chrome track (the
/// recipe's real-blur chrome capsule, radius 37), a 64 dp white
/// knob resting 5 dp in, carrying the Z mark (30 dp; the glass
/// tint while off, #FFB06CFF while on), and the state label centred
/// with 72 dp of clearance on the knob's resting side, shimmering
/// on a 2600 ms sweep while it waits. Landing thresholds are the
/// slider's own 0.70 / 0.30. Pointer tracking is the slide's
/// Listener pattern — outside the gesture arena, so the wrapping
/// Tooltip can never cancel a paused drag — and the knob's motion
/// is physical-left based, as in the source. The source's springs
/// (stiff flip, 0.6-damped snap-back) are expressed as the kit's
/// ease curves, like the glass switch's.
class _GlassSlideConnect extends StatefulWidget {
  const _GlassSlideConnect({required this.state, required this.prefs});

  final ZedConnectState state;
  final ZedPrefs prefs;

  @override
  State<_GlassSlideConnect> createState() => _GlassSlideConnectState();
}

class _GlassSlideConnectState extends State<_GlassSlideConnect>
    with SingleTickerProviderStateMixin {
  double? _drag;
  int? _pointer;
  double _downX = 0;
  double _lastBeyond = 0;
  DateTime? _downAt;
  bool _reduced = false;

  /// The label shimmer's sweep; runs only while the control waits
  /// idle — never while busy, never under reduced motion.
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    _syncShimmer();
  }

  @override
  void didUpdateWidget(_GlassSlideConnect old) {
    super.didUpdateWidget(old);
    _syncShimmer();
  }

  void _syncShimmer() {
    if (widget.state.busy || _reduced) {
      if (_shimmer.isAnimating) _shimmer.stop();
      if (_shimmer.value != 0) _shimmer.value = 0;
    } else if (!_shimmer.isAnimating) {
      _shimmer.repeat();
    }
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  void _down(PointerDownEvent e) {
    if (_pointer != null) return;
    _pointer = e.pointer;
    _downX = e.position.dx;
    _lastBeyond = 0;
    _downAt = DateTime.now();
  }

  void _move(PointerMoveEvent e, double travel, bool rtl) {
    if (e.pointer != _pointer) return;
    final total = e.position.dx - _downX;
    if (_drag == null && total.abs() <= 18) return;
    final beyond = total - 18 * total.sign;
    final dBeyond = beyond - _lastBeyond;
    _lastBeyond = beyond;
    if (travel <= 0 || dBeyond == 0) return;
    final rest = widget.state.on ? 1.0 : 0.0;
    final dx = rtl ? -dBeyond : dBeyond;
    setState(() => _drag = ((_drag ?? rest) + dx / travel).clamp(0, 1));
  }

  void _up(PointerUpEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    final s = widget.state;
    final drag = _drag;
    if (drag == null) {
      // A plain tap toggles — unless the press was held past the
      // long-press deadline, which was the user reading the tooltip.
      final held = _downAt == null
          ? Duration.zero
          : DateTime.now().difference(_downAt!);
      if (held < const Duration(milliseconds: 500)) s.onToggle();
      return;
    }
    final endOn = s.on ? drag >= 0.30 : drag > 0.70;
    if (endOn != s.on) s.onToggle();
    setState(() => _drag = null);
  }

  void _cancel(PointerCancelEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    if (_drag != null) setState(() => _drag = null);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final prefs = widget.prefs;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final tint = glassTintColor(prefs.glassTint, dark);
    final markColor = s.on ? const Color(0xFFB06CFF) : tint;
    // While the shimmer runs the label wears the full label colour;
    // still (busy / reduced motion) it drops to the secondary label
    // token, exactly as the source switches label → label2.
    final labelColor = Theme.of(context).colorScheme.onSurface;
    final stillColor = dark ? const Color(0x99EBEBF5) : const Color(0x993C3C43);
    final frac = _drag ?? (s.on ? 1.0 : 0.0);
    final shimmering = !s.busy && !_reduced;
    Widget label = Text(
      s.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w500,
        color: shimmering ? Colors.white : stillColor,
      ),
    );
    if (shimmering) {
      label = AnimatedBuilder(
        animation: _shimmer,
        builder: (context, child) => ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            colors: [
              labelColor.withValues(alpha: 0.35),
              labelColor,
              labelColor.withValues(alpha: 0.35),
            ],
            // The source's band: full colour at 0.45, dim by 0.9.
            stops: const [0, 0.45, 0.9],
            // The band is exactly the text's width and its span
            // runs [w(p−1), wp] with p sweeping −1 → 2 over the
            // 2600 ms cycle (GlassControls.kt) — the port's sweep
            // covered [−w, +w] and peaked a half-cycle early
            // (round 4).
            transform: _SweepGradient((3 * _shimmer.value - 2) * bounds.width),
          ).createShader(bounds),
          child: child,
        ),
        child: label,
      );
    }
    return Semantics(
      button: true,
      toggled: s.on,
      label: s.label,
      onTap: s.onToggle,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final travel = math.max(1.0, constraints.maxWidth - 64 - 10);
          return Listener(
            onPointerDown: _down,
            onPointerMove: (e) => _move(e, travel, rtl),
            onPointerUp: _up,
            onPointerCancel: _cancel,
            child: SizedBox(
              height: 74,
              child: GlassChrome(
                prefs: prefs,
                radius: 37,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AnimatedPadding(
                        duration: _reduced
                            ? Duration.zero
                            : const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        padding: EdgeInsetsDirectional.only(
                          start: s.on ? 0 : 72,
                          end: s.on ? 72 : 0,
                        ),
                        child: Center(child: label),
                      ),
                    ),
                    // The knob's offset is measured from the START
                    // edge (the source's Compose offset resolves
                    // through placeRelative, so it mirrors in RTL —
                    // as does its drag delta, flipped above).
                    // Rounds 1–3 placed it with a physical `left:`,
                    // which in RTL put the knob at the wrong end
                    // from its drag (round 4).
                    AnimatedPositionedDirectional(
                      duration: _reduced || _drag != null
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      start: 5 + travel * frac,
                      top: 5,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x40000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          // The knob carries the Z mark in EVERY
                          // phase (GlassControls.kt) — rounds 1–3
                          // swapped in a spinner while busy (round 4).
                          child: CustomPaint(
                            size: const Size(30, 30),
                            painter: _ZMarkPainter(markColor),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The shimmer's travelling gradient: the α0.35 → 1 → α0.35 band
/// swept across the label by the animation's progress.
class _SweepGradient extends GradientTransform {
  const _SweepGradient(this.dx);

  final double dx;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(dx, 0, 0);
}

/// The Z glyph of the original's vector mark (viewBox origin
/// 98.5, 111; size 315×290), fitted into the knob's 30 dp box.
class _ZMarkPainter extends CustomPainter {
  const _ZMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
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
    final scale = size.width / 315;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    canvas.translate(-(98.5 + 315 / 2), -(111 + 290 / 2));
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ZMarkPainter old) => old.color != color;
}

/// The plain big button and, smaller, the Pixel Pill. (Bento's and
/// Glass's Button styles have their own widgets since round 4 —
/// _BentoButtonConnect / _GlassButtonConnect; this generic Material
/// button remains the Pixel/Old Pill, whose original is the home's
/// own ConnectButton composable rather than a kit control.)
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
          foregroundColor: _onStateColor(context, s),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(big ? 32 : 24),
          ),
        ),
        icon: _busyMark(context, s, _onStateColor(context, s)),
        label: Text(
          s.label,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// The Bento Button (BentoConnectVariants.kt), round 4: a 72 dp
/// block in lime (the stage colour while live), a 48 dp foreground
/// circle carrying the 24 dp power glyph in the block's colour, the
/// state word at 17sp Bold with the hint under it at 75%, and the
/// busy spinner (22 dp, 2.5 stroke) in the foreground colour. Press
/// squash 0.97.
class _BentoButtonConnect extends StatelessWidget {
  const _BentoButtonConnect({required this.state, required this.prefs});

  final ZedConnectState state;
  final ZedPrefs prefs;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final tokens = ZedColors.of(context);
    if (tokens == null) return _ButtonConnect(state: s, big: true);
    final bg = s.live ? tokens.stage : tokens.lime;
    final fg = s.live ? tokens.onStage : tokens.onLime;
    return ZedPressable(
      glass: false,
      pressScale: 0.97,
      onTap: s.onToggle,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: bentoBlockRadius(prefs.bentoCorner),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
              child: s.busy
                  ? Center(child: _BusyMark(color: bg))
                  : Icon(
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
                    s.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (s.hint.isNotEmpty)
                    Text(
                      s.hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fg.withValues(alpha: 0.75),
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Glass busy spinner (GlassControls.kt's GlassSpinner): a 17 dp
/// ring — a full circle at 35% plus a 90° arc — rotating linearly
/// over 900 ms, in the given colour (white on the tint capsule).
/// Under reduced motion the ring stands still.
class _GlassSpinner extends StatefulWidget {
  const _GlassSpinner({required this.color});

  final Color color;

  @override
  State<_GlassSpinner> createState() => _GlassSpinnerState();
}

class _GlassSpinnerState extends State<_GlassSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      if (_c.isAnimating) _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 17,
    height: 17,
    child: RotationTransition(
      turns: _c,
      child: CustomPaint(painter: _GlassSpinnerPainter(widget.color)),
    ),
  );
}

class _GlassSpinnerPainter extends CustomPainter {
  const _GlassSpinnerPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = color.withValues(alpha: 0.35);
    canvas.drawArc(rect, 0, math.pi * 2, false, ring);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, -math.pi / 2, math.pi / 2, false, arc);
  }

  @override
  bool shouldRepaint(_GlassSpinnerPainter old) => old.color != color;
}

/// The Glass Button (GlassControls.kt GlassConnectButton), round 4:
/// a 56 dp capsule. Off/busy: the tint (72% while busy) with a 14 dp
/// tint shadow at 50%, a white top gradient (0.26, 0.18 busy) fading
/// out at 0.52, the highlight sliver, and a white headline label —
/// the busy form swaps the label's companion for the glass spinner.
/// On (live): a real glassChrome capsule whose label is the state
/// word in the iOS red.
class _GlassButtonConnect extends StatelessWidget {
  const _GlassButtonConnect({required this.state, required this.prefs});

  final ZedConnectState state;
  final ZedPrefs prefs;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tint = glassTintColor(prefs.glassTint, dark);
    if (s.live) {
      return ZedPressable(
        onTap: s.onToggle,
        child: GlassChrome(
          prefs: prefs,
          radius: 28,
          child: SizedBox(
            height: 54,
            child: Center(
              child: Text(
                s.label,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: dark
                      ? const Color(0xFFFF4245)
                      : const Color(0xFFFF383C),
                ),
              ),
            ),
          ),
        ),
      );
    }
    final fill = s.busy ? tint.withValues(alpha: 0.72) : tint;
    return ZedPressable(
      onTap: s.onToggle,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: tint.withValues(alpha: 0.5),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // The vertical sheen: white 0.26 (0.18 busy) at the top,
            // gone by 0.52 of the height.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: s.busy ? 0.18 : 0.26),
                      Colors.white.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.52],
                  ),
                ),
              ),
            ),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (s.busy) ...[
                    const _GlassSpinner(color: Colors.white),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    s.label,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A morphing blob (the source's MorphingBlob over MaterialShapes
/// Cookie9Sided → SoftBurst polygons): a 9-point cookie whose inner
/// radius deepens with [progress], turned by [rotation]. Flutter has
/// no MaterialShapes; the polygon pair is the documented
/// approximation (round 4).
class _BlobPainter extends CustomPainter {
  const _BlobPainter({
    required this.color,
    required this.progress,
    required this.rotation,
    this.points = 9,
  });

  final Color color;

  /// 0 = cookie (off), 1 = burst (engaged).
  final double progress;

  /// Radians.
  final double rotation;

  /// Polygon points: 9 for the Morph (Cookie9Sided → SoftBurst),
  /// 6 for the Tile badge (Clover4Leaf → Cookie6Sided).
  final int points;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2;
    final inner = r * (0.88 + (0.70 - 0.88) * progress);
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final angle = rotation + i * math.pi / points;
      final radius = i.isEven ? r : inner;
      final p = centre + Offset(math.cos(angle), math.sin(angle)) * radius;
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
  bool shouldRepaint(_BlobPainter old) =>
      old.color != color ||
      old.progress != progress ||
      old.rotation != rotation ||
      old.points != points;
}

/// BentoType's Latin letter tracking (BentoLook/BentoKit): the
/// original tightens display/title/number styles by a percentage
/// of the size (and opens captions by 0.9) whenever the language
/// is not Persian — `latin = languageTag != "fa"` (Theme.kt).
/// Returns [latin] for non-fa locales, 0 for fa.
double _bentoTracking(BuildContext context, double latin) =>
    Localizations.localeOf(context).languageCode == 'fa' ? 0 : latin;

/// The Bento Morph (BentoConnectVariants.kt), round 4: a 112 dp row
/// — a 90 dp morphing blob (lime, power glyph 34 in onLime, the glyph
/// upright while the blob turns: busy spin 2400 ms, connected drift
/// 24000 ms), the state word at 21sp Bold, then the elapsed time
/// when live else the server name / hint, and the hint again as a
/// third line while engaged. The container runs surface → stage.
/// Press squash 0.94. (Rounds 1–3 ran a resizing pill.)
class _MorphConnect extends StatefulWidget {
  const _MorphConnect({required this.state, required this.prefs});

  final ZedConnectState state;
  final ZedPrefs prefs;

  @override
  State<_MorphConnect> createState() => _MorphConnectState();
}

class _MorphConnectState extends State<_MorphConnect>
    with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 24000),
  );
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(_MorphConnect old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final s = widget.state;
    // The source's spinning() reads 0 while inactive: a turn that
    // stops also resets (round 4).
    if (!_reduced && s.busy) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      if (_spin.isAnimating) _spin.stop();
      if (_spin.value != 0) _spin.value = 0;
    }
    // The connected drift is the playful-touch flourish; the port's
    // prefs carry no playful toggle yet (documented, round 4), so
    // the source's default (on) applies.
    if (!_reduced && s.live) {
      if (!_drift.isAnimating) _drift.repeat();
    } else {
      if (_drift.isAnimating) _drift.stop();
      if (_drift.value != 0) _drift.value = 0;
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    _drift.dispose();
    super.dispose();
  }

  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final tokens = ZedColors.of(context);
    if (tokens == null) return _ButtonConnect(state: s, big: true);
    final engaged = s.on;
    final ink = engaged ? tokens.onStage : tokens.ink;
    // The source's press squash (0.94) sits on the BLOB's layer,
    // not on the whole row (round 4); the morph progress runs to
    // 1 while connected OR busy.
    final morphed = s.live || s.busy;
    return Semantics(
      button: true,
      label: s.label,
      onTap: s.onToggle,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) {
          setState(() => _pressed = false);
          s.onToggle();
        },
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: AnimatedContainer(
        duration: _reduced
            ? Duration.zero
            : const Duration(milliseconds: 340),
        curve: Curves.easeOut,
        height: 112,
        decoration: BoxDecoration(
          color: engaged ? tokens.stage : tokens.surface,
          borderRadius: bentoBlockRadius(widget.prefs.bentoCorner),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            AnimatedScale(
              scale: _pressed && !_reduced ? 0.94 : 1,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              child: SizedBox(
              width: 90,
              height: 90,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: Listenable.merge([_spin, _drift]),
                    builder: (context, _) => TweenAnimationBuilder<double>(
                      tween: Tween(end: morphed ? 1 : 0),
                      duration: _reduced
                          ? Duration.zero
                          : const Duration(milliseconds: 500),
                      builder: (context, progress, _) => CustomPaint(
                        size: const Size(90, 90),
                        painter: _BlobPainter(
                          color: tokens.lime,
                          progress: progress,
                          rotation:
                              _spin.value * math.pi * 2 +
                              _drift.value * math.pi * 2,
                        ),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.power_settings_new_rounded,
                    size: 34,
                    color: tokens.onLime,
                  ),
                ],
              ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ink,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (s.live)
                    ZedElapsedText(
                      since: s.since,
                      style: TextStyle(
                        color: ink.withValues(alpha: 0.8),
                        fontSize: 15,
                        // BentoType.number(15): SemiBold, tnum,
                        // Latin tracking −2.5% (round 4).
                        fontWeight: FontWeight.w600,
                        letterSpacing: _bentoTracking(context, -0.375),
                      ),
                    )
                  else
                    Text(
                      s.serverName ?? s.hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ink.withValues(alpha: 0.8),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: _bentoTracking(context, -0.375),
                      ),
                    ),
                  if ((s.live || s.busy) && s.hint.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      s.hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ink.withValues(alpha: 0.65),
                        fontSize: 14,
                      ),
                    ),
                  ],
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

/// The Bento Rail (BentoConnectVariants.kt), round 4: a HORIZONTAL
/// 80 dp capsule (radius 40, padding 8) — rounds 1–3 rendered it as
/// a vertical 64×180 switch, the wrong orientation entirely. "On"
/// in the source means connected OR busy: the track runs surface2 →
/// lime, the 64 dp knob (lime → onLime; the 28 dp power glyph in
/// the inverse colour, in BOTH states) travels to the end, and the
/// middle carries a sine wave (amplitude 6, FIXED 30 dp wavelength,
/// stroke 4, inset 74 dp each side, onLime at 90% — 55% while
/// busy; its phase turns over 900 ms ONLY while busy and resets
/// to 0 otherwise, the source's `spinning()`). While off, the
/// middle carries the centred tap hint. Role: switch.
class _RailConnect extends StatefulWidget {
  const _RailConnect({required this.state, required this.prefs});

  final ZedConnectState state;
  final ZedPrefs prefs;

  @override
  State<_RailConnect> createState() => _RailConnectState();
}

class _RailConnectState extends State<_RailConnect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _phase = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(_RailConnect old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.state.busy && !_reduced) {
      if (!_phase.isAnimating) _phase.repeat();
    } else {
      // The source's spinning() returns 0 while inactive: the wave
      // stands at phase 0 whenever the control is not busy.
      if (_phase.isAnimating) _phase.stop();
      if (_phase.value != 0) _phase.value = 0;
    }
  }

  @override
  void dispose() {
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final tokens = ZedColors.of(context);
    if (tokens == null) return _ButtonConnect(state: s, big: true);
    // The source's `on` for the rail is connected OR busy.
    final engaged = s.on || s.busy;
    return Semantics(
      toggled: s.on,
      button: true,
      label: s.label,
      onTap: s.onToggle,
      child: GestureDetector(
        onTap: s.onToggle,
        child: AnimatedContainer(
          duration: _reduced
              ? Duration.zero
              : const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          height: 80,
          decoration: BoxDecoration(
            color: engaged ? tokens.lime : tokens.surface2,
            borderRadius: BorderRadius.circular(40),
          ),
          padding: const EdgeInsets.all(8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              return Stack(
                children: [
                  if (engaged)
                    Positioned(
                      left: 74,
                      right: 74,
                      top: 0,
                      bottom: 0,
                      child: AnimatedBuilder(
                        animation: _phase,
                        builder: (context, _) => CustomPaint(
                          painter: _RailWavePainter(
                            color: tokens.onLime.withValues(
                              alpha: s.busy ? 0.55 : 0.9,
                            ),
                            phase: _phase.value,
                          ),
                        ),
                      ),
                    )
                  else
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 72),
                        child: Text(
                          // Off, the middle carries the tap hint
                          // (the source's tapHint), not the state
                          // word (round 4).
                          s.hint.isNotEmpty ? s.hint : s.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.muted,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  AnimatedPositionedDirectional(
                    duration: _reduced
                        ? Duration.zero
                        : const Duration(milliseconds: 280),
                    curve: Curves.easeOut,
                    start: engaged ? math.max(0.0, w - 64) : 0,
                    top: 0,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: engaged ? tokens.onLime : tokens.lime,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.power_settings_new_rounded,
                        size: 28,
                        color: engaged ? tokens.lime : tokens.onLime,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The rail's wave: a sine of amplitude 6 and a FIXED 30 dp
/// wavelength (the source does not fit it to the width — round 4),
/// phase-shifted while busy: y = mid + 6·sin(2π(x + phase·30)/30).
class _RailWavePainter extends CustomPainter {
  const _RailWavePainter({required this.color, required this.phase});

  final Color color;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;
    const wavelength = 30.0;
    final mid = size.height / 2;
    final shift = phase * wavelength;
    final path = Path();
    for (var x = 0.0; x <= size.width; x += 2) {
      final y = mid + 6 * math.sin(2 * math.pi * (x + shift) / wavelength);
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RailWavePainter old) =>
      old.color != color || old.phase != phase;
}

/// The Bento Hold (BentoConnectVariants.kt), round 4: a 104 dp row
/// in lime (stage while live) — a 76 dp knob (a filled disc ringed
/// by the progress arc: the hold filling 0→360 over 650 ms LINEAR,
/// a 90° arc rotating over 1100 ms while busy, the full ring while
/// live), the state word at 18sp Bold, and beneath it the elapsed
/// time at 26sp when live, else the hint / server name. Press and
/// hold 650 ms toggles; releasing early cancels; while busy a plain
/// TAP is the cancel. (Rounds 1–3 rendered a bare 120 dp ring.) A
/// Listener is used instead of a GestureDetector so press tracking
/// stays outside the gesture arena and cannot be canceled by the
/// wrapping Tooltip's long-press recognizer.
class _HoldConnect extends StatefulWidget {
  const _HoldConnect({required this.state, required this.prefs});

  final ZedConnectState state;
  final ZedPrefs prefs;

  @override
  State<_HoldConnect> createState() => _HoldConnectState();
}

class _HoldConnectState extends State<_HoldConnect>
    with TickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  /// The busy ring's rotation (1100 ms linear loop).
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  Timer? _timer;
  bool _reduced = false;

  /// The pointer performing the hold, if any. A Listener hears EVERY
  /// pointer: without tracking, a second finger would start a second
  /// timer (a double toggle) and the first finger's release would
  /// cancel the second's hold.
  int? _pointer;
  DateTime? _downAt;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    _syncSpin();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    _spin.dispose();
    super.dispose();
  }

  /// Set when the hold has fired: the press is spent, and no new
  /// hold may start until the finger lifts (a second finger
  /// pressing after the toggle would otherwise arm a second
  /// toggle from the same touch sequence).
  bool _fired = false;

  @override
  void didUpdateWidget(_HoldConnect old) {
    super.didUpdateWidget(old);
    _syncSpin();
    // If the PHASE changed mid-press (on, busy or live — the busy
    // edge included: a hold armed while idle must not complete
    // into a state that has since started connecting), the press
    // belongs to a state that no longer exists; completing it
    // would act on the new state unasked. (Mere rebuilds with an
    // equal state — the homes rebuild the snapshot often — must
    // NOT cancel.)
    if (_pointer != null &&
        (old.state.on != widget.state.on ||
            old.state.busy != widget.state.busy ||
            old.state.live != widget.state.live)) {
      _pointer = null;
      _fired = false;
      _cancel();
    }
  }

  void _syncSpin() {
    if (widget.state.busy && !_reduced) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      // spinning() reads 0 while inactive (round 4).
      if (_spin.isAnimating) _spin.stop();
      if (_spin.value != 0) _spin.value = 0;
    }
  }

  void _start(int pointer) {
    if (_pointer != null || _fired) return;
    _pointer = pointer;
    _downAt = DateTime.now();
    // While busy there is nothing to hold for: the press is a tap
    // candidate (the cancel), decided on release.
    if (widget.state.busy) return;
    _c.forward(from: 0);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      // The pointer stays captured and the press is marked spent:
      // the toggle has happened; the release must do nothing more.
      _fired = true;
      widget.state.onToggle();
      _c.reset();
    });
  }

  void _end(int pointer) {
    if (pointer != _pointer) return;
    _pointer = null;
    if (_fired) {
      _fired = false;
      return;
    }
    if (widget.state.busy) {
      final held = _downAt == null
          ? Duration.zero
          : DateTime.now().difference(_downAt!);
      if (held < const Duration(milliseconds: 500)) {
        widget.state.onToggle();
      }
      return;
    }
    _cancel();
  }

  void _cancel() {
    _timer?.cancel();
    _c.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final tokens = ZedColors.of(context);
    if (tokens == null) return _ButtonConnect(state: s, big: true);
    final ink = s.live ? tokens.onStage : tokens.onLime;
    return Semantics(
      button: true,
      label: s.label,
      onTap: s.onToggle,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) => _start(e.pointer),
        onPointerUp: (e) => _end(e.pointer),
        onPointerCancel: (e) => _end(e.pointer),
        child: AnimatedContainer(
          duration: _reduced
              ? Duration.zero
              : const Duration(milliseconds: 340),
          curve: Curves.easeOut,
          height: 104,
          decoration: BoxDecoration(
            color: s.live ? tokens.stage : tokens.lime,
            borderRadius: bentoBlockRadius(widget.prefs.bentoCorner),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_c, _spin]),
                  builder: (context, _) => CustomPaint(
                    painter: _HoldRingPainter(
                      // The source's ring track is the animated
                      // INK at 22% (onLime off, onStage live) and
                      // the progress arc is ink too — lime only
                      // once connected (round 4; the port used the
                      // palette ink and a constant lime).
                      track: ink.withValues(alpha: 0.22),
                      progressColor: s.live ? tokens.lime : ink,
                      progress: s.live ? 1 : (s.busy ? -1 : _c.value),
                      spin: _spin.value,
                    ),
                    child: Center(
                      child: Container(
                        // The source's disc: radius = 38 − stroke
                        // 6 = 32, so 64 across (round 4).
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: s.live ? tokens.lime : tokens.onLime,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.power_settings_new_rounded,
                          size: 30,
                          color: s.live ? tokens.onLime : tokens.lime,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (s.live)
                      ZedElapsedText(
                        since: s.since,
                        style: TextStyle(
                          color: ink,
                          fontSize: 26,
                          // BentoType.number(26): SemiBold, Latin
                          // tracking −2.5% (round 4).
                          fontWeight: FontWeight.w600,
                          letterSpacing: _bentoTracking(context, -0.65),
                        ),
                      )
                    else
                      Text(
                        s.busy ? s.hint : (s.serverName ?? s.hint),
                        // The source's note runs to two lines.
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ink.withValues(alpha: 0.78),
                          fontSize: 14,
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

/// The Hold knob's ring: a full track circle (ink at 22%), then the
/// progress arc from −90° — the hold's fill (0..1), the full circle
/// when [progress] is 1, or the busy form when [progress] is −1: a
/// 90° arc rotated by [spin] turns.
class _HoldRingPainter extends CustomPainter {
  const _HoldRingPainter({
    required this.track,
    required this.progressColor,
    required this.progress,
    required this.spin,
  });

  final Color track;
  final Color progressColor;

  /// 0..1 hold fill; 1 = full ring; −1 = busy (rotating 90° arc).
  final double progress;
  final double spin;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.width / 2 - 3;
    final rect = Rect.fromCircle(center: centre, radius: radius);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );
    final arc = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    if (progress >= 1) {
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, arc);
    } else if (progress < 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2 + spin * math.pi * 2,
        math.pi / 2,
        false,
        arc,
      );
    } else if (progress > 0) {
      canvas.drawArc(rect, -math.pi / 2, progress * math.pi * 2, false, arc);
    }
  }

  @override
  bool shouldRepaint(_HoldRingPainter old) =>
      old.track != track ||
      old.progressColor != progressColor ||
      old.progress != progress ||
      old.spin != spin;
}

/// The Bento Tile (BentoConnectVariants.kt), round 4: a 132 dp
/// full-width tile(true) block — the stage colour, turning lime
/// while live — with the state word as a 12sp SemiBold caption at
/// 80%, the big line (the elapsed time at 40sp when live, else the
/// state word at 34sp), the hint / server name at the bottom, and a
/// 64 dp morphing badge at the top end (lime, or onLime while live;
/// power glyph 26; busy spin 1800 ms). Press squash 0.97. (Rounds
/// 1–3 ran a small 1.6-aspect tinted card.)
class _TileConnect extends StatefulWidget {
  const _TileConnect({required this.state, required this.prefs});

  final ZedConnectState state;
  final ZedPrefs prefs;

  @override
  State<_TileConnect> createState() => _TileConnectState();
}

class _TileConnectState extends State<_TileConnect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(_TileConnect old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.state.busy && !_reduced) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      // spinning() reads 0 while inactive (round 4).
      if (_spin.isAnimating) _spin.stop();
      if (_spin.value != 0) _spin.value = 0;
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final tokens = ZedColors.of(context);
    if (tokens == null) return _ButtonConnect(state: s, big: true);
    final ink = s.live ? tokens.onLime : tokens.onStage;
    return ZedPressable(
      glass: false,
      pressScale: 0.97,
      onTap: s.onToggle,
      child: AnimatedContainer(
        duration: _reduced
            ? Duration.zero
            : const Duration(milliseconds: 340),
        curve: Curves.easeOut,
        height: 132,
        decoration: BoxDecoration(
          color: s.live ? tokens.lime : tokens.stage,
          borderRadius: bentoTileRadius(widget.prefs.bentoCorner),
        ),
        padding: const EdgeInsets.all(18),
        child: Stack(
          children: [
            // The caption and the big line group at the top
            // (spacedBy 2, clear of the badge by 72 at the end);
            // the small line pins to the bottom (round 4 — the
            // port spread them with a Spacer).
            PositionedDirectional(
              top: 0,
              start: 0,
              end: 72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ink.withValues(alpha: 0.8),
                      fontSize: 12,
                      height: 16 / 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: _bentoTracking(context, 0.9),
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (s.live)
                    ZedElapsedText(
                      since: s.since,
                      style: TextStyle(
                        color: ink,
                        fontSize: 40,
                        fontWeight: FontWeight.w600,
                        letterSpacing: _bentoTracking(context, -1.0),
                      ),
                    )
                  else
                    Text(
                      s.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ink,
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        letterSpacing: _bentoTracking(context, -0.75),
                      ),
                    ),
                ],
              ),
            ),
            PositionedDirectional(
              bottom: 0,
              start: 0,
              end: 72,
              child: Text(
                // Engaged (live or busy) the bottom line is the
                // tap hint; off it is the server name, else the
                // hint (BentoConnectVariants.kt, round 4).
                (s.live || s.busy) ? s.hint : (s.serverName ?? s.hint),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ink.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
              ),
            ),
            PositionedDirectional(
              top: 0,
              end: 0,
              child: SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _spin,
                      builder: (context, _) => TweenAnimationBuilder<double>(
                        tween: Tween(end: s.live ? 1 : 0),
                        duration: _reduced
                            ? Duration.zero
                            : const Duration(milliseconds: 500),
                        builder: (context, progress, _) => CustomPaint(
                          size: const Size(64, 64),
                          painter: _BlobPainter(
                            color: s.live ? tokens.onLime : tokens.lime,
                            progress: progress,
                            rotation: _spin.value * math.pi * 2,
                            // The badge morphs Clover4Leaf →
                            // Cookie6Sided (round 4).
                            points: 6,
                          ),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.power_settings_new_rounded,
                      size: 26,
                      color: s.live ? tokens.lime : tokens.onLime,
                    ),
                  ],
                ),
              ),
            ),
          ],
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
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.45),
                    blurRadius: 36,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.power_settings_new_rounded, size: 52, color: color),
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

/// The Pixel/Old alt controls' colours (home/ConnectControls.kt):
/// the container is primary while off, secondaryContainer while on,
/// errorContainer on error; the content is the dark ink #10131A when
/// the container's luminance passes 0.5, else white.
(Color, Color) _pixelColors(BuildContext context, ZedConnectState s) {
  final scheme = Theme.of(context).colorScheme;
  // containerFor(): the active container serves every ACTIVE
  // phase — connected or busy (round 4; the port keyed it on
  // `on` alone, so a connecting control wore the idle primary).
  final bg = s.error
      ? scheme.errorContainer
      : (s.on || s.busy)
      ? scheme.secondaryContainer
      : scheme.primary;
  final fg = bg.computeLuminance() > 0.5
      ? const Color(0xFF10131A)
      : Colors.white;
  return (bg, fg);
}

/// The alt controls' busy mark at the control's own size: the
/// Material loading indicator, standing still under reduced motion.
Widget _pixelSpinner(BuildContext context, double size, Color color) {
  if (MediaQuery.disableAnimationsOf(context)) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _BusyArcPainter(color)),
    );
  }
  return SizedBox(
    width: size,
    height: size,
    child: CircularProgressIndicator(strokeWidth: 3, color: color),
  );
}

/// The glyph the alt controls share: a BOLT while idle, a CLOSE
/// while on (ConnectControls.kt) — not the power glyph the port used
/// through round 3.
IconData _pixelGlyph(ZedConnectState s) =>
    s.on ? Icons.close_rounded : Icons.bolt_rounded;

/// The Pixel Ring (ConnectControls.kt), round 4: a 132 dp filled
/// circle, its border in the content colour at 35% — 3 dp wide
/// while idle, 8 dp while on — the bolt/close glyph at 46 dp, the
/// busy spinner at 38. Press scale 0.94.
class _RingConnect extends StatelessWidget {
  const _RingConnect({required this.state});

  final ZedConnectState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final (bg, fg) = _pixelColors(context, s);
    return ZedPressable(
      glass: false,
      pressScale: 0.94,
      onTap: s.onToggle,
      child: Container(
        width: 132,
        height: 132,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bg,
          border: Border.all(
            color: fg.withValues(alpha: 0.35),
            width: s.on ? 8 : 3,
          ),
        ),
        child: Center(
          child: s.busy
              ? _pixelSpinner(context, 38, fg)
              : Icon(_pixelGlyph(s), size: 46, color: fg),
        ),
      ),
    );
  }
}

/// The Pixel Bar (ConnectControls.kt), round 4: a full-width 54 dp
/// bar, radius 14, horizontal padding 20 — a 10 dp content dot
/// (full alpha while on, 55% while idle) or the 20 dp busy spinner,
/// then the state word at titleMedium SemiBold.
class _BarConnect extends StatelessWidget {
  const _BarConnect({required this.state});

  final ZedConnectState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final (bg, fg) = _pixelColors(context, s);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: s.onToggle,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 54,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                if (s.busy)
                  _pixelSpinner(context, 20, fg)
                else
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: fg.withValues(alpha: s.on ? 1 : 0.55),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    s.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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

/// The Pixel Icon (ConnectControls.kt), round 4: a 76 dp rounded
/// square whose radius ANIMATES 24 → 34 while pressed; the
/// bolt/close glyph at 30 dp, the busy spinner at 26.
class _IconConnect extends StatefulWidget {
  const _IconConnect({required this.state});

  final ZedConnectState state;

  @override
  State<_IconConnect> createState() => _IconConnectState();
}

class _IconConnectState extends State<_IconConnect> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final (bg, fg) = _pixelColors(context, s);
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      label: s.label,
      onTap: s.onToggle,
      child: Listener(
        onPointerDown: (_) => setState(() => _down = true),
        onPointerUp: (_) => setState(() => _down = false),
        onPointerCancel: (_) => setState(() => _down = false),
        child: GestureDetector(
          onTap: s.onToggle,
          child: AnimatedContainer(
            duration: reduced
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(_down ? 34 : 24),
            ),
            child: Center(
              child: s.busy
                  ? _pixelSpinner(context, 26, fg)
                  : Icon(_pixelGlyph(s), size: 30, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Pixel Switch (ConnectControls.kt), round 4: a full-width
/// 68 dp capsule (radius 34, padding 6) whose 52 dp knob — the
/// content colour at 22%, carrying the bolt/close glyph at 24 dp or
/// the 22 dp busy spinner — slides start ↔ end with the state,
/// over a centred state word. (Rounds 1–3 rendered a stock Material
/// Switch beside a label.)
class _PixelSwitchConnect extends StatelessWidget {
  const _PixelSwitchConnect({required this.state});

  final ZedConnectState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final (bg, fg) = _pixelColors(context, s);
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      toggled: s.on,
      button: true,
      label: s.label,
      onTap: s.onToggle,
      child: GestureDetector(
        onTap: s.onToggle,
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(34),
          ),
          // The source pads the switch box by 8 (6 is its COMPACT
          // padding; the port models no compact variant).
          padding: const EdgeInsets.all(8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final travel = math.max(0.0, constraints.maxWidth - 52);
              return Stack(
                children: [
                  Center(
                    child: Text(
                      s.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fg,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  AnimatedPositionedDirectional(
                    duration: reduced
                        ? Duration.zero
                        : const Duration(milliseconds: 280),
                    curve: Curves.easeOut,
                    // The knob aligns by isActive: busy travels
                    // too (round 4).
                    start: (s.on || s.busy) ? travel : 0,
                    top: 0,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: fg.withValues(alpha: 0.22),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: s.busy
                            ? _pixelSpinner(context, 22, fg)
                            : Icon(_pixelGlyph(s), size: 24, color: fg),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The Glass Switch style is the VpnCard (GlassControls.kt),
/// round 4: a 74 dp glass module (cell shape) — a 42 dp circle
/// (iOS green while on, the neutral fill while off) with the shield
/// glyph at 22, the state word as the headline, the place / hint as
/// the subhead, and the kit's GlassSwitch at the end, checked
/// whenever the phase is not Off. (Rounds 1–3 rendered a bare
/// label + switch row.)
class _GlassCardConnect extends StatelessWidget {
  const _GlassCardConnect({required this.state, required this.prefs});

  final ZedConnectState state;
  final ZedPrefs prefs;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final label2 = dark ? const Color(0x99EBEBF5) : const Color(0x993C3C43);
    final sub = s.serverName ?? s.hint;
    return MergeSemantics(
      child: GlassModule(
        radius: GlassTokens.cellRadius,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        onTap: s.onToggle,
        reduced: prefs.reduceTransparency,
        child: SizedBox(
          height: 74,
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: s.on
                      ? (dark
                            ? const Color(0xFF30D158)
                            : const Color(0xFF34C759))
                      : (dark
                            ? const Color(0x5C787880)
                            : const Color(0x33787880)),
                ),
                child: Icon(
                  Icons.shield_rounded,
                  size: 22,
                  // The shield wears white on the green, the full
                  // label colour on the off fill (round 4).
                  color: s.on
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (sub.isNotEmpty)
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, color: label2),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GlassSwitch(
                // The source's card switch is checked for every
                // phase but Off — busy reads ON (round 4).
                value: s.on || s.busy,
                onChanged: (_) => s.onToggle(),
                prefs: prefs,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One phase look of the Glass Z (GlassZ.kt's zLook): the body
/// gradient stops, rim, shadow, the three glow stops and glow
/// strength, and the scalar paint parameters. Colours carry their
/// own alphas, exactly as the source's table does.
class _ZLook {
  const _ZLook({
    required this.a,
    required this.b,
    required this.rim,
    required this.shadow,
    required this.glowA,
    required this.glowB,
    required this.glowC,
    required this.hi,
    required this.lo,
    required this.shade,
    required this.spec,
    required this.caust,
    required this.shine,
    required this.glow,
    required this.busyAlpha,
  });

  final Color a;
  final Color b;
  final Color rim;
  final Color shadow;
  final Color glowA;
  final Color glowB;
  final Color glowC;
  final double hi;
  final double lo;
  final double shade;
  final double spec;
  final double caust;
  final double shine;
  final double glow;
  final double busyAlpha;

  static _ZLook lerp(_ZLook x, _ZLook y, double t) => _ZLook(
    a: Color.lerp(x.a, y.a, t)!,
    b: Color.lerp(x.b, y.b, t)!,
    rim: Color.lerp(x.rim, y.rim, t)!,
    shadow: Color.lerp(x.shadow, y.shadow, t)!,
    glowA: Color.lerp(x.glowA, y.glowA, t)!,
    glowB: Color.lerp(x.glowB, y.glowB, t)!,
    glowC: Color.lerp(x.glowC, y.glowC, t)!,
    hi: x.hi + (y.hi - x.hi) * t,
    lo: x.lo + (y.lo - x.lo) * t,
    shade: x.shade + (y.shade - x.shade) * t,
    spec: x.spec + (y.spec - x.spec) * t,
    caust: x.caust + (y.caust - x.caust) * t,
    shine: x.shine + (y.shine - x.shine) * t,
    glow: x.glow + (y.glow - x.glow) * t,
    busyAlpha: x.busyAlpha + (y.busyAlpha - x.busyAlpha) * t,
  );

  @override
  bool operator ==(Object other) =>
      other is _ZLook &&
      other.a == a &&
      other.b == b &&
      other.rim == rim &&
      other.shadow == shadow &&
      other.glow == glow &&
      other.busyAlpha == busyAlpha;

  @override
  int get hashCode => Object.hash(a, b, rim, shadow, glow, busyAlpha);
}

class _ZLookTween extends Tween<_ZLook> {
  _ZLookTween({required _ZLook end}) : super(end: end);

  @override
  _ZLook lerp(double t) => _ZLook.lerp(begin!, end!, t);
}

/// The zLook table (GlassZ.kt), verbatim.
_ZLook _zLook({required int phase, required bool dark, required Color tint}) {
  // phase: 0 off, 1 busy, 2 on.
  if (phase == 2) {
    return _ZLook(
      a: dark
          ? const Color(0xFFC48CFF).withValues(alpha: 0.55)
          : const Color(0xFFBE87FF).withValues(alpha: 0.80),
      b: dark
          ? const Color(0xFFFF64B4).withValues(alpha: 0.24)
          : const Color(0xFFFF69B4).withValues(alpha: 0.52),
      rim: dark
          ? Colors.white.withValues(alpha: 0.78)
          : const Color(0xFF783CB4).withValues(alpha: 0.42),
      shadow: dark
          ? const Color(0xFFB450E6).withValues(alpha: 0.26)
          : const Color(0xFFAA46DC).withValues(alpha: 0.32),
      glowA: const Color(0xFFB06CFF),
      glowB: const Color(0xFFE05BE6),
      glowC: const Color(0xFFFF6FB5),
      hi: 1,
      lo: 0.6,
      shade: dark ? 0.10 : 0.16,
      spec: 0.6,
      caust: 0.18,
      shine: 0.85,
      glow: 1,
      busyAlpha: 0,
    );
  }
  if (phase == 1) {
    return _ZLook(
      a: tint.withValues(alpha: dark ? 0.36 : 0.52),
      b: tint.withValues(alpha: dark ? 0.12 : 0.22),
      rim: dark
          ? Colors.white.withValues(alpha: 0.65)
          : tint.withValues(alpha: 0.5),
      shadow: tint.withValues(alpha: 0.22),
      glowA: tint.withValues(alpha: 0.75),
      glowB: tint.withValues(alpha: 0.75),
      glowC: tint.withValues(alpha: 0.75),
      hi: 0.95,
      lo: 0.6,
      shade: dark ? 0.12 : 0.18,
      spec: 0.5,
      caust: 0.28,
      shine: 0.75,
      glow: 0.7,
      busyAlpha: 1,
    );
  }
  return _ZLook(
    a: dark
        ? Colors.white.withValues(alpha: 0.26)
        : Colors.white.withValues(alpha: 0.84),
    b: dark
        ? Colors.white.withValues(alpha: 0.07)
        : const Color(0xFF9EACC8).withValues(alpha: 0.52),
    rim: dark
        ? Colors.white.withValues(alpha: 0.5)
        : const Color(0xFF283755).withValues(alpha: 0.32),
    shadow: dark
        ? Colors.black.withValues(alpha: 0.55)
        : const Color(0xFF1E2850).withValues(alpha: 0.2),
    glowA: Colors.transparent,
    glowB: Colors.transparent,
    glowC: Colors.transparent,
    hi: dark ? 0.85 : 1,
    lo: dark ? 0.35 : 0.85,
    shade: dark ? 0.35 : 0.22,
    spec: dark ? 0.45 : 0.72,
    caust: dark ? 0.16 : 0.42,
    shine: dark ? 0.6 : 0.95,
    glow: 0,
    busyAlpha: 0,
  );
}

/// The Z glyph path in its viewBox coordinates (origin 98.5, 111;
/// size 315×290) — shared by the hero painter and the slider's knob
/// mark.
Path _zPath() => Path()
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

/// The Glass "Z" hero (GlassZ.kt GlassZControl), reimplemented as a
/// custom painter in round 4 — rounds 1–3 shipped a static circle
/// with a text "Z". The glyph (width ≤176, height = width×162/176,
/// inside a tappable box +44/+48) is painted in layers: a blurred
/// back layer (the shadow silhouette dropped 14 dp, plus the glow
/// gradient silhouette breathing at alpha glow×breathe — a
/// static-shape blur, NOT a backdrop filter), the diagonal body
/// gradient, the clipped inner effects (caustics band, shine sweep,
/// busy scan, specular radial, inner shade and top highlight
/// strokes), the 1.3 dp rim, and the busy dashed trace. Ambient
/// motion runs off ONE ticker and only while animation is allowed
/// and the app is in the foreground (the source's MotionBudget
/// Paused gate, as far as this platform exposes it); otherwise the
/// source's static pose is painted. Phase colours tween 450 ms.
class _GlassZConnect extends StatefulWidget {
  const _GlassZConnect({required this.state, required this.prefs});

  final ZedConnectState state;
  final ZedPrefs prefs;

  @override
  State<_GlassZConnect> createState() => _GlassZConnectState();
}

class _GlassZConnectState extends State<_GlassZConnect>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  /// The ambient clock: a slow controller whose value reads as
  /// elapsed time (this app's material fork does not export the
  /// bare Ticker type). One hour per run; on completion it wraps
  /// and the base carries the accumulated hours.
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(hours: 1),
  );
  int _baseMs = 0;
  bool _animate = false;

  int get _elapsedMs =>
      _baseMs + (_clock.value * const Duration(hours: 1).inMilliseconds).round();

  int get _phase => widget.state.busy ? 1 : (widget.state.on ? 2 : 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clock.addListener(() {
      if (mounted) setState(() {});
    });
    _clock.addStatusListener((status) {
      if (status == AnimationStatus.completed && _animateWantedSafe) {
        _baseMs += const Duration(hours: 1).inMilliseconds;
        _clock.forward(from: 0);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncClock();
  }

  @override
  void didUpdateWidget(_GlassZConnect old) {
    super.didUpdateWidget(old);
    _syncClock();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _syncClock();
  }

  bool get _animateWantedSafe =>
      mounted &&
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  bool get _animateWanted =>
      _animateWantedSafe && !MediaQuery.disableAnimationsOf(context);

  void _syncClock() {
    if (!mounted) return;
    final want = _animateWanted;
    _animate = want;
    if (want && !_clock.isAnimating) {
      _clock.forward();
    } else if (!want && _clock.isAnimating) {
      _clock.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tint = glassTintColor(widget.prefs.glassTint, dark);
    final target = _zLook(phase: _phase, dark: dark, tint: tint);
    // The Z is a primary control, so it must read as a button with
    // a state to a screen reader and take keyboard activation on
    // desktop — a bare GestureDetector gives it neither (round 3,
    // DeepSeek ds3-02 finding 1).
    return FocusableActionDetector(
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => s.onToggle(),
        ),
      },
      child: Semantics(
        button: true,
        toggled: s.on,
        label: s.label,
        onTap: s.onToggle,
        child: ZedPressable(
          pressScale: 1.06,
          onTap: s.onToggle,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = math.min(176.0, constraints.maxWidth - 44);
              final width = w > 0 ? w : 176.0;
              final height = width * 162 / 176;
              return TweenAnimationBuilder<_ZLook>(
                tween: _ZLookTween(end: target),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 450),
                builder: (context, look, _) => CustomPaint(
                  size: Size(width + 44, height + 48),
                  painter: _ZPainter(
                    look: look,
                    tint: tint,
                    elapsedMs: _elapsedMs,
                    animate: _animate,
                    busy: _phase == 1,
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

/// Paints the Glass Z (see _GlassZConnect). All effect coordinates
/// are the source's, in the glyph's viewBox space (origin 98.5, 111;
/// size 315×290); [elapsedMs] drives the ambient values, which are
/// pure functions of it (the source's infinite transitions).
class _ZPainter extends CustomPainter {
  const _ZPainter({
    required this.look,
    required this.tint,
    required this.elapsedMs,
    required this.animate,
    required this.busy,
  });

  final _ZLook look;
  final Color tint;
  final int elapsedMs;
  final bool animate;
  final bool busy;

  static const double _zx = 98.5;
  static const double _zy = 111;
  static const double _zw = 315;
  static const double _zh = 290;

  /// A reversing tween (FastOutSlowIn) between [a] and [b] over
  /// [periodMs], as a pure function of elapsed time.
  double _reverse(double a, double b, int periodMs) {
    final cycle = elapsedMs % (periodMs * 2);
    final t = cycle < periodMs
        ? Curves.fastOutSlowIn.transform(cycle / periodMs)
        : 1 - Curves.fastOutSlowIn.transform((cycle - periodMs) / periodMs);
    return a + (b - a) * t;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final glyphW = size.width - 44;
    final glyphH = size.height - 48;
    if (glyphW <= 0 || glyphH <= 0) return;
    final sx = glyphW / _zw;
    final sy = glyphH / _zh;
    final path = _zPath();

    // Ambient values: the source's static pose when not animating.
    final double caust;
    final double shineX;
    final double scan;
    final double trace;
    final double breathe;
    if (animate) {
      caust = _reverse(0, 315, 7000);
      final period = busy ? 1700 : 4400;
      final t = (elapsedMs % period) / period;
      shineX = t < 0.55
          ? -380 + 760 * const Cubic(0.45, 0.0, 0.2, 1.0).transform(t / 0.55)
          : 380;
      scan = _reverse(-20, 250, 1200);
      trace = (elapsedMs % 1500) / 1500;
      breathe = _reverse(0.45, 0.9, 3200);
    } else {
      caust = 157;
      shineX = -400;
      scan = 113;
      trace = 0;
      breathe = 0.75;
    }

    void inZ(double originX, double originY, void Function() draw) {
      canvas.save();
      canvas.translate(originX, originY);
      canvas.scale(sx, sy);
      canvas.translate(-_zx, -_zy);
      draw();
      canvas.restore();
    }

    // The back layer: BOTH silhouettes live under the source's
    // 22 dp static-shape blur (a mask filter here — Compose's
    // BlurEffect radius maps to a Skia sigma of about half, so 11).
    const blur = MaskFilter.blur(BlurStyle.normal, 11);
    inZ(22, 24 + 14, () {
      canvas.drawPath(
        path,
        Paint()
          ..color = look.shadow
          ..maskFilter = blur,
      );
    });
    final glowAlpha = look.glow * breathe;
    if (glowAlpha > 0.001) {
      inZ(22, 24, () {
        canvas.drawPath(
          path,
          Paint()
            ..maskFilter = blur
            ..shader = ui.Gradient.linear(
              const Offset(_zx, _zy),
              const Offset(_zx + _zw, _zy + _zh),
              [look.glowA, look.glowB, look.glowC],
              [0, 0.5, 1],
            )
            ..color = Colors.white.withValues(alpha: glowAlpha),
        );
      });
    }

    // The glyph itself, in its box at (22, 24).
    inZ(22, 24, () {
      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.linear(
            const Offset(_zx, _zy),
            const Offset(_zx + _zw, _zy + _zh),
            [look.a, look.b],
          ),
      );
      canvas.save();
      canvas.clipPath(path);
      final box = Rect.fromLTWH(_zx, _zy, _zw, _zh);
      // Caustics: the rainbow band, 1260 wide, offset by caust.
      final cx = -531.5 + caust;
      canvas.drawRect(
        box,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(cx, 0),
            Offset(cx + 1260, 0),
            const [
              Color(0xFF00C3FF),
              Color(0xFF9A7CFF),
              Color(0xFFC7F24E),
              Color(0xFFFF8DC7),
              Color(0xFF00C3FF),
            ],
            [0, 0.25, 0.5, 0.75, 1],
          )
          ..color = Colors.white.withValues(alpha: look.caust),
      );
      // The shine sweep (hidden while parked outside ±379).
      if (shineX > -379 && shineX < 379) {
        canvas.drawRect(
          box,
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(_zx + shineX, _zy),
              Offset(_zx + _zw + shineX, _zy + 0.4 * _zh),
              [
                Colors.transparent,
                Colors.transparent,
                Colors.white.withValues(alpha: look.shine),
                Colors.transparent,
                Colors.transparent,
              ],
              [0, 0.4, 0.5, 0.6, 1],
            ),
        );
      }
      // The busy scan band.
      if (look.busyAlpha > 0.001) {
        final syTop = _zy + scan;
        canvas.drawRect(
          Rect.fromLTWH(_zx, syTop, _zw, 64),
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(0, syTop),
              Offset(0, syTop + 64),
              [
                Colors.transparent,
                Colors.white.withValues(alpha: 0.7),
                Colors.transparent,
              ],
              [0, 0.5, 1],
            )
            ..color = Colors.white.withValues(alpha: look.busyAlpha),
        );
      }
      // The specular radial.
      canvas.drawRect(
        box,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(_zx + 0.28 * _zw, _zy + 0.08 * _zh),
            0.6 * (_zw + _zh) / 2,
            [Colors.white.withValues(alpha: look.spec), Colors.transparent],
          ),
      );
      // The inner shade stroke (18) and top highlight stroke (12).
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18
          ..strokeJoin = StrokeJoin.round
          ..shader = ui.Gradient.linear(
            const Offset(_zx, _zy),
            const Offset(_zx + _zw, _zy + _zh),
            [
              Colors.black.withValues(alpha: 0),
              Colors.black.withValues(alpha: 0),
              Colors.black.withValues(alpha: look.shade),
            ],
            [0, 0.45, 1],
          ),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..strokeJoin = StrokeJoin.round
          ..shader = ui.Gradient.linear(
            const Offset(_zx, _zy),
            const Offset(_zx + _zw, _zy + _zh),
            [
              Colors.white.withValues(alpha: look.hi),
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: look.lo),
            ],
            [0, 0.42, 0.72, 1],
          ),
      );
      canvas.restore();
      // The rim: 1.3 dp in device space, expressed in path units.
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3 * _zw / glyphW
          ..strokeJoin = StrokeJoin.round
          ..color = look.rim,
      );
      // The busy trace: a dashed stroke (dash 19% of the path
      // length, phase turning over 1500 ms), white → tint.
      if (look.busyAlpha > 0.001) {
        final tracePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..shader = ui.Gradient.linear(
            const Offset(_zx, _zy),
            const Offset(_zx + _zw, _zy + _zh),
            [Colors.white, tint],
          )
          ..color = Colors.white.withValues(alpha: look.busyAlpha);
        for (final metric in path.computeMetrics()) {
          final length = metric.length;
          final dash = length * 0.19;
          var d = -length * (1 - trace);
          while (d < length) {
            final start = math.max(0.0, d);
            final end = math.min(length, d + dash);
            if (end > start) {
              canvas.drawPath(metric.extractPath(start, end), tracePaint);
            }
            d += length;
          }
        }
      }
    });
  }

  @override
  bool shouldRepaint(_ZPainter old) =>
      old.look != look ||
      old.tint != tint ||
      old.elapsedMs != elapsedMs ||
      old.animate != animate ||
      old.busy != busy;
}
