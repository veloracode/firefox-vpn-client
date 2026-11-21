import 'package:material_ui/material_ui.dart';

import 'zed_connect.dart';
import 'zed_connect_glass.dart';
import 'zed_prefs.dart';
import 'zed_theme.dart';

/// The home hero: status word, the design's connect control, and the
/// timer / speed chips. Replaces the stock power orb in the overview
/// page for every design. The caller passes the already-formatted
/// live strings so the 2 s core poll only rebuilds the text leaves
/// that actually changed.
class ZedHero extends StatelessWidget {
  const ZedHero({
    super.key,
    required this.prefs,
    required this.spec,
    required this.upText,
    required this.downText,
    this.upRate = 0,
    this.downRate = 0,
    this.onOpenServers,
    this.onOpenAccounts,
    this.serversLabel = '',
    this.accountsLabel = '',
  });

  final ZedPrefs prefs;
  final ZedConnectSpec spec;
  final String upText;
  final String downText;

  /// Raw rates (bytes/s) for the Pixel traffic strip's rings/graph.
  final double upRate;
  final double downRate;

  /// Bento quick actions (homeQuick), when the page offers them.
  final VoidCallback? onOpenServers;
  final VoidCallback? onOpenAccounts;
  final String serversLabel;
  final String accountsLabel;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return switch (prefs.design) {
      ZedDesign.bento => _BentoHero(
        tokens: bentoTokensFor(
          prefs.bento.palette,
          dark,
          amoled: prefs.bento.amoled,
          seedArgb: pixelAccents[prefs.pixel.accentIndex.clamp(0, 9)]
              .toARGB32(),
        ),
        prefs: prefs.bento,
        zedPrefs: prefs,
        spec: spec,
        upText: upText,
        downText: downText,
        onOpenServers: onOpenServers,
        onOpenAccounts: onOpenAccounts,
        serversLabel: serversLabel,
        accountsLabel: accountsLabel,
      ),
      ZedDesign.pixel => _PixelHero(
        zedPrefs: prefs,
        spec: spec,
        upText: upText,
        downText: downText,
        upRate: upRate,
        downRate: downRate,
      ),
      ZedDesign.old => _PixelHero(
        zedPrefs: prefs,
        spec: spec,
        upText: upText,
        downText: downText,
        upRate: upRate,
        downRate: downRate,
      ),
      ZedDesign.glass => _GlassHero(
        tokens: glassTokensFor(prefs.glass, dark),
        prefs: prefs.glass,
        spec: spec,
        upText: upText,
        downText: downText,
      ),
    };
  }
}

class _Chips extends StatelessWidget {
  const _Chips({
    required this.items,
    required this.background,
    required this.foreground,
    required this.radius,
  });

