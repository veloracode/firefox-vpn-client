import 'package:material_ui/material_ui.dart';

import 'zed_glass.dart';
import 'zed_prefs.dart';
import 'zed_theme.dart';

/// The shared kit every screen is built from, one variant per design —
/// the "designs swap per-screen kits, not branches inside composables"
/// rule (§8), applied at the component level: a screen asks for a
/// [ZedModule] or a [ZedGroup] and gets Bento's shaped surface, Glass's
/// simulated glass, or Pixel/Old's Material card, according to the
/// current design.

/// A module: the unit cards and groups are made of (Bento 24 dp /
/// Glass 24 dp module radius, cells 26 in Glass groups).
class ZedModule extends StatelessWidget {
  const ZedModule({
    super.key,
    required this.prefs,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.hero = false,
  });

  final ZedPrefs prefs;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// The hero module: Bento's stage surface (the deep palette colour
  /// the connect control sits on), with the stage's own ink.
  final bool hero;

  @override
  Widget build(BuildContext context) {
    switch (prefs.design) {
      case ZedDesign.glass:
        return GlassModule(padding: padding, onTap: onTap, child: child);
      case ZedDesign.bento:
        final tokens = ZedColors.of(context);
        final radius = hero
            ? bentoHeroRadius(prefs.bentoCorner)
            : bentoModuleRadius(prefs.bentoCorner);
        final fill = hero && tokens != null
            ? tokens.stage
            : Theme.of(context).cardTheme.color;
        Widget content = Padding(padding: padding, child: child);
        if (hero && tokens != null) {
          content = DefaultTextStyle.merge(
            style: TextStyle(color: tokens.onStage),
            child: IconTheme.merge(
              data: IconThemeData(color: tokens.onStage),
              child: content,
            ),
          );
        }
        final material = Material(
          color: fill,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color:
                  tokens?.line ??
                  Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: InkWell(
            onTap: onTap,
            customBorder: RoundedRectangleBorder(borderRadius: radius),
            child: content,
          ),
        );
        // Bento's press is a 0.965 shrink on a spring (§1.5),
        // observed through a Listener so the InkWell keeps the tap.
        if (onTap == null) return material;
        return _PressScale(scale: 0.965, child: material);
      case ZedDesign.pixel:
      case ZedDesign.old:
        final card = Card(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: Padding(padding: padding, child: child),
          ),
        );
        if (onTap == null) return card;
        return _PressScale(scale: 0.985, child: card);
    }
  }
}

/// A titled group of rows inside one module, with group-drawn
/// separators (one shape per group — the glass performance rule, and
/// Bento's grouped look).
class ZedGroup extends StatelessWidget {
  const ZedGroup({
    super.key,
    required this.prefs,
    required this.rows,
    this.title,
  });

  final ZedPrefs prefs;
  final List<Widget> rows;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) {
        children.add(
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        );
      }
      children.add(rows[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              title!,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ZedModule(
          prefs: prefs,
          padding: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }
}

/// One row inside a [ZedGroup]: icon, title, optional subtitle and
/// trailing, the whole row tappable.
class ZedRow extends StatelessWidget {
  const ZedRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: trailing ?? (onTap == null ? null : const Icon(Icons.chevron_right_rounded)),
    onTap: onTap,
  );
}

/// The mobile dock, per nav style (§25). The dock is built OUTSIDE the
/// page transition by the shell; Glass always gets its real-glass
/// chrome pill. [items] are (icon, selectedIcon, label) triples.
class ZedDock extends StatelessWidget {
  const ZedDock({
    super.key,
    required this.prefs,
    required this.items,
    required this.selected,
    required this.onSelect,
  });

