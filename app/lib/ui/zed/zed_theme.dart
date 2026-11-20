import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:material_ui/material_ui.dart';

import '../widgets.dart' show languageFont;
import 'zed_prefs.dart';

/// The ZedSecure design system's theme builder, reimplemented in Dart
/// from the documented v3.2.0 design system (ZEDSECURE-MASTER.md §8/§25)
/// with the exact tokens of ZED-TOKENS-EXTRACT.md. Four designs over
/// one settings model: Bento resolves its twelve palettes to the
/// original's exact `BentoColors` (eight hardcoded, four derived from
/// HCT tonal palettes), Pixel/Old take an accent seed, Glass its tint.
/// AMOLED rewrites surfaces towards true black.


/// One Bento palette fully resolved for one brightness — the exact
/// `BentoColors` field set of the original (ZED-TOKENS-EXTRACT §1.1):
/// the ground the page sits on, the surfaces modules are made of, the
/// stage the hero module wears, the lime accent, the dock's own fill.
class BentoTokens {
  const BentoTokens({
    required this.ground,
    required this.surface,
    required this.surface2,
    required this.line,
    required this.ink,
    required this.muted,
    required this.stage,
    required this.onStage,
    required this.chipOnStage,
    required this.goodOnStage,
    required this.lime,
    required this.onLime,
    required this.good,
    required this.mid,
    required this.bad,
    required this.selected,
    required this.dock,
    required this.dockLine,
    required this.danger,
    required this.onDanger,
  });

  final Color ground;
  final Color surface;
  final Color surface2;
  final Color line;
  final Color ink;
  final Color muted;
  final Color stage;
  final Color onStage;
  final Color chipOnStage;
  final Color goodOnStage;
  final Color lime;
  final Color onLime;
  final Color good;
  final Color mid;
  final Color bad;
  final Color selected;
  final Color dock;
  final Color dockLine;
  final Color danger;
  final Color onDanger;

  /// The welcome screen's palette dot colour.
  Color get seed => lime;

  BentoTokens copyWith({
    Color? ground,
    Color? surface,
    Color? surface2,
    Color? dock,
  }) => BentoTokens(
    ground: ground ?? this.ground,
    surface: surface ?? this.surface,
    surface2: surface2 ?? this.surface2,
    line: line,
    ink: ink,
    muted: muted,
    stage: stage,
    onStage: onStage,
    chipOnStage: chipOnStage,
    goodOnStage: goodOnStage,
    lime: lime,
    onLime: onLime,
    good: good,
    mid: mid,
    bad: bad,
    selected: selected,
    dock: dock ?? this.dock,
    dockLine: dockLine,
    danger: danger,
    onDanger: onDanger,
  );
}

