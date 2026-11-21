/// The ZedSecure design system's preference model, reimplemented in Dart
/// from the documented ZedSecure v3.2.0 design system (see
/// ZEDSECURE-MASTER.md §8/§25 in the design study). One settings model,
/// four designs; each design keeps its own sub-preferences, so changing
/// Bento never leaks into Glass — the per-design isolation ZedSecure
/// itself keeps.
///
/// This file is part of the AGPL-3.0 Zed rebuild of the user interface.
/// The design parameters are documented behaviour/geometry, re-expressed
/// in Flutter; no ZedSecure source code is reproduced.
library;

/// The four designs. Bento is the default, as in ZedSecure.
enum ZedDesign { bento, pixel, old, glass }

/// Bento's twelve palettes (§25); [zedLime] (shown as "Brand" in
/// ZedSecure) is the default.
enum BentoPalette {
  zedLime,
  accent,
  pastel,
  vivid,
  mono,
  citrus,
  matcha,
  neon,
  pistachio,
  ocean,
  sunset,
  berry,
}

/// Bento corner styles (§25).
enum BentoCorner { leaf, round, soft }

/// Which dock items carry their label (BentoDockLabels in the
/// original): only the active one, all of them, or none. The port
/// defaults to [always] where the original defaults to active —
/// a deliberate deviation, re-examined in round 3 and kept, for
/// reasons the original's four-destination dock does not face:
/// (1) with only two destinations there is no crowding for Active
/// to relieve — both labels always fit; (2) this app's navigation
/// contract treats both labels as always-present affordances —
/// its widget tests find and tap the dock's Settings label by its
/// text, and switching the default to Active failed seven of them
/// (the gear icon stays visible under Active, but its label is
/// part of how this app's users and tests address the tab);
/// (3) the reference behaviour remains one settings tap away:
/// Active is a stored option, honoured exactly as chosen. Only
/// the DEFAULT differs.
enum BentoDockLabels { active, always, never }

/// Bento connect controls (§25). Slide is the wave-track control with a
/// 0.72 completion threshold; Hold needs a 650 ms press.
enum BentoConnectStyle { slide, button, morph, rail, hold, tile }

/// Glass material (§25).
enum GlassMaterial { clear, tinted }

/// Glass wallpapers (§25).
enum GlassWallpaper { live, lagoon, dusk, graphite, plain }

/// Glass connect controls (§25).
enum GlassConnectStyle { z, button, switchStyle, slider }

/// Pixel/Old connect controls (§25).
enum PixelConnectStyle { pill, hero, ring, bar, icon, switchStyle }

/// Navigation bar styles (§25), shared across designs.
enum NavBarStyle {
  floatingPill,
  fullBar,
  expressivePill,
  compactDock,
  underline,
  minimal,
  dock,
}

/// Screen transition styles (§25). Push is the default.
enum ZedTransitionStyle { fade, slide, push, depth, elastic, curtain, flip }

/// The eleven one-tap theme profiles (§25); [none] is no profile.
enum ZedThemeProfile {
  none,
  aurora,
  ember,
  midnight,
  sakura,
  citrus,
  mono,
  neonlime,
  tokyo,
  solar,
  moss,
  clay,
}

/// All design preferences, grouped per design. Immutable-style: changes
/// go through [copyWith] and the whole object is stored as one JSON map
/// in the app settings file, so a design's block survives untouched
/// while another design is edited.
class ZedPrefs {
  const ZedPrefs({
    this.design = ZedDesign.bento,
    this.bentoPalette = BentoPalette.zedLime,
    // The documented BentoCorners default is Leaf (extract §0) —
    // the port originally defaulted to Round; corrected in round 2.
    this.bentoCorner = BentoCorner.leaf,
    this.bentoConnect = BentoConnectStyle.slide,
    this.bentoDockLabels = BentoDockLabels.always,
    this.bentoAmoled = false,
    this.glassMaterial = GlassMaterial.clear,
    this.glassWallpaper = GlassWallpaper.live,
    this.glassTint = 0,
    this.glassConnect = GlassConnectStyle.z,
    this.glassLists = true,
    this.glassShrinkBar = true,
    // The reference default is OFF (an opt-in flourish); the port
    // originally defaulted this on — corrected in the round-2 review
    // to match the documented GlassPrefs defaults.
    this.glassMotionHighlights = false,
    this.reduceTransparency = false,
    this.glassShowSpeed = true,
    this.glassShowTimer = true,
    this.pixelAccent = 0,
    this.pixelConnect = PixelConnectStyle.hero,
    this.pixelAmoled = false,
    this.oldConnect = PixelConnectStyle.pill,
    this.oldAmoled = false,
    // The documented AppSettings nav-style default is ExpressivePill
    // (extract §0/§3) — corrected in round 2 (was FloatingPill).
    this.navStyle = NavBarStyle.expressivePill,
    this.transitionStyle = ZedTransitionStyle.push,
    this.profile = ZedThemeProfile.none,
  });

