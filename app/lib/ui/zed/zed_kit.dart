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
    this.cell = false,
  });

  final ZedPrefs prefs;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// A list cell (a [ZedGroup]'s container) rather than a free module:
  /// in Glass, cells follow the `glassLists` preference — off means
  /// the solid-cell form, exactly as the original's theme picks
  /// `solidCell` over the glass module fill for list cells.
  final bool cell;

  /// The hero module: Bento's stage surface (the deep palette colour
  /// the connect control sits on), with the stage's own ink.
  final bool hero;

  @override
  Widget build(BuildContext context) {
    switch (prefs.design) {
      case ZedDesign.glass:
        return GlassModule(
          // A group cell wears the CELL shape (26), a free module
          // the module shape (24) — the flag used to reach only
          // the fill, so group containers rendered at 24 (round 4).
          radius: cell ? GlassTokens.cellRadius : GlassTokens.moduleRadius,
          padding: padding,
          onTap: onTap,
          solid: cell && !prefs.glassLists,
          reduced: prefs.reduceTransparency,
          child: child,
        );
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
                  Theme.of(context).colorScheme.outlineVariant
                      .withValues(alpha: 0.4),
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
    final glass = prefs.design == ZedDesign.glass;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) {
        children.add(
          glass
              // The group draws its own separators in Glass
              // (GlassKit.kt GlassGroup): a 0.5 dp line in the
              // separator token, inset 16 dp from the start side
              // ONLY — the line runs to the trailing edge. Rounds
              // 1–3 used a Material divider inset on both ends in a
              // scheme colour (round 4).
              ? Divider(
                  height: 0.5,
                  thickness: 0.5,
                  indent: 16,
                  endIndent: 0,
                  color: dark
                      ? const Color(0x1FFFFFFF)
                      : const Color(0x293C3C43),
                )
              : Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: Theme.of(context).colorScheme.outlineVariant
                      .withValues(alpha: 0.5),
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
          cell: true,
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
    trailing:
        trailing ??
        (onTap == null ? null : const Icon(Icons.chevron_right_rounded)),
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
    this.shrunk = false,
  });

  final ZedPrefs prefs;
  final List<(IconData, IconData, String)> items;
  final int selected;
  final ValueChanged<int> onSelect;

  /// The collapsed form (the Glass "Shrink tab bar" preference, driven
  /// by the shell's scroll tracking): a shorter, icon-only pill.
  final bool shrunk;

  @override
  Widget build(BuildContext context) {
    // The nav STYLE (full bar / underline) is a Pixel/Old
    // personalization: Glass always gets its glass tab bar and
    // Bento its own dock, whatever the style pref says — the
    // style branch must not run first (round 4; under Glass with
    // a full-bar style the port served a Material NavigationBar
    // and lost the glass pill entirely).
    if (prefs.design == ZedDesign.pixel || prefs.design == ZedDesign.old) {
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
    }
    final scheme = Theme.of(context).colorScheme;
    final bento = prefs.design == ZedDesign.bento
        ? ZedColors.of(context)
        : null;
    // Bento's dock is its own geometry (§1.8): 56 dp bar, 30 dp shape,
    // the palette's dock fill and line, the active item in lime.
    final isBento = bento != null;
    final isGlass = prefs.design == ZedDesign.glass;
    if (isGlass) {
      // The Glass tab bar is its own widget (GlassTabBar.kt): a
      // full-width pill of equal slots with a sliding platter, or
      // the 62 dp current-tab circle in the shrunk (Mini) form —
      // rounds 1–3 squeezed it through the generic dock item
      // (round 4).
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
          child: Row(
            children: [
              if (shrunk)
                _GlassMiniTab(prefs: prefs, items: items, selected: selected, onSelect: onSelect)
              else
                Expanded(
                  child: _GlassTabBar(
                    prefs: prefs,
                    items: items,
                    selected: selected,
                    onSelect: onSelect,
                  ),
                ),
            ],
          ),
        ),
      );
    }
    final pill = Container(
      // Minimum height (see _DockItem): the pill grows with large
      // text instead of clipping its labels.
      constraints: BoxConstraints(minHeight: isBento ? 56 : 62),
      padding: EdgeInsets.symmetric(horizontal: isBento ? 4 : 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            // Bento spaces its items 2 dp apart (BentoDock.kt).
            if (isBento && i > 0) const SizedBox(width: 2),
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
              // BentoDock.kt item metrics: icon 22 in BOTH states,
              // label 14sp SemiBold in both states, horizontal
              // padding 16 with a label / 13 without, min width 50,
              // 7 dp between icon and label (round 4 — the generic
              // item ran 25/22 icons and w700/w600 labels).
              iconSize: isBento ? 22 : null,
              labelFontSize: isBento ? 14 : null,
              labelWeight: isBento ? FontWeight.w600 : null,
              padLabel: isBento ? 16 : null,
              padIcon: isBento ? 13 : null,
              minWidth: isBento ? 50 : null,
              gap: isBento ? 7 : null,
              onTap: () => onSelect(i),
            ),
          ],
        ],
      ),
    );
    final Widget bar = isBento
        ? Container(
            decoration: BoxDecoration(
              color: bento.dock,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: bento.dockLine, width: 1),
              boxShadow: [
                // BentoDock.kt: shadow(10.dp, ink at 18%).
                BoxShadow(
                  color: bento.ink.withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: pill,
          )
        : Material(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(36),
            elevation: 6,
            child: pill,
          );
    // No Center here: as a Scaffold's bottom bar this widget is laid
    // out with loose constraints, and a Center would claim the whole
    // screen height for the bar, leaving the page itself zero height.
    // A centred Row measures as the pill's own height instead.
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, isBento ? 20 : 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [bar],
        ),
      ),
    );
  }
}

