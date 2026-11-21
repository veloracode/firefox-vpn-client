import '../../app_settings.dart';

/// The ZedSecure v3.2.0 design-system preferences, reimplemented from
/// `domain/model/AppSettings.kt`, `BentoPrefs.kt` and `GlassPrefs.kt`.
///
/// One model, four designs. Stored as a single JSON object under the
/// `zed` key of app-settings.json (see [AppSettings.zed]); every field
/// independently defaulted on read, so a missing or corrupt value can
/// never break the rest — the same persistence discipline ZedSecure
/// uses for its field-by-field store.

enum ZedDesign { bento, pixel, old, glass }

enum ZedTransition { fade, slide, push, depth, elastic, curtain, flip }

enum ZedNavStyle {
  floatingPill,
  fullBar,
  expressivePill,
  compactDock,
  underline,
  minimal,
  dock,
}

enum BentoPalette {
  brand,
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

enum BentoCorners { leaf, round, soft }

enum BentoTitleSize { huge, large, compact }

enum BentoDensity { comfortable, compact }

enum BentoDockLabels { active, always, never }

enum BentoConnect { slide, button, morph, rail, hold, tile }

enum PixelColorStyle {
  zedSecure,
  tonalSpot,
  vibrant,
  expressive,
  rainbow,
  fruitSalad,
  fidelity,
  neutral,
  monochrome,
}

enum PixelContrast { standard, medium, high }

enum CardCornerStyle { squared, rounded, pill }

enum PixelConnect { pill, hero, ring, bar, icon, switchStyle }

enum TrafficCardStyle { cards, duo, rings, minimal, graph }

enum TrafficTileSize { small, normal, large }

enum GlassMaterial { clear, tinted }

enum GlassWallpaper { live, lagoon, dusk, graphite, plain }

/// Source order in `GlassPrefs.kt`: Blue, Indigo, Purple, Pink, Red,
/// Orange, Green, Mint, Teal, Cyan, Brown, Graphite.
enum GlassTint {
  blue,
  indigo,
  purple,
  pink,
  red,
  orange,
  green,
  mint,
  teal,
  cyan,
  brown,
  graphite,
}

enum GlassConnect { z, button, switchStyle, slider }

T _enum<T extends Enum>(List<T> values, Object? raw, T fallback) =>
    raw is String ? (values.asNameMap()[raw] ?? fallback) : fallback;

bool _bool(Object? raw, bool fallback) => raw is bool ? raw : fallback;

int _int(Object? raw, int fallback) => raw is int ? raw : fallback;

/// Nullable variants for the custom-colour/profile fields: a corrupt
/// or legacy value of the wrong type reads as "unset", never throws.
int? _intOrNull(Object? raw) => raw is int ? raw : null;
String? _stringOrNull(Object? raw) => raw is String ? raw : null;

class BentoPrefs {
  BentoPrefs({
    this.palette = BentoPalette.brand,
    this.corners = BentoCorners.leaf,
    this.title = BentoTitleSize.large,
    this.density = BentoDensity.comfortable,
    this.dockLabels = BentoDockLabels.active,
    this.dockAutoHide = true,
    this.navStyle = ZedNavStyle.dock,
    this.connect = BentoConnect.slide,
    this.motifs = true,
    this.playfulTouch = true,
    this.indexes = true,
    this.liveTiles = true,
    this.wave = true,
    this.homeSpeed = true,
    this.homeSession = true,
    this.homeQuick = true,
    this.homeChips = true,
    this.amoled = false,
  });

  BentoPalette palette;
  BentoCorners corners;
  BentoTitleSize title;
  BentoDensity density;
  BentoDockLabels dockLabels;
  bool dockAutoHide;
  ZedNavStyle navStyle;
  BentoConnect connect;
  bool motifs;
  bool playfulTouch;
  bool indexes;
  bool liveTiles;
  bool wave;
  bool homeSpeed;
  bool homeSession;
  bool homeQuick;
  bool homeChips;
  bool amoled;

  factory BentoPrefs.fromJson(Map<String, Object?> j) => BentoPrefs(
    palette: _enum(BentoPalette.values, j['palette'], BentoPalette.brand),
    corners: _enum(BentoCorners.values, j['corners'], BentoCorners.leaf),
    title: _enum(BentoTitleSize.values, j['title'], BentoTitleSize.large),
    density: _enum(BentoDensity.values, j['density'], BentoDensity.comfortable),
    dockLabels: _enum(
      BentoDockLabels.values,
      j['dock_labels'],
      BentoDockLabels.active,
    ),
    dockAutoHide: _bool(j['dock_auto_hide'], true),
    navStyle: _enum(ZedNavStyle.values, j['nav_style'], ZedNavStyle.dock),
    connect: _enum(BentoConnect.values, j['connect'], BentoConnect.slide),
    motifs: _bool(j['motifs'], true),
    playfulTouch: _bool(j['playful_touch'], true),
    indexes: _bool(j['indexes'], true),
    liveTiles: _bool(j['live_tiles'], true),
    wave: _bool(j['wave'], true),
    homeSpeed: _bool(j['home_speed'], true),
    homeSession: _bool(j['home_session'], true),
    homeQuick: _bool(j['home_quick'], true),
    homeChips: _bool(j['home_chips'], true),
    amoled: _bool(j['amoled'], false),
  );