/// The eight hardcoded palettes, dark (§1.2 of the extract).
const _bentoDark = <BentoPalette, BentoTokens>{
  BentoPalette.zedLime: BentoTokens(
    ground: Color(0xFF0B0A10), surface: Color(0xFF18161F), surface2: Color(0xFF24212D),
    line: Color(0xFF3A3646), ink: Color(0xFFEEEAF6), muted: Color(0xFFA6A0B8),
    stage: Color(0xFF311B6B), onStage: Color(0xFFEFE8FF), chipOnStage: Color(0x1FFFFFFF),
    goodOnStage: Color(0xFF9BF0AE), lime: Color(0xFFC7F24E), onLime: Color(0xFF1A2200),
    good: Color(0xFF7BE495), mid: Color(0xFFF2C14E), bad: Color(0xFFFF8A80),
    selected: Color(0xFF2B1D57), dock: Color(0xFF1E1B27), dockLine: Color(0x24FFFFFF),
    danger: Color(0xFFFFB4AB), onDanger: Color(0xFF690005),
  ),
  BentoPalette.citrus: BentoTokens(
    ground: Color(0xFF0C0D07), surface: Color(0xFF181A0F), surface2: Color(0xFF23261A),
    line: Color(0xFF3A3D2A), ink: Color(0xFFF1F2E4), muted: Color(0xFFB0B39A),
    stage: Color(0xFF2D3A0B), onStage: Color(0xFFEEF8CF), chipOnStage: Color(0x1FFFFFFF),
    goodOnStage: Color(0xFF9BF0AE), lime: Color(0xFFE2F53A), onLime: Color(0xFF1F2400),
    good: Color(0xFF7BE495), mid: Color(0xFFF2C14E), bad: Color(0xFFFF8A80),
    selected: Color(0xFF3A4A12), dock: Color(0xFF23261A), dockLine: Color(0x24FFFFFF),
    danger: Color(0xFFFFB4AB), onDanger: Color(0xFF690005),
  ),
  BentoPalette.matcha: BentoTokens(
    ground: Color(0xFF0A0D0A), surface: Color(0xFF151A15), surface2: Color(0xFF20271F),
    line: Color(0xFF364034), ink: Color(0xFFE8F0E6), muted: Color(0xFFA3B09F),
    stage: Color(0xFF1F3D27), onStage: Color(0xFFDDF3E2), chipOnStage: Color(0x1FFFFFFF),
    goodOnStage: Color(0xFF9BF0AE), lime: Color(0xFFB4E36B), onLime: Color(0xFF172600),
    good: Color(0xFF7BE495), mid: Color(0xFFF2C14E), bad: Color(0xFFFF8A80),
    selected: Color(0xFF28452F), dock: Color(0xFF20271F), dockLine: Color(0x24FFFFFF),
    danger: Color(0xFFFFB4AB), onDanger: Color(0xFF690005),
  ),
  BentoPalette.neon: BentoTokens(
    ground: Color(0xFF08070C), surface: Color(0xFF15131C), surface2: Color(0xFF201D2A),
    line: Color(0xFF383346), ink: Color(0xFFF2EEFA), muted: Color(0xFFABA3BF),
    stage: Color(0xFF3D0B4F), onStage: Color(0xFFFBDDFF), chipOnStage: Color(0x1FFFFFFF),
    goodOnStage: Color(0xFF9BF0AE), lime: Color(0xFFB9FF3B), onLime: Color(0xFF142400),
    good: Color(0xFF7BE495), mid: Color(0xFFF2C14E), bad: Color(0xFFFF8A80),
    selected: Color(0xFF4A1060), dock: Color(0xFF201D2A), dockLine: Color(0x24FFFFFF),
    danger: Color(0xFFFFB4AB), onDanger: Color(0xFF690005),
  ),
  BentoPalette.pistachio: BentoTokens(
    ground: Color(0xFF0B0C0A), surface: Color(0xFF171915), surface2: Color(0xFF22251F),
    line: Color(0xFF393D34), ink: Color(0xFFEEF1E9), muted: Color(0xFFA8AE9F),
    stage: Color(0xFF2B2348), onStage: Color(0xFFE9E2FF), chipOnStage: Color(0x1FFFFFFF),
    goodOnStage: Color(0xFF9BF0AE), lime: Color(0xFFD3F2A2), onLime: Color(0xFF1E2A08),
    good: Color(0xFF7BE495), mid: Color(0xFFF2C14E), bad: Color(0xFFFF8A80),
    selected: Color(0xFF352C57), dock: Color(0xFF22251F), dockLine: Color(0x24FFFFFF),
    danger: Color(0xFFFFB4AB), onDanger: Color(0xFF690005),
  ),
  BentoPalette.ocean: BentoTokens(
    ground: Color(0xFF070B10), surface: Color(0xFF121923), surface2: Color(0xFF1C2431),
    line: Color(0xFF313D4F), ink: Color(0xFFE7EEF8), muted: Color(0xFF9FAABD),
    stage: Color(0xFF0E2F57), onStage: Color(0xFFD8E9FF), chipOnStage: Color(0x1FFFFFFF),
    goodOnStage: Color(0xFF9BF0AE), lime: Color(0xFF5CF2C8), onLime: Color(0xFF00281D),
    good: Color(0xFF7BE495), mid: Color(0xFFF2C14E), bad: Color(0xFFFF8A80),
    selected: Color(0xFF123A6A), dock: Color(0xFF1C2431), dockLine: Color(0x24FFFFFF),
    danger: Color(0xFFFFB4AB), onDanger: Color(0xFF690005),
  ),
  BentoPalette.sunset: BentoTokens(
    ground: Color(0xFF0E0A09), surface: Color(0xFF1C1513), surface2: Color(0xFF28201D),
    line: Color(0xFF43362F), ink: Color(0xFFF8EDE8), muted: Color(0xFFBBA79E),
    stage: Color(0xFF4A1F12), onStage: Color(0xFFFFE3D6), chipOnStage: Color(0x1FFFFFFF),
    goodOnStage: Color(0xFF9BF0AE), lime: Color(0xFFFFB547), onLime: Color(0xFF2E1800),
    good: Color(0xFF7BE495), mid: Color(0xFFF2C14E), bad: Color(0xFFFF8A80),
    selected: Color(0xFF5A2A18), dock: Color(0xFF28201D), dockLine: Color(0x24FFFFFF),
    danger: Color(0xFFFFB4AB), onDanger: Color(0xFF690005),
  ),
  BentoPalette.berry: BentoTokens(
    ground: Color(0xFF0D080C), surface: Color(0xFF1B1219), surface2: Color(0xFF271B24),
    line: Color(0xFF42303D), ink: Color(0xFFF7EAF2), muted: Color(0xFFB8A2B0),
    stage: Color(0xFF4A0E3A), onStage: Color(0xFFFFD9F2), chipOnStage: Color(0x1FFFFFFF),
    goodOnStage: Color(0xFF9BF0AE), lime: Color(0xFFD7F59A), onLime: Color(0xFF1E2A06),
    good: Color(0xFF7BE495), mid: Color(0xFFF2C14E), bad: Color(0xFFFF8A80),
    selected: Color(0xFF5A1548), dock: Color(0xFF271B24), dockLine: Color(0x24FFFFFF),
    danger: Color(0xFFFFB4AB), onDanger: Color(0xFF690005),
  ),
};