  final ZedDesign design;

  // Bento block.
  final BentoPalette bentoPalette;
  final BentoCorner bentoCorner;
  final BentoConnectStyle bentoConnect;
  final BentoDockLabels bentoDockLabels;
  final bool bentoAmoled;

  // Glass block.
  final GlassMaterial glassMaterial;
  final GlassWallpaper glassWallpaper;

  /// Index into the twelve iOS tints (zed_glass.dart).
  final int glassTint;
  final GlassConnectStyle glassConnect;
  final bool glassLists;
  final bool glassShrinkBar;
  final bool glassMotionHighlights;
  final bool reduceTransparency;
  final bool glassShowSpeed;
  final bool glassShowTimer;

  // Pixel block.
  /// Index into the ten accent presets (zed_theme.dart); 0 is Iris.
  final int pixelAccent;
  final PixelConnectStyle pixelConnect;
  final bool pixelAmoled;

  // Old block. Old has a full kit only for Home in ZedSecure; elsewhere
  // it renders with the Pixel/Material kit — the same rule applies here.
  final PixelConnectStyle oldConnect;
  final bool oldAmoled;

  // Global block.
  final NavBarStyle navStyle;
  final ZedTransitionStyle transitionStyle;
  final ZedThemeProfile profile;

  ZedPrefs copyWith({
    ZedDesign? design,
    BentoPalette? bentoPalette,
    BentoCorner? bentoCorner,
    BentoConnectStyle? bentoConnect,
    BentoDockLabels? bentoDockLabels,
    bool? bentoAmoled,
    GlassMaterial? glassMaterial,
    GlassWallpaper? glassWallpaper,
    int? glassTint,
    GlassConnectStyle? glassConnect,
    bool? glassLists,
    bool? glassShrinkBar,
    bool? glassMotionHighlights,
    bool? reduceTransparency,
    bool? glassShowSpeed,
    bool? glassShowTimer,
    int? pixelAccent,
    PixelConnectStyle? pixelConnect,
    bool? pixelAmoled,
    PixelConnectStyle? oldConnect,
    bool? oldAmoled,
    NavBarStyle? navStyle,
    ZedTransitionStyle? transitionStyle,
    ZedThemeProfile? profile,
  }) => ZedPrefs(
    design: design ?? this.design,
    bentoPalette: bentoPalette ?? this.bentoPalette,
    bentoCorner: bentoCorner ?? this.bentoCorner,
    bentoConnect: bentoConnect ?? this.bentoConnect,
    bentoDockLabels: bentoDockLabels ?? this.bentoDockLabels,
    bentoAmoled: bentoAmoled ?? this.bentoAmoled,
    glassMaterial: glassMaterial ?? this.glassMaterial,
    glassWallpaper: glassWallpaper ?? this.glassWallpaper,
    glassTint: glassTint ?? this.glassTint,
    glassConnect: glassConnect ?? this.glassConnect,
    glassLists: glassLists ?? this.glassLists,
    glassShrinkBar: glassShrinkBar ?? this.glassShrinkBar,
    glassMotionHighlights: glassMotionHighlights ?? this.glassMotionHighlights,
    reduceTransparency: reduceTransparency ?? this.reduceTransparency,
    glassShowSpeed: glassShowSpeed ?? this.glassShowSpeed,
    glassShowTimer: glassShowTimer ?? this.glassShowTimer,
    pixelAccent: pixelAccent ?? this.pixelAccent,
    pixelConnect: pixelConnect ?? this.pixelConnect,
    pixelAmoled: pixelAmoled ?? this.pixelAmoled,
    oldConnect: oldConnect ?? this.oldConnect,
    oldAmoled: oldAmoled ?? this.oldAmoled,
    navStyle: navStyle ?? this.navStyle,
    transitionStyle: transitionStyle ?? this.transitionStyle,
    profile: profile ?? this.profile,
  );