  final ZedPrefs prefs;
  final List<(IconData, IconData, String)> items;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    if (prefs.navStyle == NavBarStyle.fullBar ||
        prefs.navStyle == NavBarStyle.underline) {
      return NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: onSelect,
        destinations: [
          for (var i = 0; i < items.length; i++)
            NavigationDestination(
              icon: Icon(items[i].$1),
              selectedIcon: Icon(items[i].$2),
              label: items[i].$3,
            ),
        ],
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final bento = prefs.design == ZedDesign.bento
        ? ZedColors.of(context)
        : null;
    // Bento's dock is its own geometry (§1.8): 56 dp bar, 30 dp shape,
    // the palette's dock fill and line, the active item in lime.
    final isBento = bento != null;
    final pill = Container(
      height: isBento ? 56 : GlassTokens.dockHeight,
      padding: EdgeInsets.symmetric(horizontal: isBento ? 4 : 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++)
            _DockItem(
              icon: items[i].$1,
              selectedIcon: items[i].$2,
              label: items[i].$3,
              selected: i == selected,
              // Bento follows its dock-labels setting (active item
              // only by default); the other designs name every
              // destination except in the two compact styles.
              showLabel: isBento
                  ? switch (prefs.bentoDockLabels) {
                      BentoDockLabels.active => i == selected,
                      BentoDockLabels.always => true,
                      BentoDockLabels.never => false,
                    }
                  : prefs.navStyle != NavBarStyle.minimal &&
                        prefs.navStyle != NavBarStyle.compactDock,
              scheme: scheme,
              activeColor: bento?.lime,
              activeForeground: bento?.onLime,
              inactiveForeground: bento?.muted,
              itemHeight: isBento ? 48 : null,
              onTap: () => onSelect(i),
            ),
        ],
      ),
    );
    final Widget bar = prefs.design == ZedDesign.glass
        ? GlassChrome(prefs: prefs, radius: 36, child: pill)
        : Material(
            color: bento?.dock ?? scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(isBento ? 30 : 36),
            elevation: 6,
            child: isBento
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: bento.dockLine, width: 1),
                    ),
                    child: pill,
                  )
                : pill,
          );
    // No Center here: as a Scaffold's bottom bar this widget is laid
    // out with loose constraints, and a Center would claim the whole
    // screen height for the bar, leaving the page itself zero height.
    // A centred Row measures as the pill's own height instead.
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          prefs.design == ZedDesign.glass ? 22 : (isBento ? 20 : 10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [bar],
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.showLabel,
    required this.scheme,
    required this.onTap,
    this.activeColor,
    this.activeForeground,
    this.inactiveForeground,
    this.itemHeight,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final bool showLabel;
  final ColorScheme scheme;
  final VoidCallback onTap;

  /// The active item's own colours when the design gives the dock a
  /// palette (Bento: lime on lime-ink); null falls back to the scheme's
  /// secondary container.
  final Color? activeColor;
  final Color? activeForeground;
  final Color? inactiveForeground;
  final double? itemHeight;

  @override
  Widget build(BuildContext context) {
    // The selected pill: icon 25 dp, shrinking to 22 in the compact
    // form, with the label expanding beside it (§25 micro-interactions).
    final activeBg = activeColor ?? scheme.secondaryContainer;
    final activeFg = activeForeground ?? scheme.onSecondaryContainer;
    final inactiveFg = inactiveForeground ?? scheme.onSurfaceVariant;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        height: itemHeight,
        padding: EdgeInsets.symmetric(horizontal: selected && showLabel ? 14 : 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? selectedIcon : icon,
              size: selected ? 25 : 22,
              color: selected ? activeFg : inactiveFg,
            ),
            if (showLabel) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? activeFg : inactiveFg,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


/// A press-shrink observed through a [Listener]: pointer events are
/// watched, never claimed, so an inner InkWell or button still gets
/// its tap exactly once (a nested GestureDetector would steal the
/// arena and swallow it). Tracks active pointer ids so lifting one of
/// several fingers does not clear the shrink while another remains down.
class _PressScale extends StatefulWidget {
  const _PressScale({required this.scale, required this.child});

  final double scale;
  final Widget child;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  final Set<int> _activePointers = <int>{};

  bool get _down => _activePointers.isNotEmpty;

  void _handlePointerDown(PointerDownEvent event) {
    if (!mounted) return;
    final wasDown = _down;
    _activePointers.add(event.pointer);
    if (!wasDown) setState(() {});
  }

  void _handlePointerUp(PointerUpEvent event) =>
      _releasePointer(event.pointer);

  void _handlePointerCancel(PointerCancelEvent event) =>
      _releasePointer(event.pointer);

  void _releasePointer(int pointer) {
    if (!mounted) return;
    final wasDown = _down;
    _activePointers.remove(pointer);
    if (wasDown != _down) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _handlePointerDown,
    onPointerUp: _handlePointerUp,
    onPointerCancel: _handlePointerCancel,
    child: AnimatedScale(
      scale: _down ? widget.scale : 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      child: widget.child,
    ),
  );
}