/// The eight hardcoded palettes, light (§1.3 of the extract).
const _bentoLight = <BentoPalette, BentoTokens>{
  BentoPalette.zedLime: BentoTokens(
    ground: Color(0xFFF6F6F0), surface: Color(0xFFEAEAE2), surface2: Color(0xFFDCDCD2),
    line: Color(0xFFC5C5BA), ink: Color(0xFF16161C), muted: Color(0xFF55555F),
    stage: Color(0xFF2A1361), onStage: Color(0xFFF1EBFF), chipOnStage: Color(0x24FFFFFF),
    goodOnStage: Color(0xFF9BF0AE), lime: Color(0xFFC7F24E), onLime: Color(0xFF1A2200),
    good: Color(0xFF16803F), mid: Color(0xFF8A5A00), bad: Color(0xFFB3261E),
    selected: Color(0xFFE3DBFF), dock: Color(0xFFFFFFFF), dockLine: Color(0x1A16161C),
    danger: Color(0xFFFFDAD6), onDanger: Color(0xFF410002),
  ),
  BentoPalette.citrus: BentoTokens(
    ground: Color(0xFFF7F8EC), surface: Color(0xFFEBEDDB), surface2: Color(0xFFDEE1C9),
    line: Color(0xFFC6C9AE), ink: Color(0xFF17180F), muted: Color(0xFF565A44),
    stage: Color(0xFF2D3A0B), onStage: Color(0xFFF2FBD6), chipOnStage: Color(0x24FFFFFF),
    goodOnStage: Color(0xFF9BF0AE), lime: Color(0xFFD8EE2C), onLime: Color(0xFF1F2400),
    good: Color(0xFF16803F), mid: Color(0xFF8A5A00), bad: Color(0xFFB3261E),
    selected: Color(0xFFE5F0B8), dock: Color(0xFFFFFFFF), dockLine: Color(0x1A16161C),
    danger: Color(0xFFFFDAD6), onDanger: Color(0xFF410002),
  ),
  BentoPalette.matcha: BentoTokens(
    ground: Color(0xFFF4F7F2), surface: Color(0xFFE7EDE4), surface2: Color(0xFFD9E1D5),
    line: Color(0xFFBFC9BB), ink: Color(0xFF141A13), muted: Color(0xFF4E594B),
    stage: Color(0xFF1F3D27), onStage: Color(0xFFE2F6E7), chipOnStage: Color(0x24FFFFFF),
    goodOnStage: Color(0xFF9BF0AE), lime: Color(0xFFA6D65A), onLime: Color(0xFF172600),
    good: Color(0xFF16803F), mid: Color(0xFF8A5A00), bad: Color(0xFFB3261E),
    selected: Color(0xFFD6EAD9), dock: Color(0xFFFFFFFF), dockLine: Color(0x1A16161C),
    danger: Color(0xFFFFDAD6), onDanger: Color(0xFF410002),
  ),
  BentoPalette.neon: BentoTokens(
    ground: Color(0xFFF8F6FB), surface: Color(0xFFECE8F2), surface2: Color(0xFFDED8E8),
    line: Color(0xFFC5BDD3), ink: Color(0xFF15121C), muted: Color(0xFF554C66),
    stage: Color(0xFF3D0B4F), onStage: Color(0xFFFCE2FF), chipOnStage: Color(0x24FFFFFF),
    goodOnStage: Color(0xFF9BF0AE), lime: Color(0xFFA8F21E), onLime: Color(0xFF142400),
    good: Color(0xFF16803F), mid: Color(0xFF8A5A00), bad: Color(0xFFB3261E),
    selected: Color(0xFFF1DDF7), dock: Color(0xFFFFFFFF), dockLine: Color(0x1A16161C),
    danger: Color(0xFFFFDAD6), onDanger: Color(0xFF410002),
  ),
  BentoPalette.pistachio: BentoTokens(
    ground: Color(0xFFF6F7F2), surface: Color(0xFFEAECE3), surface2: Color(0xFFDDE0D4),
    line: Color(0xFFC4C8BA), ink: Color(0xFF151713), muted: Color(0xFF535849),
    stage: Color(0xFF2B2348), onStage: Color(0xFFEEE8FF), chipOnStage: Color(0x24FFFFFF),
    goodOnStage: Color(0xFF9BF0AE), lime: Color(0xFFC6EB8A), onLime: Color(0xFF1E2A08),
    good: Color(0xFF16803F), mid: Color(0xFF8A5A00), bad: Color(0xFFB3261E),
    selected: Color(0xFFE3DDF7), dock: Color(0xFFFFFFFF), dockLine: Color(0x1A16161C),
    danger: Color(0xFFFFDAD6), onDanger: Color(0xFF410002),
  ),
  BentoPalette.ocean: BentoTokens(
    ground: Color(0xFFF3F7FB), surface: Color(0xFFE4EBF3), surface2: Color(0xFFD5DEE9),
    line: Color(0xFFB9C5D4), ink: Color(0xFF0F1620), muted: Color(0xFF4A5768),
    stage: Color(0xFF0E2F57), onStage: Color(0xFFDDEBFF), chipOnStage: Color(0x24FFFFFF),
    goodOnStage: Color(0xFF9BF0AE), lime: Color(0xFF3BE0B4), onLime: Color(0xFF00281D),
    good: Color(0xFF16803F), mid: Color(0xFF8A5A00), bad: Color(0xFFB3261E),
    selected: Color(0xFFD6E5F7), dock: Color(0xFFFFFFFF), dockLine: Color(0x1A16161C),
    danger: Color(0xFFFFDAD6), onDanger: Color(0xFF410002),
  ),
  BentoPalette.sunset: BentoTokens(
    ground: Color(0xFFFBF6F3), surface: Color(0xFFF1E8E3), surface2: Color(0xFFE5D9D2),
    line: Color(0xFFCDBDB4), ink: Color(0xFF1C1310), muted: Color(0xFF64514A),
    stage: Color(0xFF4A1F12), onStage: Color(0xFFFFE6DA), chipOnStage: Color(0x24FFFFFF),
    goodOnStage: Color(0xFF9BF0AE), lime: Color(0xFFFFA62B), onLime: Color(0xFF2E1800),
    good: Color(0xFF16803F), mid: Color(0xFF8A5A00), bad: Color(0xFFB3261E),
    selected: Color(0xFFF5DCD0), dock: Color(0xFFFFFFFF), dockLine: Color(0x1A16161C),
    danger: Color(0xFFFFDAD6), onDanger: Color(0xFF410002),
  ),
  BentoPalette.berry: BentoTokens(
    ground: Color(0xFFFBF5F8), surface: Color(0xFFF1E6EC), surface2: Color(0xFFE5D6DF),
    line: Color(0xFFCDB9C5), ink: Color(0xFF1C1018), muted: Color(0xFF634C5A),
    stage: Color(0xFF4A0E3A), onStage: Color(0xFFFFDDF3), chipOnStage: Color(0x24FFFFFF),
    goodOnStage: Color(0xFF9BF0AE), lime: Color(0xFFC4EC7C), onLime: Color(0xFF1E2A06),
    good: Color(0xFF16803F), mid: Color(0xFF8A5A00), bad: Color(0xFFB3261E),
    selected: Color(0xFFF5D8E9), dock: Color(0xFFFFFFFF), dockLine: Color(0x1A16161C),
    danger: Color(0xFFFFDAD6), onDanger: Color(0xFF410002),
  ),
};

