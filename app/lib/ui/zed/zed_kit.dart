import 'dart:async';

import 'package:flutter/physics.dart';
import 'package:material_ui/material_ui.dart';

import 'zed_connect_glass.dart' show GlassSwitch;
import 'zed_glass.dart';
import 'zed_motion.dart';
import 'zed_prefs.dart';
import 'zed_theme.dart';

/// Shared ZedSecure kit: navigation chrome, settings rows and small
/// components (ZED-TOKENS-EXTRACT §1.8, §2.5, §3.4, §5).

class ZedTab {
  const ZedTab({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Tracks the primary scroll controller's direction for the
/// auto-hide / shrink behaviours of the docks.
mixin ScrollDirectionTracker<T extends StatefulWidget> on State<T> {
  ScrollController? _controller;
  double _lastOffset = 0;
  bool scrollingDown = false;
  Timer? _idleTimer;

  void _attach() {
    final c = PrimaryScrollController.of(context);
    if (c == _controller) return;
    _controller?.removeListener(_onScroll);
    _controller = c;
    _controller?.addListener(_onScroll);
    _lastOffset = _safeOffset(c);
  }

  /// The primary controller is shared: while two pages coexist (a
  /// transition), it has two positions and [ScrollController.offset]
  /// is undefined — keep the last known offset then.
  static double _safeOffset(ScrollController c) =>
      c.positions.length == 1 ? c.offset : 0;

  void _onScroll() {
    final controller = _controller;
    if (controller == null || controller.positions.length != 1) return;
    final offset = controller.offset;
    final down = offset > _lastOffset + 4;
    final up = offset < _lastOffset - 4;
    if (down && !scrollingDown) {
      setState(() => scrollingDown = true);
    } else if (up && scrollingDown) {
      setState(() => scrollingDown = false);
    }
    if (offset <= 0 && scrollingDown) {
      setState(() => scrollingDown = false);
    }
    _lastOffset = offset;
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted && scrollingDown) setState(() => scrollingDown = false);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attach();
  }

  @override
  void dispose() {
    _controller?.removeListener(_onScroll);
    _idleTimer?.cancel();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Bento dock (§1.8)
// ---------------------------------------------------------------------------

/// 56 dp dock, full width minus 16 dp side margins, bar radius from
/// the Bento shape table; selected item gets a secondaryContainer
/// pill (radius = barRadius − 10) that slides between items; labels
/// per [BentoDockLabels]; auto-hide slides it down on scroll.
class BentoDock extends StatefulWidget {
  const BentoDock({
    super.key,
    required this.tokens,
    required this.prefs,
    required this.tabs,
    required this.index,
    required this.onSelect,
  });

  final BentoTokens tokens;
  final BentoPrefs prefs;
  final List<ZedTab> tabs;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  State<BentoDock> createState() => _BentoDockState();
}

class _BentoDockState extends State<BentoDock>
    with ScrollDirectionTracker<BentoDock> {
  @override
  Widget build(BuildContext context) {
    final colors = widget.tokens;
    final prefs = widget.prefs;
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(bentoCardRadius(prefs.corners));
    final hide = prefs.dockAutoHide && scrollingDown;
    return AnimatedSlide(
      offset: hide ? const Offset(0, 1.6) : Offset.zero,
      duration: const Duration(milliseconds: 250),
      curve: zedFastOutSlowIn,
      child: AnimatedOpacity(
        opacity: hide ? 0 : 1,
        duration: const Duration(milliseconds: 200),
        child: Container(
          height: 56,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: colors.dock, borderRadius: radius),
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: LayoutBuilder(
            builder: (context, box) {
              final itemW = box.maxWidth / widget.tabs.length;
              return Stack(
                children: [
                  AnimatedPositionedDirectional(
                    start: itemW * widget.index + 2,
                    top: 0,
                    duration: const Duration(milliseconds: 350),
                    curve: zedFastOutSlowIn,
                    child: Container(
                      width: itemW - 4,
                      height: 48,
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(
                          (bentoCardRadius(prefs.corners) - 10).clamp(0, 999),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < widget.tabs.length; i++)
                        Expanded(
                          child: _DockItem(
                            tab: widget.tabs[i],
                            selected: i == widget.index,
                            labels: prefs.dockLabels,
                            color: i == widget.index
                                ? scheme.onSecondaryContainer
                                : colors.muted,
                            onTap: () => widget.onSelect(i),
                          ),
                        ),
                    ],
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

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.tab,
    required this.selected,
    required this.labels,
    required this.color,
    required this.onTap,
  });

  final ZedTab tab;
  final bool selected;
  final BentoDockLabels labels;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final showLabel = switch (labels) {
      BentoDockLabels.always => true,
      BentoDockLabels.never => false,
      BentoDockLabels.active => selected,
    };
    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(tab.icon, size: 22, color: color),
            if (showLabel) ...[
              const SizedBox(height: 1),
              Text(
                tab.label,
                style: TextStyle(fontSize: 9, color: color),
                maxLines: 1,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Glass tab bar (§2.5)
// ---------------------------------------------------------------------------

/// 62 dp chrome platter; the selection platter slides with spring
/// (0.72, 400); on sustained down-scroll it shrinks to a 62 dp mini
/// circle showing the current tab (tap expands); the shrunk state
/// resets on tab change.
class GlassTabBar extends StatefulWidget {
  const GlassTabBar({
    super.key,
    required this.tokens,
    required this.tabs,
    required this.index,
    required this.onSelect,
    this.shrinkEnabled = true,
  });

  final GlassTokens tokens;
  final List<ZedTab> tabs;
  final int index;
  final ValueChanged<int> onSelect;

  /// GlassPrefs.shrinkTabBar: off keeps the full bar while scrolling.
  final bool shrinkEnabled;

  @override
  State<GlassTabBar> createState() => _GlassTabBarState();
}

class _GlassTabBarState extends State<GlassTabBar>
    with ScrollDirectionTracker<GlassTabBar>, TickerProviderStateMixin {
  late final AnimationController _platter = AnimationController(vsync: this);
  bool _shrunk = false;
  double _downAccum = 0;
  double _lastSeen = 0;
  ScrollController? _shrinkController;

  @override
  void initState() {
    super.initState();
    _platter.value = widget.index.toDouble();
  }

  @override
  void didUpdateWidget(GlassTabBar old) {
    super.didUpdateWidget(old);
    if (!widget.shrinkEnabled && _shrunk) _shrunk = false;
    if (widget.index != old.index) {
      _shrunk = false;
      _platter.animateWith(
        SpringSimulation(
          springPlatter,
          _platter.value,
          widget.index.toDouble(),
          0,
        ),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Extend the tracker's behaviour with shrink accumulation.
    final c = PrimaryScrollController.of(context);
    if (c != _shrinkController) {
      _shrinkController?.removeListener(_shrinkListener);
      _shrinkController = c;
      _shrinkController?.addListener(_shrinkListener);
      _lastSeen = c.positions.length == 1 ? c.offset : 0;
    }
  }

  void _shrinkListener() {
    if (!widget.shrinkEnabled) return;
    final c = _shrinkController;
    if (c == null || !mounted || c.positions.length != 1) return;
    final d = c.offset - _lastSeen;
    _lastSeen = c.offset;
    if (d > 0) {
      _downAccum += d;
      if (_downAccum > 48 && !_shrunk) setState(() => _shrunk = true);
    } else if (d < -2) {
      _downAccum = 0;
      if (_shrunk) setState(() => _shrunk = false);
    }
    if (c.offset <= 0 && _shrunk) setState(() => _shrunk = false);
  }

  @override
  void dispose() {
    _shrinkController?.removeListener(_shrinkListener);
    _platter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    if (_shrunk) {
      final tab = widget.tabs[widget.index];
      return Center(
        child: GestureDetector(
          onTap: () => setState(() => _shrunk = false),
          child: GlassChromeSurface(
            tokens: tokens,
            radius: BorderRadius.circular(31),
            child: SizedBox(
              width: 62,
              height: 62,
              child: Icon(tab.icon, size: 24, color: tokens.label),
            ),
          ),
        ),
      );
    }
    return GlassChromeSurface(
      tokens: tokens,
      child: SizedBox(
        height: 62,
        child: LayoutBuilder(
          builder: (context, box) {
            final itemW = box.maxWidth / widget.tabs.length;
            return AnimatedBuilder(
              animation: _platter,
              builder: (context, _) => Stack(
                children: [
                  PositionedDirectional(
                    start: 6 + itemW * _platter.value,
                    top: 6,
                    child: Container(
                      width: itemW - 12,
                      height: 50,
                      decoration: BoxDecoration(
                        color: tokens.platter,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < widget.tabs.length; i++)
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => widget.onSelect(i),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  widget.tabs[i].icon,
                                  size: 22,
                                  color: i == widget.index
                                      ? tokens.label
                                      : tokens.label2,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.tabs[i].label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: i == widget.index
                                        ? tokens.label
                                        : tokens.label2,
                                  ),
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pixel / Old bottom bar (§5)
// ---------------------------------------------------------------------------

/// Bottom navigation for the Pixel and Old designs, shaped by the
/// shared navStyle: expressive pill (72 dp, floating), floating bar
/// (64 dp), flat bar (64 dp, square), minimal (56 dp, icons only).
class ZedBottomBar extends StatelessWidget {
  const ZedBottomBar({
    super.key,
    required this.style,
    required this.tabs,
    required this.index,
    required this.onSelect,
  });

  final ZedNavStyle style;
  final List<ZedTab> tabs;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (height, radius, margin) = switch (style) {
      ZedNavStyle.floatingPill => (72.0, 36.0, 16.0),
      ZedNavStyle.expressivePill => (72.0, 36.0, 16.0),
      ZedNavStyle.dock => (72.0, 36.0, 16.0),
      ZedNavStyle.fullBar => (64.0, 0.0, 0.0),
      ZedNavStyle.underline => (64.0, 0.0, 0.0),
      ZedNavStyle.compactDock => (56.0, 28.0, 16.0),
      ZedNavStyle.minimal => (56.0, 28.0, 16.0),
    };
    final showLabels = style != ZedNavStyle.minimal;
    return Container(
      height: height,
      margin: EdgeInsets.symmetric(horizontal: margin),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(i),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: zedFastOutSlowIn,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: i == index
                            ? scheme.secondaryContainer
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Icon(
                        tabs[i].icon,
                        size: 22,
                        color: i == index
                            ? scheme.onSecondaryContainer
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                    if (showLabels) ...[
                      const SizedBox(height: 2),
                      Text(
                        tabs[i].label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: i == index
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: i == index
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Settings kit
// ---------------------------------------------------------------------------

/// A settings section header in the active design's voice.
class ZedSectionHeader extends StatelessWidget {
  const ZedSectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final glass = ZedGlass.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: glass?.label2 ?? scheme.primary,
        ),
      ),
    );
  }
}

/// A settings card in the active design (Bento surface, Pixel tonal
/// container, Glass module surface).
class ZedCard extends StatelessWidget {
  const ZedCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final glass = ZedGlass.of(context);
    final bento = ZedColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final body = Padding(
      padding: padding ?? const EdgeInsets.symmetric(vertical: 4),
      child: child,
    );
    if (glass != null) {
      return GlassSurface(
        tokens: glass,
        radius: BorderRadius.circular(26),
        child: body,
      );
    }
    if (bento != null) {
      // The card shape (corner style) rides in the theme's CardTheme.
      return Material(
        color: bento.surface,
        shape: Theme.of(context).cardTheme.shape,
        child: body,
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: body,
    );
  }
}

/// One settings row: title, optional subtitle, trailing widget.
class ZedSettingRow extends StatelessWidget {
  const ZedSettingRow({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final glass = ZedGlass.of(context);
    final scheme = Theme.of(context).colorScheme;
    final titleColor = glass?.label ?? scheme.onSurface;
    final subColor = glass?.label2 ?? scheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: subColor),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: titleColor,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(fontSize: 12.5, color: subColor),
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// A switch row whose switch matches the active design (Glass uses
/// the GlassSwitch; Bento/Pixel/Old use the Material switch themed
/// by the design's scheme).
class ZedSwitchRow extends StatelessWidget {
  const ZedSwitchRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final glass = ZedGlass.of(context);
    final trailing = glass != null
        ? GlassSwitch(tokens: glass, value: value, onChanged: onChanged)
        : Switch(value: value, onChanged: onChanged);
    return ZedSettingRow(
      title: title,
      subtitle: subtitle,
      icon: icon,
      trailing: trailing,
      onTap: () => onChanged(!value),
    );
  }
}

/// A segmented choice row in the active design's voice.
class ZedSegmentedRow<T> extends StatelessWidget {
  const ZedSegmentedRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.options,
    required this.value,
    required this.onChanged,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final glass = ZedGlass.of(context);
    final scheme = Theme.of(context).colorScheme;
    Widget segment(int i) {
      final (v, label) = options[i];
      final selected = v == value;
      final Color bg;
      final Color fg;
      if (glass != null) {
        bg = selected ? Colors.white : Colors.transparent;
        fg = selected ? const Color(0xFF1C1C1E) : glass.label;
      } else {
        bg = selected ? scheme.secondaryContainer : Colors.transparent;
        fg = selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant;
      }
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: zedFastOutSlowIn,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: fg,
              ),
            ),
          ),
        ),
      );
    }

    final track = glass?.fill ?? scheme.surfaceContainerHighest;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 20,
                  color: glass?.label2 ?? scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: glass?.label ?? scheme.onSurface,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: glass?.label2 ?? scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: track,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [for (var i = 0; i < options.length; i++) segment(i)],
            ),
          ),
        ],
      ),
    );
  }
}

/// A horizontal swatch picker (palettes, tints, accents).
class ZedSwatchRow extends StatelessWidget {
  const ZedSwatchRow({
    super.key,
    required this.title,
    required this.colors,
    required this.selected,
    required this.onSelect,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Color> colors;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final glass = ZedGlass.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: glass?.label ?? scheme.onSurface,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12.5,
                color: glass?.label2 ?? scheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < colors.length; i++)
                GestureDetector(
                  onTap: () => onSelect(i),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: colors[i],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: i == selected
                            ? scheme.primary
                            : scheme.outlineVariant,
                        width: i == selected ? 3 : 1,
                      ),
                    ),
                    child: i == selected
                        ? Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: _readableOn(colors[i]),
                          )
                        : null,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

Color _readableOn(Color bg) =>
    bg.computeLuminance() > 0.45 ? const Color(0xFF14161A) : Colors.white;