  final List<(IconData, String)> items;
  final Color background;
  final Color foreground;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (icon, text) in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(radius),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: foreground),
                const SizedBox(width: 6),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _BentoHero extends StatelessWidget {
  const _BentoHero({
    required this.tokens,
    required this.prefs,
    required this.zedPrefs,
    required this.spec,
    required this.upText,
    required this.downText,
    this.onOpenServers,
    this.onOpenAccounts,
    this.serversLabel = '',
    this.accountsLabel = '',
  });

  final BentoTokens tokens;
  final BentoPrefs prefs;
  final ZedPrefs zedPrefs;
  final ZedConnectSpec spec;
  final String upText;
  final String downText;
  final VoidCallback? onOpenServers;
  final VoidCallback? onOpenAccounts;
  final String serversLabel;
  final String accountsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = tokens;
    final scheme = Theme.of(context).colorScheme;
    final statusColor = spec.phase == ZedPhase.error
        ? scheme.error
        : spec.active
        ? colors.lime
        : colors.ink;
    final compact = prefs.density == BentoDensity.compact;
    final titleSize = switch (prefs.title) {
      BentoTitleSize.huge => 40.0,
      BentoTitleSize.large => 34.0,
      BentoTitleSize.compact => 28.0,
    };
    final chips = <(IconData, String)>[
      if (prefs.homeChips && prefs.homeSession && spec.elapsed.isNotEmpty)
        (Icons.schedule_rounded, spec.elapsed),
      if (prefs.homeChips && prefs.homeSpeed && prefs.liveTiles && spec.on) ...[
        (Icons.arrow_upward_rounded, upText),
        (Icons.arrow_downward_rounded, downText),
      ],
    ];
    final showQuick =
        prefs.homeQuick && onOpenServers != null && onOpenAccounts != null;
    return Column(
      children: [
        Text(
          spec.stateLabel,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: titleSize,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: statusColor,
          ),
        ),
        // The place card below the hero names the location; the
        // hero does not repeat it.
        SizedBox(height: compact ? 14 : 20),
        ZedConnectControl(prefs: zedPrefs, spec: spec),
        if (chips.isNotEmpty) ...[
          SizedBox(height: compact ? 12 : 18),
          _Chips(
            items: chips,
            background: colors.surface,
            foreground: colors.ink,
            radius: bentoChipRadius(prefs.corners),
          ),
        ],
        if (showQuick) ...[
          SizedBox(height: compact ? 12 : 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _QuickAction(
                icon: Icons.public_rounded,
                label: serversLabel,
                background: colors.surface,
                foreground: colors.ink,
                radius: bentoChipRadius(prefs.corners),
                onTap: onOpenServers!,
              ),
              const SizedBox(width: 8),
              _QuickAction(
                icon: Icons.people_rounded,
                label: accountsLabel,
                background: colors.surface,
                foreground: colors.ink,
                radius: bentoChipRadius(prefs.corners),
                onTap: onOpenAccounts!,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.radius,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final double radius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: background,
    borderRadius: BorderRadius.circular(radius),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PixelHero extends StatelessWidget {
  const _PixelHero({
    required this.zedPrefs,
    required this.spec,
    required this.upText,
    required this.downText,
    required this.upRate,
    required this.downRate,
  });

  final ZedPrefs zedPrefs;
  final ZedConnectSpec spec;
  final String upText;
  final String downText;
  final double upRate;
  final double downRate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).height < 640;
    // Pixel/Old show live speeds in the traffic strip under the
    // control (styled by trafficStyle), not in hero chips; the Hero
    // control itself carries the session timer while connected.
    return Column(
      children: [
        Text(
          spec.stateLabel,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: spec.phase == ZedPhase.error
                ? scheme.error
                : scheme.onSurface,
          ),
        ),
        const SizedBox(height: 18),
        ZedConnectControl(prefs: zedPrefs, spec: spec, compact: compact),
        if (spec.on) ...[
          const SizedBox(height: 16),
          _TrafficStrip(
            prefs: zedPrefs.activePixel,
            upText: upText,
            downText: downText,
            upRate: upRate,
            downRate: downRate,
          ),
        ],
      ],
    );
  }
}

/// The Pixel/Old traffic strip under the connect control: five
/// styles (cards / duo / rings / minimal / graph), three tile sizes,
/// and the user's custom traffic colours when set.
class _TrafficStrip extends StatefulWidget {
  const _TrafficStrip({
    required this.prefs,
    required this.upText,
    required this.downText,
    required this.upRate,
    required this.downRate,
  });

  final PixelPrefs prefs;
  final String upText;
  final String downText;
  final double upRate;
  final double downRate;

  @override
  State<_TrafficStrip> createState() => _TrafficStripState();
}

class _TrafficStripState extends State<_TrafficStrip> {
  final List<double> _history = [];

  void _sample() {
    _history.add(widget.downRate + widget.upRate);
    if (_history.length > 24) _history.removeAt(0);
  }

  @override
  void initState() {
    super.initState();
    _sample();
  }

  @override
  void didUpdateWidget(_TrafficStrip old) {
    super.didUpdateWidget(old);
    // Sample on every rebuild, not only on change: the strip is
    // rebuilt by the overview's poll stream, and steady traffic
    // (an idle 0/0 above all) is still a time series — gating on
    // change froze the graph and left the text fallback up forever.
    _sample();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = widget.prefs;
    final downColor = p.customDownload != null
        ? Color(p.customDownload!)
        : scheme.primary;
    final upColor = p.customUpload != null
        ? Color(p.customUpload!)
        : scheme.tertiary;
    final downTile = p.customDownloadTile != null
        ? Color(p.customDownloadTile!)
        : scheme.surfaceContainerHigh;
    final upTile = p.customUploadTile != null
        ? Color(p.customUploadTile!)
        : scheme.surfaceContainerHigh;
    // cornerStyle scales the traffic tiles' radius (§3.2).
    final tileRadius = 16 * cornerStyleTileScale(p.cornerStyle);
    final (pad, fontSize, ringSize) = switch (p.trafficTileSize) {
      TrafficTileSize.small => (8.0, 12.0, 52.0),
      TrafficTileSize.normal => (12.0, 13.0, 64.0),
      TrafficTileSize.large => (16.0, 15.0, 76.0),
    };
    Widget value(String text, Color color) => Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    Widget tile(Color bg, IconData icon, Color color, String text) => Container(
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(tileRadius),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: fontSize + 3, color: color),
          const SizedBox(width: 6),
          value(text, scheme.onSurface),
        ],
      ),
    );
    return switch (p.trafficStyle) {
      TrafficCardStyle.cards => Row(
        children: [
          Expanded(
            child: tile(
              downTile,
              Icons.arrow_downward_rounded,
              downColor,
              widget.downText,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: tile(
              upTile,
              Icons.arrow_upward_rounded,
              upColor,
              widget.upText,
            ),
          ),
        ],
      ),
      TrafficCardStyle.duo => Container(
        padding: EdgeInsets.all(pad),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(tileRadius),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_downward_rounded,
                  size: fontSize + 3,
                  color: downColor,
                ),
                const SizedBox(width: 6),
                value(widget.downText, scheme.onSurface),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_upward_rounded,
                  size: fontSize + 3,
                  color: upColor,
                ),
                const SizedBox(width: 6),
                value(widget.upText, scheme.onSurface),
              ],
            ),
          ],
        ),
      ),
      TrafficCardStyle.rings => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _RingGauge(
            size: ringSize,
            fraction: (widget.downRate / 12500000).clamp(0.0, 1.0),
            color: downColor,
            track: downTile,
            label: widget.downText,
            fontSize: fontSize - 2,
          ),
          const SizedBox(width: 20),
          _RingGauge(
            size: ringSize,
            fraction: (widget.upRate / 12500000).clamp(0.0, 1.0),
            color: upColor,
            track: upTile,
            label: widget.upText,
            fontSize: fontSize - 2,
          ),
        ],
      ),
      TrafficCardStyle.minimal => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.arrow_downward_rounded,
            size: fontSize + 3,
            color: downColor,
          ),
          const SizedBox(width: 4),
          value(widget.downText, scheme.onSurface),
          const SizedBox(width: 14),
          Icon(Icons.arrow_upward_rounded, size: fontSize + 3, color: upColor),
          const SizedBox(width: 4),
          value(widget.upText, scheme.onSurface),
        ],
      ),
      TrafficCardStyle.graph => Container(
        height: ringSize,
        padding: EdgeInsets.all(pad),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(tileRadius),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final sample in _history)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  height:
                      (ringSize - 2 * pad) *
                      (sample / 12500000).clamp(0.04, 1.0),
                  decoration: BoxDecoration(
                    color: downColor.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            if (_history.isEmpty)
              Expanded(child: value(widget.downText, scheme.onSurface)),
          ],
        ),
      ),
    };
  }
}