/// The canonical accent seeds the four algorithmic palettes derive
/// from (the original derives them from the user's accent colour; the
/// port's presets are these fixed seeds).
const _algorithmicSeeds = <BentoPalette, int>{
  BentoPalette.accent: 0xFF5B5BD6,
  BentoPalette.pastel: 0xFFD77FA1,
  BentoPalette.vivid: 0xFFE64A19,
  BentoPalette.mono: 0xFF616161,
};

Color _tone(TonalPalette p, int t) => Color(p.get(t));

/// The original's `tonal()` (§1.4): every colour is an HCT tone of a
/// handful of tonal palettes built from the seed's hue.
BentoTokens _tonalTokens(int seedArgb, bool dark, BentoPalette kind) {
  final seed = Hct.fromInt(seedArgb);
  final hue = seed.hue;
  final seedChroma = seed.chroma;
  final (accentChroma, stageChroma) = switch (kind) {
    BentoPalette.accent => (seedChroma > 56 ? seedChroma : 56.0, 64.0),
    BentoPalette.pastel => (40.0, 40.0),
    _ => (92.0, 64.0), // vivid
  };
  final neutral = TonalPalette.of(hue, 6);
  final neutralVariant = TonalPalette.of(hue, 10);
  final accent = TonalPalette.of(hue, accentChroma);
  final stage = TonalPalette.of(hue, stageChroma);
  final goodP = TonalPalette.of(145, 48);
  final midP = TonalPalette.of(80, 60);
  final badP = TonalPalette.of(25, 70);
  int t(int d, int l) => dark ? d : l;
  return BentoTokens(
    ground: _tone(neutral, t(4, 97)),
    surface: _tone(neutral, t(10, 92)),
    surface2: _tone(neutral, t(15, 87)),
    line: _tone(neutralVariant, t(26, 78)),
    ink: _tone(neutral, t(93, 8)),
    muted: _tone(neutralVariant, t(70, 36)),
    stage: _tone(stage, t(22, 18)),
    onStage: _tone(stage, t(92, 95)),
    chipOnStage: Colors.white.withValues(alpha: dark ? 0.12 : 0.14),
    goodOnStage: _tone(goodP, 88),
    lime: _tone(accent, 88),
    onLime: _tone(accent, 14),
    good: _tone(goodP, t(80, 40)),
    mid: _tone(midP, t(80, 42)),
    bad: _tone(badP, t(72, 40)),
    selected: _tone(stage, t(20, 90)),
    dock: _tone(neutral, t(13, 99)),
    dockLine: (dark ? Colors.white : Colors.black).withValues(
      alpha: dark ? 0.08 : 0.10,
    ),
    danger: _tone(badP, t(80, 90)),
    onDanger: _tone(badP, t(20, 10)),
  );
}

