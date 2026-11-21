import 'zed_prefs.dart';

/// The source's own English names for the personalisation values
/// (ZedSecure names its designs, palettes and styles in English in
/// every locale; the row titles around them are localized).
String zedDesignName(ZedDesign d) => switch (d) {
  ZedDesign.bento => 'Bento',
  ZedDesign.pixel => 'Pixel',
  ZedDesign.old => 'Old',
  ZedDesign.glass => 'Glass',
};

String zedTransitionName(ZedTransition t) => switch (t) {
  ZedTransition.fade => 'Fade',
  ZedTransition.slide => 'Slide',
  ZedTransition.push => 'Push',
  ZedTransition.depth => 'Depth',
  ZedTransition.elastic => 'Elastic',
  ZedTransition.curtain => 'Curtain',
  ZedTransition.flip => 'Flip',
};

String zedNavStyleName(ZedNavStyle s) => switch (s) {
  ZedNavStyle.floatingPill => 'Floating pill',
  ZedNavStyle.fullBar => 'Full bar',
  ZedNavStyle.expressivePill => 'Expressive pill',
  ZedNavStyle.compactDock => 'Compact dock',
  ZedNavStyle.underline => 'Underline',
  ZedNavStyle.minimal => 'Minimal',
  ZedNavStyle.dock => 'Dock',
};

String bentoPaletteName(BentoPalette p) => switch (p) {
  BentoPalette.brand => 'Brand',
  BentoPalette.accent => 'Accent',
  BentoPalette.pastel => 'Pastel',
  BentoPalette.vivid => 'Vivid',
  BentoPalette.mono => 'Mono',
  BentoPalette.citrus => 'Citrus',
  BentoPalette.matcha => 'Matcha',
  BentoPalette.neon => 'Neon',
  BentoPalette.pistachio => 'Pistachio',
  BentoPalette.ocean => 'Ocean',
  BentoPalette.sunset => 'Sunset',
  BentoPalette.berry => 'Berry',
};

String bentoCornersName(BentoCorners c) => switch (c) {
  BentoCorners.leaf => 'Leaf',
  BentoCorners.round => 'Round',
  BentoCorners.soft => 'Soft',
};

String bentoTitleSizeName(BentoTitleSize t) => switch (t) {
  BentoTitleSize.huge => 'Huge',
  BentoTitleSize.large => 'Large',
  BentoTitleSize.compact => 'Compact',
};

String bentoDensityName(BentoDensity d) => switch (d) {
  BentoDensity.comfortable => 'Comfortable',
  BentoDensity.compact => 'Compact',
};

String bentoDockLabelsName(BentoDockLabels l) => switch (l) {
  BentoDockLabels.active => 'Active only',
  BentoDockLabels.always => 'Always',
  BentoDockLabels.never => 'Never',
};

String bentoConnectName(BentoConnect c) => switch (c) {
  BentoConnect.slide => 'Slide',
  BentoConnect.button => 'Button',
  BentoConnect.morph => 'Morph',
  BentoConnect.rail => 'Rail',
  BentoConnect.hold => 'Hold',
  BentoConnect.tile => 'Tile',
};

String pixelColorStyleName(PixelColorStyle s) => switch (s) {
  PixelColorStyle.zedSecure => 'ZedSecure',
  PixelColorStyle.tonalSpot => 'Tonal spot',
  PixelColorStyle.vibrant => 'Vibrant',
  PixelColorStyle.expressive => 'Expressive',
  PixelColorStyle.rainbow => 'Rainbow',
  PixelColorStyle.fruitSalad => 'Fruit salad',
  PixelColorStyle.fidelity => 'Fidelity',
  PixelColorStyle.neutral => 'Neutral',
  PixelColorStyle.monochrome => 'Monochrome',
};

String pixelContrastName(PixelContrast c) => switch (c) {
  PixelContrast.standard => 'Standard',
  PixelContrast.medium => 'Medium',
  PixelContrast.high => 'High',
};

String cardCornerStyleName(CardCornerStyle c) => switch (c) {
  CardCornerStyle.squared => 'Squared',
  CardCornerStyle.rounded => 'Rounded',
  CardCornerStyle.pill => 'Pill',
};

String pixelConnectName(PixelConnect c) => switch (c) {
  PixelConnect.pill => 'Pill',
  PixelConnect.hero => 'Hero',
  PixelConnect.ring => 'Ring',
  PixelConnect.bar => 'Bar',
  PixelConnect.icon => 'Icon',
  PixelConnect.switchStyle => 'Switch',
};

String trafficCardStyleName(TrafficCardStyle s) => switch (s) {
  TrafficCardStyle.cards => 'Cards',
  TrafficCardStyle.duo => 'Duo',
  TrafficCardStyle.rings => 'Rings',
  TrafficCardStyle.minimal => 'Minimal',
  TrafficCardStyle.graph => 'Graph',
};

String trafficTileSizeName(TrafficTileSize s) => switch (s) {
  TrafficTileSize.small => 'Small',
  TrafficTileSize.normal => 'Normal',
  TrafficTileSize.large => 'Large',
};

String glassMaterialName(GlassMaterial m) => switch (m) {
  GlassMaterial.clear => 'Clear',
  GlassMaterial.tinted => 'Tinted',
};

String glassWallpaperName(GlassWallpaper w) => switch (w) {
  GlassWallpaper.live => 'Live',
  GlassWallpaper.lagoon => 'Lagoon',
  GlassWallpaper.dusk => 'Dusk',
  GlassWallpaper.graphite => 'Graphite',
  GlassWallpaper.plain => 'Plain',
};

String glassTintName(GlassTint t) => switch (t) {
  GlassTint.blue => 'Blue',
  GlassTint.indigo => 'Indigo',
  GlassTint.purple => 'Purple',
  GlassTint.pink => 'Pink',
  GlassTint.red => 'Red',
  GlassTint.orange => 'Orange',
  GlassTint.green => 'Green',
  GlassTint.mint => 'Mint',
  GlassTint.teal => 'Teal',
  GlassTint.cyan => 'Cyan',
  GlassTint.brown => 'Brown',
  GlassTint.graphite => 'Graphite',
};

String glassConnectName(GlassConnect c) => switch (c) {
  GlassConnect.z => 'Z',
  GlassConnect.button => 'Button',
  GlassConnect.switchStyle => 'Switch',
  GlassConnect.slider => 'Slider',
};