/// The Glass tab bar (GlassTabBar.kt), full form: a 62 dp pill
/// spanning the bar's width, inner padding 4, EQUAL slots, and the
/// `platter` token sliding under the selected slot (spring
/// 0.72/MediumLow, as an ease curve here). A cell is the icon (25 dp)
/// over its label (tabLabel: 10sp SemiBold, tracking +0.1, 1 dp gap);
/// the selected cell takes the tint, the rest the label colour. The
/// source's hold-to-scrub magnifier is not ported (documented,
/// round 4): a tap selects on release, as the source's quick tap
/// does.
class _GlassTabBar extends StatelessWidget {
  const _GlassTabBar({
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
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final tint = scheme.primary;
    final labelColor = scheme.onSurface;
    final platter = dark
        ? const Color(0x1CFFFFFF)
        : const Color(0x12000000);
    return GlassChrome(
      prefs: prefs,
      radius: 31,
      child: SizedBox(
        height: 60,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final slot = (constraints.maxWidth - 8) / items.length;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: reduced
                      ? Duration.zero
                      : const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  left: 4 + selected * slot,
                  top: 4,
                  bottom: 4,
                  width: slot,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: platter,
                      borderRadius: BorderRadius.circular(27),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Expanded(
                        child: Semantics(
                          label: items[i].$3,
                          button: true,
                          selected: i == selected,
                          onTap: () => onSelect(i),
                          child: ExcludeSemantics(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => onSelect(i),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    i == selected
                                        ? items[i].$2
                                        : items[i].$1,
                                    size: 25,
                                    color: i == selected
                                        ? tint
                                        : labelColor,
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    items[i].$3,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.1,
                                      color: i == selected
                                          ? tint
                                          : labelColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The Glass tab bar's shrunk (Mini) form: the current tab alone in
/// a 62 dp glass circle, its icon (26 dp) in the tint. Tapping it
/// re-selects the current tab, which is the shell's cue to restore
/// the full bar. (The source pairs it with a search circle; this
/// app has no search tab, so the companion is omitted.)
class _GlassMiniTab extends StatelessWidget {
  const _GlassMiniTab({
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
    final scheme = Theme.of(context).colorScheme;
    final i = selected.clamp(0, items.length - 1);
    return Semantics(
      label: items[i].$3,
      button: true,
      selected: true,
      onTap: () => onSelect(i),
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: () => onSelect(i),
          child: GlassChrome(
            prefs: prefs,
            radius: 31,
            child: SizedBox(
              width: 60,
              height: 60,
              child: Icon(items[i].$2, size: 26, color: scheme.primary),
            ),
          ),
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
    this.iconSize,
    this.labelFontSize,
    this.labelWeight,
    this.padLabel,
    this.padIcon,
    this.minWidth,
    this.gap,
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

  /// Design-exact item metrics (BentoDock.kt), overriding the
  /// generic expressive-pill values when set: a constant icon size
  /// for both states, the label's size and (single) weight, the
  /// horizontal padding with/without a label, a minimum width, and
  /// the icon-label gap.
  final double? iconSize;
  final double? labelFontSize;
  final FontWeight? labelWeight;
  final double? padLabel;
  final double? padIcon;
  final double? minWidth;
  final double? gap;

  @override
  Widget build(BuildContext context) {
    // The selected pill: icon 25 dp, shrinking to 22 in the compact
    // form, with the label expanding beside it (§25 micro-interactions).
    final activeBg = activeColor ?? scheme.secondaryContainer;
    final activeFg = activeForeground ?? scheme.onSecondaryContainer;
    final inactiveFg = inactiveForeground ?? scheme.onSurfaceVariant;
    // One semantics node per destination: the name and the selected
    // state must reach screen readers even when the design hides the
    // labels (icon-only dock), and the visible label must not be
    // announced twice.
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      // The activation action lives HERE: the child's semantics are
      // excluded (so the label is announced once), which also drops
      // the GestureDetector's own semantics action — without onTap
      // on this node a screen-reader user could focus a destination
      // but never switch to it (round-2 DeepSeek finding, ds-01).
      onTap: onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            // A minimum, not a fixed height: at large OS text
            // scales the label must grow the item, not be clipped
            // by it (round-2 DeepSeek finding, ds-01).
            constraints: BoxConstraints(
              minHeight: itemHeight ?? 0,
              minWidth: minWidth ?? 0,
            ),
            padding: EdgeInsets.symmetric(
              horizontal:
                  (showLabel ? padLabel : padIcon) ??
                  (selected && showLabel ? 14 : 10),
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: selected ? activeBg : Colors.transparent,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? selectedIcon : icon,
                  size: iconSize ?? (selected ? 25 : 22),
                  color: selected ? activeFg : inactiveFg,
                ),
                if (showLabel) ...[
                  SizedBox(width: gap ?? 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: labelFontSize,
                      color: selected ? activeFg : inactiveFg,
                      fontWeight:
                          labelWeight ??
                          (selected ? FontWeight.w700 : FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ),
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

  void _handlePointerUp(PointerUpEvent event) => _releasePointer(event.pointer);

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
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      child: widget.child,
    ),
  );
}