/// The original's `mono()` (§1.4): one near-neutral palette.
BentoTokens _monoTokens(int seedArgb, bool dark) {
  final hue = Hct.fromInt(seedArgb).hue;
  final n = TonalPalette.of(hue, 3);
  final goodP = TonalPalette.of(145, 40);
  final midP = TonalPalette.of(80, 50);
  final badP = TonalPalette.of(25, 64);
  int t(int d, int l) => dark ? d : l;
  return BentoTokens(
    ground: _tone(n, t(4, 97)),
    surface: _tone(n, t(10, 92)),
    surface2: _tone(n, t(16, 86)),
    line: _tone(n, t(27, 76)),
    ink: _tone(n, t(94, 8)),
    muted: _tone(n, t(70, 36)),
    stage: _tone(n, t(22, 16)),
    onStage: _tone(n, t(95, 96)),
    chipOnStage: Colors.white.withValues(alpha: 0.12),
    goodOnStage: _tone(goodP, 88),
    lime: _tone(n, t(94, 12)),
    onLime: _tone(n, t(8, 96)),
    good: _tone(goodP, t(80, 38)),
    mid: _tone(midP, t(80, 40)),
    bad: _tone(badP, t(72, 40)),
    selected: _tone(n, t(20, 84)),
    dock: _tone(n, t(13, 99)),
    dockLine: (dark ? Colors.white : Colors.black).withValues(
      alpha: dark ? 0.08 : 0.10,
    ),
    danger: _tone(badP, t(80, 90)),
    onDanger: _tone(badP, t(20, 10)),
  );
}