  Map<String, Object?> toJson() => {
    'design': design.name,
    'bento': {
      'palette': bentoPalette.name,
      'corner': bentoCorner.name,
      'connect': bentoConnect.name,
      'dock_labels': bentoDockLabels.name,
      'amoled': bentoAmoled,
    },
    'glass': {
      'material': glassMaterial.name,
      'wallpaper': glassWallpaper.name,
      'tint': glassTint,
      'connect': glassConnect.name,
      'lists': glassLists,
      'shrink_bar': glassShrinkBar,
      'motion_highlights': glassMotionHighlights,
      'reduce_transparency': reduceTransparency,
      'show_speed': glassShowSpeed,
      'show_timer': glassShowTimer,
    },
    'pixel': {
      'accent': pixelAccent,
      'connect': pixelConnect.name,
      'amoled': pixelAmoled,
    },
    'old': {'connect': oldConnect.name, 'amoled': oldAmoled},
    'nav_style': navStyle.name,
    'transition': transitionStyle.name,
    'profile': profile.name,
  };

  static T _enum<T extends Enum>(List<T> values, Object? name, T fallback) =>
      name is String ? (values.asNameMap()[name] ?? fallback) : fallback;

  /// Reads a stored block; anything missing or unknown falls back to the
  /// defaults, so a settings file from before this model existed (or a
  /// partially written one) can never break the design system.
  factory ZedPrefs.fromJson(Map<String, Object?>? j) {
    if (j == null) return const ZedPrefs();
    Map<String, Object?> block(String key) =>
        j[key] is Map<String, Object?> ? j[key]! as Map<String, Object?> : {};
    final bento = block('bento');
    final glass = block('glass');
    final pixel = block('pixel');
    final old = block('old');
    int index(Object? v, int max) => v is int && v >= 0 && v < max ? v : 0;
    return ZedPrefs(
      design: _enum(ZedDesign.values, j['design'], ZedDesign.bento),
      bentoPalette: _enum(
        BentoPalette.values,
        bento['palette'],
        BentoPalette.zedLime,
      ),
      bentoCorner: _enum(BentoCorner.values, bento['corner'], BentoCorner.leaf),
      bentoConnect: _enum(
        BentoConnectStyle.values,
        bento['connect'],
        BentoConnectStyle.slide,
      ),
      bentoDockLabels: _enum(
        BentoDockLabels.values,
        bento['dock_labels'],
        BentoDockLabels.always,
      ),
      bentoAmoled: bento['amoled'] == true,
      glassMaterial: _enum(
        GlassMaterial.values,
        glass['material'],
        GlassMaterial.clear,
      ),
      glassWallpaper: _enum(
        GlassWallpaper.values,
        glass['wallpaper'],
        GlassWallpaper.live,
      ),
      glassTint: index(glass['tint'], 12),
      glassConnect: _enum(
        GlassConnectStyle.values,
        glass['connect'],
        GlassConnectStyle.z,
      ),
      glassLists: glass['lists'] != false,
      glassShrinkBar: glass['shrink_bar'] != false,
      glassMotionHighlights: glass['motion_highlights'] == true,
      reduceTransparency: glass['reduce_transparency'] == true,
      glassShowSpeed: glass['show_speed'] != false,
      glassShowTimer: glass['show_timer'] != false,
      pixelAccent: index(pixel['accent'], 10),
      pixelConnect: _enum(
        PixelConnectStyle.values,
        pixel['connect'],
        PixelConnectStyle.hero,
      ),
      pixelAmoled: pixel['amoled'] == true,
      oldConnect: _enum(
        PixelConnectStyle.values,
        old['connect'],
        PixelConnectStyle.pill,
      ),
      oldAmoled: old['amoled'] == true,
      navStyle: _enum(
        NavBarStyle.values,
        j['nav_style'],
        NavBarStyle.expressivePill,
      ),
      transitionStyle: _enum(
        ZedTransitionStyle.values,
        j['transition'],
        ZedTransitionStyle.push,
      ),
      profile: _enum(
        ZedThemeProfile.values,
        j['profile'],
        ZedThemeProfile.none,
      ),
    );
  }
}