  Map<String, Object?> toJson() => {
    'palette': palette.name,
    'corners': corners.name,
    'title': title.name,
    'density': density.name,
    'dock_labels': dockLabels.name,
    'dock_auto_hide': dockAutoHide,
    'nav_style': navStyle.name,
    'connect': connect.name,
    'motifs': motifs,
    'playful_touch': playfulTouch,
    'indexes': indexes,
    'live_tiles': liveTiles,
    'wave': wave,
    'home_speed': homeSpeed,
    'home_session': homeSession,
    'home_quick': homeQuick,
    'home_chips': homeChips,
    'amoled': amoled,
  };

  BentoPrefs copy() => BentoPrefs.fromJson(toJson());
}

/// The personalisation model Pixel and Old share in ZedSecure; each
/// design keeps its own instance so Old's accent row is independent
/// of Pixel's (its settings block is its own).
class PixelPrefs {
  PixelPrefs({
    this.accentIndex = 0,
    this.colorStyle = PixelColorStyle.zedSecure,
    this.contrast = PixelContrast.standard,
    this.amoled = false,
    this.cornerStyle = CardCornerStyle.rounded,
    this.connect = PixelConnect.hero,
    this.trafficStyle = TrafficCardStyle.cards,
    this.trafficTileSize = TrafficTileSize.normal,
    this.customDownload,
    this.customUpload,
    this.customDownloadTile,
    this.customUploadTile,
    this.customConnect,
    this.customConnected,
    this.customTapHint,
    this.customServerCard,
    this.customServerActive,
    this.customConfigCard,
    this.customConfigCardText,
    this.profileId = '',
  });

  int accentIndex;
  PixelColorStyle colorStyle;
  PixelContrast contrast;
  bool amoled;
  CardCornerStyle cornerStyle;
  PixelConnect connect;
  TrafficCardStyle trafficStyle;
  TrafficTileSize trafficTileSize;
  int? customDownload;
  int? customUpload;
  int? customDownloadTile;
  int? customUploadTile;
  int? customConnect;
  int? customConnected;
  int? customTapHint;
  int? customServerCard;
  int? customServerActive;
  int? customConfigCard;
  int? customConfigCardText;
  String profileId;

  double get contrastLevel => switch (contrast) {
    PixelContrast.standard => 0.0,
    PixelContrast.medium => 0.5,
    PixelContrast.high => 1.0,
  };

  factory PixelPrefs.fromJson(Map<String, Object?> j) => PixelPrefs(
    accentIndex: _int(j['accent'], 0).clamp(0, 9),
    colorStyle: _enum(
      PixelColorStyle.values,
      j['color_style'],
      PixelColorStyle.zedSecure,
    ),
    contrast: _enum(
      PixelContrast.values,
      j['contrast'],
      PixelContrast.standard,
    ),
    amoled: _bool(j['amoled'], false),
    cornerStyle: _enum(
      CardCornerStyle.values,
      j['corner_style'],
      CardCornerStyle.rounded,
    ),
    connect: _enum(PixelConnect.values, j['connect'], PixelConnect.hero),
    trafficStyle: _enum(
      TrafficCardStyle.values,
      j['traffic_style'],
      TrafficCardStyle.cards,
    ),
    trafficTileSize: _enum(
      TrafficTileSize.values,
      j['traffic_tile_size'],
      TrafficTileSize.normal,
    ),
    customDownload: _intOrNull(j['c_download']),
    customUpload: _intOrNull(j['c_upload']),
    customDownloadTile: _intOrNull(j['c_download_tile']),
    customUploadTile: _intOrNull(j['c_upload_tile']),
    customConnect: _intOrNull(j['c_connect']),
    customConnected: _intOrNull(j['c_connected']),
    customTapHint: _intOrNull(j['c_tap_hint']),
    customServerCard: _intOrNull(j['c_server_card']),
    customServerActive: _intOrNull(j['c_server_active']),
    customConfigCard: _intOrNull(j['c_config_card']),
    customConfigCardText: _intOrNull(j['c_config_card_text']),
    profileId: _stringOrNull(j['profile']) ?? '',
  );

  Map<String, Object?> toJson() => {
    'accent': accentIndex,
    'color_style': colorStyle.name,
    'contrast': contrast.name,
    'amoled': amoled,
    'corner_style': cornerStyle.name,
    'connect': connect.name,
    'traffic_style': trafficStyle.name,
    'traffic_tile_size': trafficTileSize.name,
    'c_download': customDownload,
    'c_upload': customUpload,
    'c_download_tile': customDownloadTile,
    'c_upload_tile': customUploadTile,
    'c_connect': customConnect,
    'c_connected': customConnected,
    'c_tap_hint': customTapHint,
    'c_server_card': customServerCard,
    'c_server_active': customServerActive,
    'c_config_card': customConfigCard,
    'c_config_card_text': customConfigCardText,
    'profile': profileId,
  };