/// Resolves a palette for a brightness, with the AMOLED override the
/// original applies to every palette in the dark (pure-black ground).
BentoTokens bentoTokensFor(BentoPalette palette, bool dark, {bool amoled = false}) {
  var tokens = switch (palette) {
    BentoPalette.accent || BentoPalette.pastel || BentoPalette.vivid =>
      _tonalTokens(_algorithmicSeeds[palette]!, dark, palette),
    BentoPalette.mono => _monoTokens(_algorithmicSeeds[palette]!, dark),
    _ => (dark ? _bentoDark : _bentoLight)[palette]!,
  };
  if (amoled && dark) {
    tokens = tokens.copyWith(
      ground: const Color(0xFF000000),
      surface: const Color(0xFF111015),
      surface2: const Color(0xFF1B1A21),
      dock: const Color(0xFF141319),
    );
  }
  return tokens;
}

/// The light tokens of every palette, for pickers that show a dot of
/// each (the welcome screen).
final bentoPalettes = <BentoPalette, BentoTokens>{
  for (final p in BentoPalette.values) p: bentoTokensFor(p, false),
};

/// The Bento tokens as a theme extension, so the kit (modules, dock,
/// hero stage) reads the palette's own colours, not scheme stand-ins.
/// Present only under the Bento design.
class ZedColors extends ThemeExtension<ZedColors> {
  const ZedColors(this.tokens);

  final BentoTokens tokens;

  @override
  ZedColors copyWith({BentoTokens? tokens}) => ZedColors(tokens ?? this.tokens);

  @override
  ZedColors lerp(ZedColors? other, double t) =>
      t < 0.5 ? this : (other ?? this);

  static BentoTokens? of(BuildContext context) =>
      Theme.of(context).extension<ZedColors>()?.tokens;
}

/// Pixel/Old's ten accent presets (§25). Iris is the default.
const pixelAccents = <Color>[
  Color(0xFF5646D6), // Iris
  Color(0xFF0277BD), // Ocean
  Color(0xFF00897B), // Teal
  Color(0xFF2E7D32), // Forest
  Color(0xFFFF8F00), // Amber
  Color(0xFFE91E63), // Rose
  Color(0xFFC62828), // Crimson
  Color(0xFF00ACC1), // Cyan
  Color(0xFF7B1FA2), // Grape
  Color(0xFF546E7A), // Slate
];