class _RingGauge extends StatelessWidget {
  const _RingGauge({
    required this.size,
    required this.fraction,
    required this.color,
    required this.track,
    required this.label,
    required this.fontSize,
  });

  final double size;
  final double fraction;
  final Color color;
  final Color track;
  final String label;
  final double fontSize;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: _RingPainter(fraction: fraction, color: color, track: track),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.fraction,
    required this.color,
    required this.track,
  });

  final double fraction;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = track;
    canvas.drawCircle(center, radius, trackPaint);
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708,
      6.2832 * fraction,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.color != color || old.track != track;
}

class _GlassHero extends StatelessWidget {
  const _GlassHero({
    required this.tokens,
    required this.prefs,
    required this.spec,
    required this.upText,
    required this.downText,
  });

  final GlassTokens tokens;
  final GlassPrefs prefs;
  final ZedConnectSpec spec;
  final String upText;
  final String downText;

  @override
  Widget build(BuildContext context) {
    // GlassHome status line: the timer while connected (when the
    // home timer is on), else the state word; 24 dp box, headline,
    // letterSpacing 2.5.
    final line = spec.on && prefs.homeTimer && spec.elapsed.isNotEmpty
        ? spec.elapsed
        : spec.stateLabel.toUpperCase();
    return Column(
      children: [
        ZedGlassConnectControl(
          prefs: prefs,
          tokens: tokens,
          spec: spec,
          heroWidth: (MediaQuery.sizeOf(context).height * 0.30).clamp(
            140.0,
            176.0,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 24,
          child: Center(
            child: Text(
              line,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                letterSpacing: 2.5,
                color: tokens.label,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        if (spec.on && prefs.homeSpeed) ...[
          const SizedBox(height: 4),
          Text(
            '$downText  ·  $upText',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: tokens.label2,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }
}