  PixelPrefs copy() => PixelPrefs.fromJson(toJson());
}

class GlassPrefs {
  GlassPrefs({
    this.material = GlassMaterial.clear,
    this.wallpaper = GlassWallpaper.live,
    this.tint = GlassTint.blue,
    this.connect = GlassConnect.z,
    this.glassLists = true,
    this.shrinkTabBar = true,
    this.motionHighlights = false,
    this.reduceTransparency = false,
    this.homeSpeed = true,
    this.homeTimer = true,
    this.homeCard = true,
  });

  GlassMaterial material;
  GlassWallpaper wallpaper;
  GlassTint tint;
  GlassConnect connect;
  bool glassLists;
  bool shrinkTabBar;
  bool motionHighlights;
  bool reduceTransparency;
  bool homeSpeed;
  bool homeTimer;
  bool homeCard;

  /// The single flag that turns rim+highlight on for cells
  /// (`GlassPrefs.translucent` in the source).
  bool get translucent => glassLists && !reduceTransparency;

  factory GlassPrefs.fromJson(Map<String, Object?> j) => GlassPrefs(
    material: _enum(GlassMaterial.values, j['material'], GlassMaterial.clear),
    wallpaper: _enum(
      GlassWallpaper.values,
      j['wallpaper'],
      GlassWallpaper.live,
    ),
    tint: _enum(GlassTint.values, j['tint'], GlassTint.blue),
    connect: _enum(GlassConnect.values, j['connect'], GlassConnect.z),
    glassLists: _bool(j['glass_lists'], true),
    shrinkTabBar: _bool(j['shrink_tab_bar'], true),
    motionHighlights: _bool(j['motion_highlights'], false),
    reduceTransparency: _bool(j['reduce_transparency'], false),
    homeSpeed: _bool(j['home_speed'], true),
    homeTimer: _bool(j['home_timer'], true),
    homeCard: _bool(j['home_card'], true),
  );

  Map<String, Object?> toJson() => {
    'material': material.name,
    'wallpaper': wallpaper.name,
    'tint': tint.name,
    'connect': connect.name,
    'glass_lists': glassLists,
    'shrink_tab_bar': shrinkTabBar,
    'motion_highlights': motionHighlights,
    'reduce_transparency': reduceTransparency,
    'home_speed': homeSpeed,
    'home_timer': homeTimer,
    'home_card': homeCard,
  };

  GlassPrefs copy() => GlassPrefs.fromJson(toJson());
}

class ZedPrefs {
  ZedPrefs({
    this.design = ZedDesign.bento,
    this.transition = ZedTransition.push,
    this.navStyle = ZedNavStyle.expressivePill,
    this.reduceMotion = false,
    BentoPrefs? bento,
    PixelPrefs? pixel,
    PixelPrefs? old,
    GlassPrefs? glass,
  }) : bento = bento ?? BentoPrefs(),
       pixel = pixel ?? PixelPrefs(),
       old = old ?? PixelPrefs(),
       glass = glass ?? GlassPrefs();

  ZedDesign design;
  ZedTransition transition;
  ZedNavStyle navStyle;
  bool reduceMotion;
  BentoPrefs bento;
  PixelPrefs pixel;
  PixelPrefs old;
  GlassPrefs glass;

  /// The personalisation block of the design that uses one.
  PixelPrefs get activePixel => design == ZedDesign.old ? old : pixel;

  factory ZedPrefs.fromJson(Map<String, Object?> j) {
    Map<String, Object?> sub(String key) =>
        j[key] is Map<String, Object?> ? j[key] as Map<String, Object?> : {};
    return ZedPrefs(
      design: _enum(ZedDesign.values, j['design'], ZedDesign.bento),
      transition: _enum(
        ZedTransition.values,
        j['transition'],
        ZedTransition.push,
      ),
      navStyle: _enum(
        ZedNavStyle.values,
        j['nav_style'],
        ZedNavStyle.expressivePill,
      ),
      reduceMotion: _bool(j['reduce_motion'], false),
      bento: BentoPrefs.fromJson(sub('bento')),
      pixel: PixelPrefs.fromJson(sub('pixel')),
      old: PixelPrefs.fromJson(sub('old')),
      glass: GlassPrefs.fromJson(sub('glass')),
    );
  }

  Map<String, Object?> toJson() => {
    'design': design.name,
    'transition': transition.name,
    'nav_style': navStyle.name,
    'reduce_motion': reduceMotion,
    'bento': bento.toJson(),
    'pixel': pixel.toJson(),
    'old': old.toJson(),
    'glass': glass.toJson(),
  };

  ZedPrefs copy() => ZedPrefs.fromJson(toJson());
}

/// The bridge between [AppSettings] (persistence) and [ZedPrefs].
extension ZedSettings on AppSettings {
  ZedPrefs get zedPrefs => ZedPrefs.fromJson(zed);

  void setZed(ZedPrefs prefs) => update(zed: prefs.toJson());
}