/// Corner radius for a design's modules: Bento follows its corner style
/// (Leaf is asymmetric — see [bentoModuleShape]), Pixel/Old follow the
/// personalization corner style, Glass modules are always 24.
double zedModuleRadius(ZedPrefs prefs) => switch (prefs.design) {
  ZedDesign.bento => switch (prefs.bentoCorner) {
    BentoCorner.leaf => 36,
    BentoCorner.round => 36,
    BentoCorner.soft => 24,
  },
  ZedDesign.glass => 24,
  ZedDesign.pixel || ZedDesign.old => 22,
};

/// Bento's module (tile) shape, exact (§1.5): Leaf is the asymmetric
/// (36, 36, 36, 12), Round a uniform 36, Soft a uniform 24. The Leaf
/// corners are directional (start/end), so the small corner mirrors
/// to the start side in RTL instead of staying physical-left.
BorderRadiusGeometry bentoModuleRadius(BentoCorner corner) => switch (corner) {
  BentoCorner.leaf => const BorderRadiusDirectional.only(
    topStart: Radius.circular(36),
    topEnd: Radius.circular(36),
    bottomEnd: Radius.circular(36),
    bottomStart: Radius.circular(12),
  ),
  BentoCorner.round => BorderRadius.circular(36),
  BentoCorner.soft => BorderRadius.circular(24),
};

/// Bento's hero shape (§1.5): Leaf (34, 34, 34, 12), Round 34, Soft 22.
BorderRadiusGeometry bentoHeroRadius(BentoCorner corner) => switch (corner) {
  BentoCorner.leaf => const BorderRadiusDirectional.only(
    topStart: Radius.circular(34),
    topEnd: Radius.circular(34),
    bottomEnd: Radius.circular(34),
    bottomStart: Radius.circular(12),
  ),
  BentoCorner.round => BorderRadius.circular(34),
  BentoCorner.soft => BorderRadius.circular(22),
};

abstract final class ZedTheme {
  /// Builds the app's [ThemeData] for [prefs] at [brightness]; [locale]
  /// picks the font exactly as the app's theme always has.
  static ThemeData build(
    Brightness brightness,
    Locale locale,
    ZedPrefs prefs,
  ) {
    final dark = brightness == Brightness.dark;
    final font = languageFont(locale.languageCode);
    final bento = bentoTokensFor(
      prefs.bentoPalette,
      dark,
      amoled: prefs.bentoAmoled,
    );
    final (scheme, bg, surface) = switch (prefs.design) {
      ZedDesign.bento => (
        ColorScheme(
          brightness: brightness,
          primary: bento.lime,
          onPrimary: bento.onLime,
          primaryContainer: bento.selected,
          onPrimaryContainer: bento.ink,
          secondary: bento.stage,
          onSecondary: bento.onStage,
          secondaryContainer: bento.selected,
          onSecondaryContainer: bento.ink,
          tertiary: bento.stage,
          onTertiary: bento.onStage,
          error: dark ? bento.danger : const Color(0xFFB3261E),
          onError: dark ? bento.onDanger : Colors.white,
          errorContainer: bento.danger,
          onErrorContainer: bento.onDanger,
          surface: bento.surface,
          onSurface: bento.ink,
          onSurfaceVariant: bento.muted,
          surfaceContainerLowest: bento.ground,
          surfaceContainerLow: bento.surface,
          surfaceContainer: bento.surface2,
          surfaceContainerHigh: bento.surface2,
          surfaceContainerHighest: bento.surface2,
          outline: bento.line,
          outlineVariant: bento.line,
          inverseSurface: bento.ink,
          onInverseSurface: bento.ground,
          inversePrimary: bento.stage,
          shadow: Colors.black,
          scrim: Colors.black,
        ),
        bento.ground,
        bento.surface,
      ),
      ZedDesign.pixel => _accentScheme(
        pixelAccents[prefs.pixelAccent],
        brightness,
        amoled: prefs.pixelAmoled,
      ),
      ZedDesign.old => _accentScheme(
        pixelAccents[prefs.pixelAccent],
        brightness,
        amoled: prefs.oldAmoled,
      ),
      ZedDesign.glass => (
        ColorScheme.fromSeed(
          seedColor: glassTintColor(prefs.glassTint, dark),
          brightness: brightness,
          dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
        ),
        Colors.transparent,
        // The module fill, exact (§2.1): reduced transparency is the
        // solid cell; Tinted ≈ 86%/84%; Clear 38% dark / 50% light.
        prefs.reduceTransparency
            ? (dark ? const Color(0xFF1C1C1E) : Colors.white)
            : switch (prefs.glassMaterial) {
                GlassMaterial.tinted =>
                  dark ? const Color(0xDB28282C) : const Color(0xD6FFFFFF),
                GlassMaterial.clear =>
                  dark ? const Color(0x612C2C30) : const Color(0x80FFFFFF),
              },
      ),
    };
    final radius = zedModuleRadius(prefs);
    return ThemeData(
      extensions: [
        if (prefs.design == ZedDesign.bento) ZedColors(bento),
      ],
      colorScheme: scheme,
      fontFamily: font,
      scaffoldBackgroundColor: bg,
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        shape: RoundedRectangleBorder(
          // Bento cards take the design's own module shape (the Leaf
          // asymmetry included); the other designs use their uniform
          // module radius.
          borderRadius: prefs.design == ZedDesign.bento
              ? bentoModuleRadius(prefs.bentoCorner)
              : BorderRadius.circular(radius),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: dark
            ? Color.alphaBlend(
                scheme.surface.withValues(alpha: 0.6),
                const Color(0xFF0B0B0F),
              )
            : surface,
        selectedLabelTextStyle: TextStyle(
          fontFamily: font,
          fontSize: 15.5,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontFamily: font,
          fontSize: 15.5,
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        ),
        selectedIconTheme: IconThemeData(
          size: 24,
          color: scheme.onSecondaryContainer,
        ),
        unselectedIconTheme: IconThemeData(
          size: 24,
          color: scheme.onSurfaceVariant,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: scheme.secondaryContainer,
      ),
    );
  }

  static (ColorScheme, Color, Color) _accentScheme(
    Color accent,
    Brightness brightness, {
    required bool amoled,
  }) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
    );
    if (amoled && dark) {
      return (scheme, Colors.black, const Color(0xFF0A0A0A));
    }
    return (
      scheme,
      dark ? const Color(0xFF111218) : const Color(0xFFF5F5FA),
      dark ? const Color(0xFF1A1B23) : Colors.white,
    );
  }
}

/// The twelve iOS tints for Glass, by index — the dark values
/// (ZED-TOKENS-EXTRACT §2.5).
const glassTintColors = <Color>[
  Color(0xFF0091FF), // blue
  Color(0xFF30D158), // green
  Color(0xFF00D2E0), // teal
  Color(0xFFFF9230), // orange
  Color(0xFFFF375F), // pink
  Color(0xFFDB34F2), // purple
  Color(0xFFFF4245), // red
  Color(0xFFFFD600), // yellow
  Color(0xFF00DAC3), // mint
  Color(0xFF6D7CFF), // indigo
  Color(0xFFB78A66), // brown
  Color(0xFF98989D), // graphite
];

/// The same twelve tints in their light values (§2.5).
const glassTintColorsLight = <Color>[
  Color(0xFF0088FF),
  Color(0xFF34C759),
  Color(0xFF00C3D0),
  Color(0xFFFF8D28),
  Color(0xFFFF2D55),
  Color(0xFFCB30E0),
  Color(0xFFFF383C),
  Color(0xFFFFCC00),
  Color(0xFF00C8B3),
  Color(0xFF6155F5),
  Color(0xFFAC7F5E),
  Color(0xFF8E8E93),
];

/// A Glass tint by index, in the brightness's own value.
Color glassTintColor(int index, bool dark) =>
    (dark ? glassTintColors : glassTintColorsLight)[index.clamp(
      0,
      glassTintColors.length - 1,
    )];
