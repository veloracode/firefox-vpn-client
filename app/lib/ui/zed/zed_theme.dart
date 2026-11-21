import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:material_ui/material_ui.dart';

import '../widgets.dart' show languageFont;
import 'zed_prefs.dart';

/// The ZedSecure v3.2.0 design system's theme layer, reimplemented in
/// Dart from the Kotlin source (`ui/bento/BentoPalette.kt`,
/// `ui/bento/BentoTheme.kt`, `ui/glass/GlassTheme.kt`,
/// `ui/theme/Personalization.kt`, `ui/theme/Theme.kt`). Values are the
/// source's own; where the source computes a colour (HCT tonal
/// palettes), the same algorithm runs here — no guessed hexes.

/// A (container, content) colour pair — the original's `BentoTone`.
class BentoTone {
  const BentoTone(this.container, this.content);

  final Color container;
  final Color content;
}

/// One Bento palette fully resolved for one brightness — the exact
/// `BentoColors` field set of `BentoPalette.kt`.
class BentoTokens {
  const BentoTokens({
    required this.dark,
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
    required this.blue,
    required this.violet,
    required this.cyan,
    required this.pink,
    required this.coral,
    required this.good,
    required this.mid,
    required this.bad,
    required this.selected,
    required this.dock,
    required this.dockLine,
    required this.danger,
    required this.onDanger,
    required this.colorful,
  });

  final bool dark;
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
  final BentoTone blue;
  final BentoTone violet;
  final BentoTone cyan;
  final BentoTone pink;
  final BentoTone coral;
  final Color good;
  final Color mid;
  final Color bad;
  final Color selected;
  final Color dock;
  final Color dockLine;
  final Color danger;
  final Color onDanger;
  final bool colorful;

  /// `BentoColors.pingColor`: ms<=0 → bad; <300 → good; <800 → mid.
  Color pingColor(int ms) =>
      ms <= 0 ? bad : (ms < 300 ? good : (ms < 800 ? mid : bad));

  BentoTokens copyWith({
    Color? ground,
    Color? surface,
    Color? surface2,
    Color? dock,
  }) => BentoTokens(
    dark: dark,
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
    blue: blue,
    violet: violet,
    cyan: cyan,
    pink: pink,
    coral: coral,
    good: good,
    mid: mid,
    bad: bad,
    selected: selected,
    dock: dock ?? this.dock,
    dockLine: dockLine,
    danger: danger,
    onDanger: onDanger,
    colorful: colorful,
  );
}

BentoTokens _dark({
  required Color ground,
  required Color surface,
  required Color surface2,
  required Color line,
  required Color ink,
  required Color muted,
  required Color stage,
  required Color onStage,
  required Color lime,
  required Color onLime,
  required BentoTone blue,
  required BentoTone violet,
  required BentoTone cyan,
  required BentoTone pink,
  required BentoTone coral,
  required Color selected,
  required Color dock,
  required bool colorful,
}) => BentoTokens(
  dark: true,
  ground: ground,
  surface: surface,
  surface2: surface2,
  line: line,
  ink: ink,
  muted: muted,
  stage: stage,
  onStage: onStage,
  chipOnStage: const Color(0x1FFFFFFF),
  goodOnStage: const Color(0xFF9BF0AE),
  lime: lime,
  onLime: onLime,
  blue: blue,
  violet: violet,
  cyan: cyan,
  pink: pink,
  coral: coral,
  good: const Color(0xFF7BE495),
  mid: const Color(0xFFF2C14E),
  bad: const Color(0xFFFF8A80),
  selected: selected,
  dock: dock,
  dockLine: const Color(0x24FFFFFF),
  danger: const Color(0xFFFFB4AB),
  onDanger: const Color(0xFF690005),
  colorful: colorful,
);

BentoTokens _light({
  required Color ground,
  required Color surface,
  required Color surface2,
  required Color line,
  required Color ink,
  required Color muted,
  required Color stage,
  required Color onStage,
  required Color lime,
  required Color onLime,
  required BentoTone blue,
  required BentoTone violet,
  required BentoTone cyan,
  required BentoTone pink,
  required BentoTone coral,
  required Color selected,
  required bool colorful,
}) => BentoTokens(
  dark: false,
  ground: ground,
  surface: surface,
  surface2: surface2,
  line: line,
  ink: ink,
  muted: muted,
  stage: stage,
  onStage: onStage,
  chipOnStage: const Color(0x24FFFFFF),
  goodOnStage: const Color(0xFF9BF0AE),
  lime: lime,
  onLime: onLime,
  blue: blue,
  violet: violet,
  cyan: cyan,
  pink: pink,
  coral: coral,
  good: const Color(0xFF16803F),
  mid: const Color(0xFF8A5A00),
  bad: const Color(0xFFB3261E),
  selected: selected,
  dock: const Color(0xFFFFFFFF),
  dockLine: const Color(0x1A16161C),
  danger: const Color(0xFFFFDAD6),
  onDanger: const Color(0xFF410002),
  colorful: colorful,
);

/// The eight hardcoded palettes, dark (`BentoPalette.kt` §1.2 values).
final _bentoDark = <BentoPalette, BentoTokens>{
  BentoPalette.brand: _dark(
    ground: const Color(0xFF0B0A10),
    surface: const Color(0xFF18161F),
    surface2: const Color(0xFF24212D),
    line: const Color(0xFF3A3646),
    ink: const Color(0xFFEEEAF6),
    muted: const Color(0xFFA6A0B8),
    stage: const Color(0xFF311B6B),
    onStage: const Color(0xFFEFE8FF),
    lime: const Color(0xFFC7F24E),
    onLime: const Color(0xFF1A2200),
    blue: const BentoTone(Color(0xFF15294A), Color(0xFFCFE1FF)),
    violet: const BentoTone(Color(0xFF2A2352), Color(0xFFDDD5FF)),
    cyan: const BentoTone(Color(0xFF103D3A), Color(0xFFB3F1EC)),
    pink: const BentoTone(Color(0xFF4A1C35), Color(0xFFFFD0E5)),
    coral: const BentoTone(Color(0xFF4A251D), Color(0xFFFFD3C6)),
    selected: const Color(0xFF2B1D57),
    dock: const Color(0xFF1E1B27),
    colorful: false,
  ),
  BentoPalette.citrus: _dark(
    ground: const Color(0xFF0C0D07),
    surface: const Color(0xFF181A0F),
    surface2: const Color(0xFF23261A),
    line: const Color(0xFF3A3D2A),
    ink: const Color(0xFFF1F2E4),
    muted: const Color(0xFFB0B39A),
    stage: const Color(0xFF2D3A0B),
    onStage: const Color(0xFFEEF8CF),
    lime: const Color(0xFFE2F53A),
    onLime: const Color(0xFF1F2400),
    blue: const BentoTone(Color(0xFF3B3608), Color(0xFFFFF3A1)),
    violet: const BentoTone(Color(0xFF123A2A), Color(0xFFB9F5D7)),
    cyan: const BentoTone(Color(0xFF22370F), Color(0xFFD3F5A7)),
    pink: const BentoTone(Color(0xFF40280C), Color(0xFFFFD6A6)),
    coral: const BentoTone(Color(0xFF43201A), Color(0xFFFFC8BC)),
    selected: const Color(0xFF3A4A12),
    dock: const Color(0xFF23261A),
    colorful: true,
  ),
  BentoPalette.matcha: _dark(
    ground: const Color(0xFF0A0D0A),
    surface: const Color(0xFF151A15),
    surface2: const Color(0xFF20271F),
    line: const Color(0xFF364034),
    ink: const Color(0xFFE8F0E6),
    muted: const Color(0xFFA3B09F),
    stage: const Color(0xFF1F3D27),
    onStage: const Color(0xFFDDF3E2),
    lime: const Color(0xFFB4E36B),
    onLime: const Color(0xFF172600),
    blue: const BentoTone(Color(0xFF1E3326), Color(0xFFCDEDD6)),
    violet: const BentoTone(Color(0xFF2C3416), Color(0xFFE1EFB6)),
    cyan: const BentoTone(Color(0xFF0F393A), Color(0xFFB2EDEE)),
    pink: const BentoTone(Color(0xFF3D2619), Color(0xFFF4CDB6)),
    coral: const BentoTone(Color(0xFF36301E), Color(0xFFF2E6C2)),
    selected: const Color(0xFF28452F),
    dock: const Color(0xFF20271F),
    colorful: true,
  ),
  BentoPalette.neon: _dark(
    ground: const Color(0xFF08070C),
    surface: const Color(0xFF15131C),
    surface2: const Color(0xFF201D2A),
    line: const Color(0xFF383346),
    ink: const Color(0xFFF2EEFA),
    muted: const Color(0xFFABA3BF),
    stage: const Color(0xFF3D0B4F),
    onStage: const Color(0xFFFBDDFF),
    lime: const Color(0xFFB9FF3B),
    onLime: const Color(0xFF142400),
    blue: const BentoTone(Color(0xFF4A0E3B), Color(0xFFFFC1EA)),
    violet: const BentoTone(Color(0xFF07344A), Color(0xFFA3EAFF)),
    cyan: const BentoTone(Color(0xFF2B1657), Color(0xFFE1D0FF)),
    pink: const BentoTone(Color(0xFF373A08), Color(0xFFF8FFA0)),
    coral: const BentoTone(Color(0xFF4A1810), Color(0xFFFFC5B5)),
    selected: const Color(0xFF4A1060),
    dock: const Color(0xFF201D2A),
    colorful: true,
  ),
  BentoPalette.pistachio: _dark(
    ground: const Color(0xFF0B0C0A),
    surface: const Color(0xFF171915),
    surface2: const Color(0xFF22251F),
    line: const Color(0xFF393D34),
    ink: const Color(0xFFEEF1E9),
    muted: const Color(0xFFA8AE9F),
    stage: const Color(0xFF2B2348),
    onStage: const Color(0xFFE9E2FF),
    lime: const Color(0xFFD3F2A2),
    onLime: const Color(0xFF1E2A08),
    blue: const BentoTone(Color(0xFF2A3420), Color(0xFFDDEFC7)),
    violet: const BentoTone(Color(0xFF2C2547), Color(0xFFE2DAFF)),
    cyan: const BentoTone(Color(0xFF14363A), Color(0xFFC2EDF0)),
    pink: const BentoTone(Color(0xFF43242E), Color(0xFFFFD6E1)),
    coral: const BentoTone(Color(0xFF3A3420), Color(0xFFF7EBC4)),
    selected: const Color(0xFF352C57),
    dock: const Color(0xFF22251F),
    colorful: true,
  ),
  BentoPalette.ocean: _dark(
    ground: const Color(0xFF070B10),
    surface: const Color(0xFF121923),
    surface2: const Color(0xFF1C2431),
    line: const Color(0xFF313D4F),
    ink: const Color(0xFFE7EEF8),
    muted: const Color(0xFF9FAABD),
    stage: const Color(0xFF0E2F57),
    onStage: const Color(0xFFD8E9FF),
    lime: const Color(0xFF5CF2C8),
    onLime: const Color(0xFF00281D),
    blue: const BentoTone(Color(0xFF10304F), Color(0xFFC4E2FF)),
    violet: const BentoTone(Color(0xFF1E2357), Color(0xFFD6D9FF)),
    cyan: const BentoTone(Color(0xFF0A3838), Color(0xFFA8F0EC)),
    pink: const BentoTone(Color(0xFF0A3340), Color(0xFFA6E8FF)),
    coral: const BentoTone(Color(0xFF38301F), Color(0xFFF2E2BA)),
    selected: const Color(0xFF123A6A),
    dock: const Color(0xFF1C2431),
    colorful: true,
  ),
  BentoPalette.sunset: _dark(
    ground: const Color(0xFF0E0A09),
    surface: const Color(0xFF1C1513),
    surface2: const Color(0xFF28201D),
    line: const Color(0xFF43362F),
    ink: const Color(0xFFF8EDE8),
    muted: const Color(0xFFBBA79E),
    stage: const Color(0xFF4A1F12),
    onStage: const Color(0xFFFFE3D6),
    lime: const Color(0xFFFFB547),
    onLime: const Color(0xFF2E1800),
    blue: const BentoTone(Color(0xFF4A2A16), Color(0xFFFFD8B8)),
    violet: const BentoTone(Color(0xFF2E1A40), Color(0xFFE6D2FF)),
    cyan: const BentoTone(Color(0xFF3F3110), Color(0xFFFFE7A3)),
    pink: const BentoTone(Color(0xFF4A1A2A), Color(0xFFFFC6D9)),
    coral: const BentoTone(Color(0xFF4A1F1A), Color(0xFFFFC4B8)),
    selected: const Color(0xFF5A2A18),
    dock: const Color(0xFF28201D),
    colorful: true,
  ),
  BentoPalette.berry: _dark(
    ground: const Color(0xFF0D080C),
    surface: const Color(0xFF1B1219),
    surface2: const Color(0xFF271B24),
    line: const Color(0xFF42303D),
    ink: const Color(0xFFF7EAF2),
    muted: const Color(0xFFB8A2B0),
    stage: const Color(0xFF4A0E3A),
    onStage: const Color(0xFFFFD9F2),
    lime: const Color(0xFFD7F59A),
    onLime: const Color(0xFF1E2A06),
    blue: const BentoTone(Color(0xFF4A1230), Color(0xFFFFC6E0)),
    violet: const BentoTone(Color(0xFF341B4A), Color(0xFFEBD3FF)),
    cyan: const BentoTone(Color(0xFF123A2C), Color(0xFFB8F2D8)),
    pink: const BentoTone(Color(0xFF4A1C24), Color(0xFFFFCCD5)),
    coral: const BentoTone(Color(0xFF46281A), Color(0xFFFFD9C2)),
    selected: const Color(0xFF5A1548),
    dock: const Color(0xFF271B24),
    colorful: true,
  ),
};

/// The eight hardcoded palettes, light.
final _bentoLight = <BentoPalette, BentoTokens>{
  BentoPalette.brand: _light(
    ground: const Color(0xFFF6F6F0),
    surface: const Color(0xFFEAEAE2),
    surface2: const Color(0xFFDCDCD2),
    line: const Color(0xFFC5C5BA),
    ink: const Color(0xFF16161C),
    muted: const Color(0xFF55555F),
    stage: const Color(0xFF2A1361),
    onStage: const Color(0xFFF1EBFF),
    lime: const Color(0xFFC7F24E),
    onLime: const Color(0xFF1A2200),
    blue: const BentoTone(Color(0xFFD4E4FF), Color(0xFF123A70)),
    violet: const BentoTone(Color(0xFFE3DBFF), Color(0xFF36268A)),
    cyan: const BentoTone(Color(0xFFC6F1ED), Color(0xFF0B4A45)),
    pink: const BentoTone(Color(0xFFFFD6E7), Color(0xFF6E1543)),
    coral: const BentoTone(Color(0xFFFFDCCD), Color(0xFF6D2914)),
    selected: const Color(0xFFE3DBFF),
    colorful: false,
  ),
  BentoPalette.citrus: _light(
    ground: const Color(0xFFF7F8EC),
    surface: const Color(0xFFEBEDDB),
    surface2: const Color(0xFFDEE1C9),
    line: const Color(0xFFC6C9AE),
    ink: const Color(0xFF17180F),
    muted: const Color(0xFF565A44),
    stage: const Color(0xFF2D3A0B),
    onStage: const Color(0xFFF2FBD6),
    lime: const Color(0xFFD8EE2C),
    onLime: const Color(0xFF1F2400),
    blue: const BentoTone(Color(0xFFFFF3B0), Color(0xFF5A4A00)),
    violet: const BentoTone(Color(0xFFCFF5E2), Color(0xFF0E4A33)),
    cyan: const BentoTone(Color(0xFFE0F5C0), Color(0xFF2C4A0C)),
    pink: const BentoTone(Color(0xFFFFE0BE), Color(0xFF6A3A06)),
    coral: const BentoTone(Color(0xFFFFD9D0), Color(0xFF6E2414)),
    selected: const Color(0xFFE5F0B8),
    colorful: true,
  ),
  BentoPalette.matcha: _light(
    ground: const Color(0xFFF4F7F2),
    surface: const Color(0xFFE7EDE4),
    surface2: const Color(0xFFD9E1D5),
    line: const Color(0xFFBFC9BB),
    ink: const Color(0xFF141A13),
    muted: const Color(0xFF4E594B),
    stage: const Color(0xFF1F3D27),
    onStage: const Color(0xFFE2F6E7),
    lime: const Color(0xFFA6D65A),
    onLime: const Color(0xFF172600),
    blue: const BentoTone(Color(0xFFD3EEDB), Color(0xFF1C4A2B)),
    violet: const BentoTone(Color(0xFFE6F0C2), Color(0xFF3F4A0E)),
    cyan: const BentoTone(Color(0xFFC6EEEE), Color(0xFF0B4748)),
    pink: const BentoTone(Color(0xFFF7DCCB), Color(0xFF6A3415)),
    coral: const BentoTone(Color(0xFFF3EAC9), Color(0xFF5A4A14)),
    selected: const Color(0xFFD6EAD9),
    colorful: true,
  ),
  BentoPalette.neon: _light(
    ground: const Color(0xFFF8F6FB),
    surface: const Color(0xFFECE8F2),
    surface2: const Color(0xFFDED8E8),
    line: const Color(0xFFC5BDD3),
    ink: const Color(0xFF15121C),
    muted: const Color(0xFF554C66),
    stage: const Color(0xFF3D0B4F),
    onStage: const Color(0xFFFCE2FF),
    lime: const Color(0xFFA8F21E),
    onLime: const Color(0xFF142400),
    blue: const BentoTone(Color(0xFFFFD6F1), Color(0xFF6E0F55)),
    violet: const BentoTone(Color(0xFFC8F1FF), Color(0xFF00475E)),
    cyan: const BentoTone(Color(0xFFE7DBFF), Color(0xFF3D1F80)),
    pink: const BentoTone(Color(0xFFF6FAB4), Color(0xFF4F5200)),
    coral: const BentoTone(Color(0xFFFFDCD2), Color(0xFF741D0A)),
    selected: const Color(0xFFF1DDF7),
    colorful: true,
  ),
  BentoPalette.pistachio: _light(
    ground: const Color(0xFFF6F7F2),
    surface: const Color(0xFFEAECE3),
    surface2: const Color(0xFFDDE0D4),
    line: const Color(0xFFC4C8BA),
    ink: const Color(0xFF151713),
    muted: const Color(0xFF535849),
    stage: const Color(0xFF2B2348),
    onStage: const Color(0xFFEEE8FF),
    lime: const Color(0xFFC6EB8A),
    onLime: const Color(0xFF1E2A08),
    blue: const BentoTone(Color(0xFFE4F0D2), Color(0xFF344A1A)),
    violet: const BentoTone(Color(0xFFE7E0FF), Color(0xFF3A2C7A)),
    cyan: const BentoTone(Color(0xFFCFEFF1), Color(0xFF134A50)),
    pink: const BentoTone(Color(0xFFFFDCE6), Color(0xFF6E2338)),
    coral: const BentoTone(Color(0xFFF7EDCC), Color(0xFF5A4614)),
    selected: const Color(0xFFE3DDF7),
    colorful: true,
  ),
  BentoPalette.ocean: _light(
    ground: const Color(0xFFF3F7FB),
    surface: const Color(0xFFE4EBF3),
    surface2: const Color(0xFFD5DEE9),
    line: const Color(0xFFB9C5D4),
    ink: const Color(0xFF0F1620),
    muted: const Color(0xFF4A5768),
    stage: const Color(0xFF0E2F57),
    onStage: const Color(0xFFDDEBFF),
    lime: const Color(0xFF3BE0B4),
    onLime: const Color(0xFF00281D),
    blue: const BentoTone(Color(0xFFD2E6FF), Color(0xFF0F3B6E)),
    violet: const BentoTone(Color(0xFFDCDEFF), Color(0xFF262E80)),
    cyan: const BentoTone(Color(0xFFC4F1EC), Color(0xFF0A4A45)),
    pink: const BentoTone(Color(0xFFC6ECF7), Color(0xFF064559)),
    coral: const BentoTone(Color(0xFFF3E8CC), Color(0xFF5A4614)),
    selected: const Color(0xFFD6E5F7),
    colorful: true,
  ),
  BentoPalette.sunset: _light(
    ground: const Color(0xFFFBF6F3),
    surface: const Color(0xFFF1E8E3),
    surface2: const Color(0xFFE5D9D2),
    line: const Color(0xFFCDBDB4),
    ink: const Color(0xFF1C1310),
    muted: const Color(0xFF64514A),
    stage: const Color(0xFF4A1F12),
    onStage: const Color(0xFFFFE6DA),
    lime: const Color(0xFFFFA62B),
    onLime: const Color(0xFF2E1800),
    blue: const BentoTone(Color(0xFFFFE2C9), Color(0xFF6A3A10)),
    violet: const BentoTone(Color(0xFFEBDDFF), Color(0xFF4A2A70)),
    cyan: const BentoTone(Color(0xFFFFEDB8), Color(0xFF5A4300)),
    pink: const BentoTone(Color(0xFFFFD9E5), Color(0xFF6E1A38)),
    coral: const BentoTone(Color(0xFFFFDAD0), Color(0xFF742214)),
    selected: const Color(0xFFF5DCD0),
    colorful: true,
  ),
  BentoPalette.berry: _light(
    ground: const Color(0xFFFBF5F8),
    surface: const Color(0xFFF1E6EC),
    surface2: const Color(0xFFE5D6DF),
    line: const Color(0xFFCDB9C5),
    ink: const Color(0xFF1C1018),
    muted: const Color(0xFF634C5A),
    stage: const Color(0xFF4A0E3A),
    onStage: const Color(0xFFFFDDF3),
    lime: const Color(0xFFC4EC7C),
    onLime: const Color(0xFF1E2A06),
    blue: const BentoTone(Color(0xFFFFD7E9), Color(0xFF6E1240)),
    violet: const BentoTone(Color(0xFFEEDDFF), Color(0xFF4F2A72)),
    cyan: const BentoTone(Color(0xFFC9F2DF), Color(0xFF0F4A34)),
    pink: const BentoTone(Color(0xFFFFD9E0), Color(0xFF6E1C2C)),
    coral: const BentoTone(Color(0xFFFFE0CE), Color(0xFF6A3414)),
    selected: const Color(0xFFF5D8E9),
    colorful: true,
  ),
};

/// The canonical accent seeds of the four algorithmic palettes: each
/// preset's LIGHT colour (`accentSeed()` returns `.light`).
const _algorithmicSeeds = <BentoPalette, int>{
  BentoPalette.accent: 0xFF5646D6,
  BentoPalette.pastel: 0xFFD77FA1,
  BentoPalette.vivid: 0xFFE64A19,
  BentoPalette.mono: 0xFF616161,
};

Color _tone(TonalPalette p, int t) => Color(p.get(t));

/// The original's `tonal()` (§1.4 of the extract): HCT tonal palettes
/// built from the seed's hue, per-kind chromas, tone tables verbatim.
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
  final tileChroma = switch (kind) {
    BentoPalette.accent => 36.0,
    BentoPalette.pastel => 26.0,
    _ => 66.0, // vivid
  };
  BentoTone tile(double offset) {
    final p = TonalPalette.of((hue + offset) % 360, tileChroma);
    return switch (kind) {
      BentoPalette.pastel => BentoTone(
        _tone(p, t(82, 92)),
        _tone(p, t(16, 24)),
      ),
      BentoPalette.vivid => BentoTone(_tone(p, t(38, 76)), _tone(p, t(96, 10))),
      _ => BentoTone(_tone(p, t(20, 90)), _tone(p, t(88, 24))),
    };
  }

  return BentoTokens(
    dark: dark,
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
    blue: tile(60),
    violet: tile(120),
    cyan: tile(180),
    pink: tile(240),
    coral: tile(300),
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
    colorful: false,
  );
}

/// The original's `mono()`: one near-neutral palette (chroma 3).
BentoTokens _monoTokens(int seedArgb, bool dark) {
  final hue = Hct.fromInt(seedArgb).hue;
  final n = TonalPalette.of(hue, 3);
  final goodP = TonalPalette.of(145, 40);
  final midP = TonalPalette.of(80, 50);
  final badP = TonalPalette.of(25, 64);
  int t(int d, int l) => dark ? d : l;
  BentoTone tile(int dTone, int lTone) => dark
      ? BentoTone(_tone(n, dTone), _tone(n, 94))
      : BentoTone(_tone(n, lTone), _tone(n, 10));
  return BentoTokens(
    dark: dark,
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
    blue: tile(14, 90),
    violet: tile(18, 86),
    cyan: tile(12, 88),
    pink: tile(20, 84),
    coral: tile(16, 91),
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
    colorful: false,
  );
}

/// Resolves a palette for a brightness, with the AMOLED override the
/// original applies to every palette in the dark. [seedArgb] overrides
/// the algorithmic palettes' canonical seed — in the original the seed
/// is the user's accent colour; round 4 of the study established that
/// the app's accent setting is the Pixel accent preset.
BentoTokens bentoTokensFor(
  BentoPalette palette,
  bool dark, {
  bool amoled = false,
  int? seedArgb,
}) {
  var tokens = switch (palette) {
    BentoPalette.accent || BentoPalette.pastel || BentoPalette.vivid =>
      _tonalTokens(seedArgb ?? _algorithmicSeeds[palette]!, dark, palette),
    BentoPalette.mono => _monoTokens(
      seedArgb ?? _algorithmicSeeds[palette]!,
      dark,
    ),
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

/// The original's `bentoColorScheme()` verbatim (`BentoTheme.kt`):
/// dark leads with the lime, light with the stage; secondary/tertiary
/// are the violet/cyan pairs (content on container); the surface IS
/// the ground; dark errorContainer is the palette's coral pair.
ColorScheme bentoScheme(BentoTokens c) {
  final low = Color.lerp(c.ground, c.surface, 0.5)!;
  final highest = Color.lerp(c.surface2, c.line, 0.25)!;
  final outline = Color.alphaBlend(c.muted.withValues(alpha: 0.7), c.ground);
  if (c.dark) {
    return ColorScheme(
      brightness: Brightness.dark,
      primary: c.lime,
      onPrimary: c.onLime,
      primaryContainer: c.stage,
      onPrimaryContainer: c.onStage,
      inversePrimary: c.stage,
      secondary: c.violet.content,
      onSecondary: c.violet.container,
      secondaryContainer: c.violet.container,
      onSecondaryContainer: c.violet.content,
      tertiary: c.cyan.content,
      onTertiary: c.cyan.container,
      tertiaryContainer: c.cyan.container,
      onTertiaryContainer: c.cyan.content,
      error: c.danger,
      onError: c.onDanger,
      errorContainer: c.coral.container,
      onErrorContainer: c.coral.content,
      surface: c.ground,
      onSurface: c.ink,
      onSurfaceVariant: c.muted,
      surfaceTint: c.lime,
      inverseSurface: c.ink,
      onInverseSurface: c.ground,
      outline: outline,
      outlineVariant: c.line,
      shadow: Colors.black,
      scrim: Colors.black,
      surfaceBright: c.surface2,
      surfaceDim: c.ground,
      surfaceContainerLowest: c.ground,
      surfaceContainerLow: low,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surface,
      surfaceContainerHighest: highest,
    );
  }
  return ColorScheme(
    brightness: Brightness.light,
    primary: c.stage,
    onPrimary: c.onStage,
    primaryContainer: c.lime,
    onPrimaryContainer: c.onLime,
    inversePrimary: c.lime,
    secondary: c.violet.content,
    onSecondary: c.violet.container,
    secondaryContainer: c.violet.container,
    onSecondaryContainer: c.violet.content,
    tertiary: c.cyan.content,
    onTertiary: c.cyan.container,
    tertiaryContainer: c.cyan.container,
    onTertiaryContainer: c.cyan.content,
    error: c.bad,
    onError: Colors.white,
    errorContainer: c.danger,
    onErrorContainer: c.onDanger,
    surface: c.ground,
    onSurface: c.ink,
    onSurfaceVariant: c.muted,
    surfaceTint: c.stage,
    inverseSurface: c.ink,
    onInverseSurface: c.ground,
    outline: outline,
    outlineVariant: c.line,
    shadow: Colors.black,
    scrim: Colors.black,
    surfaceBright: c.ground,
    surfaceDim: c.surface2,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: low,
    surfaceContainer: c.surface,
    surfaceContainerHigh: c.surface,
    surfaceContainerHighest: c.surface2,
  );
}

/// Bento shapes (`BentoShapes`, §1.5): Leaf is asymmetric
/// (36,36,36,12) for prominent tiles; corners are directional so the
/// small corner mirrors in RTL.
BorderRadiusGeometry bentoTileRadius(
  BentoCorners corner, {
  bool prominent = true,
}) => switch (corner) {
  BentoCorners.leaf =>
    prominent
        ? const BorderRadiusDirectional.only(
            topStart: Radius.circular(36),
            topEnd: Radius.circular(36),
            bottomEnd: Radius.circular(36),
            bottomStart: Radius.circular(12),
          )
        : BorderRadius.circular(30),
  BentoCorners.round => BorderRadius.circular(prominent ? 36 : 30),
  BentoCorners.soft => BorderRadius.circular(prominent ? 24 : 20),
};

BorderRadiusGeometry bentoHeroRadius(BentoCorners corner) => switch (corner) {
  BentoCorners.leaf => const BorderRadiusDirectional.only(
    topStart: Radius.circular(34),
    topEnd: Radius.circular(34),
    bottomEnd: Radius.circular(34),
    bottomStart: Radius.circular(12),
  ),
  BentoCorners.round => BorderRadius.circular(34),
  BentoCorners.soft => BorderRadius.circular(22),
};

double bentoCardRadius(BentoCorners c) => c == BentoCorners.soft ? 20 : 30;
double bentoBlockRadius(BentoCorners c) => c == BentoCorners.soft ? 18 : 26;
double bentoSmallRadius(BentoCorners c) => c == BentoCorners.soft ? 16 : 22;
double bentoChipRadius(BentoCorners c) => c == BentoCorners.soft ? 12 : 14;

/// Grouped-row radii: outer corners rounded, inner square-ish.
BorderRadiusGeometry bentoRowRadius(BentoCorners corner, int index, int count) {
  final outer = corner == BentoCorners.soft ? 16.0 : 22.0;
  final inner = corner == BentoCorners.soft ? 6.0 : 8.0;
  if (count <= 1) return BorderRadius.circular(outer);
  if (index == 0) {
    return BorderRadiusDirectional.only(
      topStart: Radius.circular(outer),
      topEnd: Radius.circular(outer),
      bottomEnd: Radius.circular(inner),
      bottomStart: Radius.circular(inner),
    );
  }
  if (index == count - 1) {
    return BorderRadiusDirectional.only(
      topStart: Radius.circular(inner),
      topEnd: Radius.circular(inner),
      bottomEnd: Radius.circular(outer),
      bottomStart: Radius.circular(outer),
    );
  }
  return BorderRadius.circular(inner);
}

/// Bento metrics (`BentoMetrics`): gutter is constant 16.
({double gap, double tileRow, double rowMin, double pad}) bentoMetrics(
  BentoDensity d,
) => switch (d) {
  BentoDensity.comfortable => (gap: 8, tileRow: 134, rowMin: 62, pad: 16),
  BentoDensity.compact => (gap: 6, tileRow: 116, rowMin: 54, pad: 13),
};

/// The Bento tokens as a theme extension, present only under Bento.
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

/// Pixel/Old's ten accent presets (`AccentPresets`): the SEED is each
/// preset's LIGHT colour — `accentSeed()` returns `.light` in both
/// brightnesses.
const pixelAccents = <Color>[
  Color(0xFF5646D6), // Iris
  Color(0xFF1E63D0), // Ocean
  Color(0xFF00897E), // Teal
  Color(0xFF2E7D32), // Forest
  Color(0xFFB4690E), // Amber
  Color(0xFFC4326B), // Rose
  Color(0xFFC0362C), // Crimson
  Color(0xFF00838F), // Cyan
  Color(0xFF8E24AA), // Grape
  Color(0xFF4A5B7A), // Slate
];

const pixelAccentNames = [
  'Iris',
  'Ocean',
  'Teal',
  'Forest',
  'Amber',
  'Rose',
  'Crimson',
  'Cyan',
  'Grape',
  'Slate',
];

const _brandTeal = Color(0xFF00897E);
const _brandRose = Color(0xFFC4326B);

/// `zedColorScheme()` for Pixel/Old: SPEC_2025 generation from the
/// accent seed. The `ZedSecure` style is TonalSpot with the seed as
/// primary and the fixed BrandTeal/BrandRose as secondary/tertiary
/// (MaterialKolor semantics); the other styles map to their
/// PaletteStyle twins, which Flutter exposes as DynamicSchemeVariant.
ColorScheme pixelScheme(PixelPrefs prefs, Brightness brightness) {
  final seed = pixelAccents[prefs.accentIndex.clamp(0, 9)];
  final dark = brightness == Brightness.dark;
  final variant = switch (prefs.colorStyle) {
    PixelColorStyle.zedSecure ||
    PixelColorStyle.tonalSpot => DynamicSchemeVariant.tonalSpot,
    PixelColorStyle.vibrant => DynamicSchemeVariant.vibrant,
    PixelColorStyle.expressive => DynamicSchemeVariant.expressive,
    PixelColorStyle.rainbow => DynamicSchemeVariant.rainbow,
    PixelColorStyle.fruitSalad => DynamicSchemeVariant.fruitSalad,
    PixelColorStyle.fidelity => DynamicSchemeVariant.fidelity,
    PixelColorStyle.neutral => DynamicSchemeVariant.neutral,
    PixelColorStyle.monochrome => DynamicSchemeVariant.monochrome,
  };
  var scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    dynamicSchemeVariant: variant,
    contrastLevel: prefs.contrastLevel,
  );
  if (prefs.colorStyle == PixelColorStyle.zedSecure) {
    // Secondary/tertiary from the fixed brand colours, generated with
    // the same TonalSpot algorithm so tones/contrast stay consistent.
    final teal = ColorScheme.fromSeed(
      seedColor: _brandTeal,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
      contrastLevel: prefs.contrastLevel,
    );
    final rose = ColorScheme.fromSeed(
      seedColor: _brandRose,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
      contrastLevel: prefs.contrastLevel,
    );
    scheme = scheme.copyWith(
      secondary: teal.primary,
      onSecondary: teal.onPrimary,
      secondaryContainer: teal.primaryContainer,
      onSecondaryContainer: teal.onPrimaryContainer,
      tertiary: rose.primary,
      onTertiary: rose.onPrimary,
      tertiaryContainer: rose.primaryContainer,
      onTertiaryContainer: rose.onPrimaryContainer,
    );
  }
  if (prefs.amoled && dark) {
    // The documented eight-role AMOLED set (§3.1 of the extract).
    scheme = scheme.copyWith(
      surface: const Color(0xFF000000),
      surfaceDim: const Color(0xFF000000),
      surfaceContainerLowest: const Color(0xFF000000),
      surfaceContainerLow: const Color(0xFF0B0B0B),
      surfaceContainer: const Color(0xFF0F0F0F),
      surfaceContainerHigh: const Color(0xFF161616),
      surfaceContainerHighest: const Color(0xFF1E1E1E),
      surfaceBright: const Color(0xFF1A1A1A),
    );
  }
  return scheme;
}

/// Server-card corner radius per `CardCornerStyle` (§3.2).
double cornerStyleServerRadius(CardCornerStyle s) => switch (s) {
  CardCornerStyle.squared => 6,
  CardCornerStyle.rounded => 22,
  CardCornerStyle.pill => 34,
};

double cornerStyleTileScale(CardCornerStyle s) => switch (s) {
  CardCornerStyle.squared => 0.30,
  CardCornerStyle.rounded => 1.00,
  CardCornerStyle.pill => 1.45,
};

/// The twelve iOS tints for Glass, dark values (`IosColors`).
const glassTintColorsDark = <GlassTint, Color>{
  GlassTint.blue: Color(0xFF0091FF),
  GlassTint.indigo: Color(0xFF6D7CFF),
  GlassTint.purple: Color(0xFFDB34F2),
  GlassTint.pink: Color(0xFFFF375F),
  GlassTint.red: Color(0xFFFF4245),
  GlassTint.orange: Color(0xFFFF9230),
  GlassTint.green: Color(0xFF30D158),
  GlassTint.mint: Color(0xFF00DAC3),
  GlassTint.teal: Color(0xFF00D2E0),
  GlassTint.cyan: Color(0xFF3CD3FE),
  GlassTint.brown: Color(0xFFB78A66),
  GlassTint.graphite: Color(0xFF98989D),
};

/// The twelve iOS tints, light values.
const glassTintColorsLight = <GlassTint, Color>{
  GlassTint.blue: Color(0xFF0088FF),
  GlassTint.indigo: Color(0xFF6155F5),
  GlassTint.purple: Color(0xFFCB30E0),
  GlassTint.pink: Color(0xFFFF2D55),
  GlassTint.red: Color(0xFFFF383C),
  GlassTint.orange: Color(0xFFFF8D28),
  GlassTint.green: Color(0xFF34C759),
  GlassTint.mint: Color(0xFF00C8B3),
  GlassTint.teal: Color(0xFF00C3D0),
  GlassTint.cyan: Color(0xFF00C0E8),
  GlassTint.brown: Color(0xFFAC7F5E),
  GlassTint.graphite: Color(0xFF8E8E93),
};

Color glassTintColor(GlassTint tint, bool dark) =>
    (dark ? glassTintColorsDark : glassTintColorsLight)[tint]!;

/// The full `GlassColors` token set (`GlassTheme.kt`), resolved for a
/// brightness + the user's glass prefs.
class GlassTokens {
  const GlassTokens({
    required this.dark,
    required this.tint,
    required this.module,
    required this.chrome,
    required this.solidCell,
    required this.chromeSolid,
    required this.cell,
    required this.label,
    required this.label2,
    required this.label3,
    required this.separator,
    required this.fill,
    required this.fill2,
    required this.page,
    required this.rimHi,
    required this.rimMid,
    required this.rimLo,
    required this.highlight,
    required this.platter,
    required this.thumb,
    required this.dim,
    required this.sheet,
    required this.menu,
    required this.green,
    required this.red,
    required this.orange,
    required this.shadow,
    required this.translucent,
    required this.reduced,
  });

  final bool dark;
  final Color tint;
  final Color module;
  final Color chrome;
  final Color solidCell;
  final Color chromeSolid;
  final Color cell;
  final Color label;
  final Color label2;
  final Color label3;
  final Color separator;
  final Color fill;
  final Color fill2;
  final Color page;
  final Color rimHi;
  final Color rimMid;
  final Color rimLo;
  final Color highlight;
  final Color platter;
  final Color thumb;
  final Color dim;
  final Color sheet;
  final Color menu;
  final Color green;
  final Color red;
  final Color orange;
  final Color shadow;
  final bool translucent;
  final bool reduced;

  /// `GlassColors.pingColor`: null → label3; <=0 → red; <200 → green;
  /// <400 → orange; else red.
  Color pingColor(int? ms) => ms == null
      ? label3
      : (ms <= 0 ? red : (ms < 200 ? green : (ms < 400 ? orange : red)));

  GlassTokens copyWith({Color? module, Color? chrome, Color? cell}) =>
      GlassTokens(
        dark: dark,
        tint: tint,
        module: module ?? this.module,
        chrome: chrome ?? this.chrome,
        solidCell: solidCell,
        chromeSolid: chromeSolid,
        cell: cell ?? this.cell,
        label: label,
        label2: label2,
        label3: label3,
        separator: separator,
        fill: fill,
        fill2: fill2,
        page: page,
        rimHi: rimHi,
        rimMid: rimMid,
        rimLo: rimLo,
        highlight: highlight,
        platter: platter,
        thumb: thumb,
        dim: dim,
        sheet: sheet,
        menu: menu,
        green: green,
        red: red,
        orange: orange,
        shadow: shadow,
        translucent: translucent,
        reduced: reduced,
      );
}

/// `GlassPalette.of(dark, prefs)` — the token factory.
GlassTokens glassTokensFor(GlassPrefs prefs, bool dark) {
  final reduced = prefs.reduceTransparency;
  final tinted = prefs.material == GlassMaterial.tinted;
  final solidCell = dark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);
  final chromeSolid = dark ? const Color(0xFF2C2C2E) : const Color(0xFFF9F9FB);
  final module = reduced
      ? solidCell
      : dark
      ? (tinted ? const Color(0xDB28282C) : const Color(0x612C2C30))
      : (tinted ? const Color(0xD6FFFFFF) : const Color(0x80FFFFFF));
  final chrome = reduced
      ? chromeSolid
      : dark
      ? (tinted ? const Color(0xDB242426) : const Color(0x661E1E20))
      : (tinted ? const Color(0xCCFFFFFF) : const Color(0x61FFFFFF));
  return GlassTokens(
    dark: dark,
    tint: glassTintColor(prefs.tint, dark),
    module: module,
    chrome: chrome,
    solidCell: solidCell,
    chromeSolid: chromeSolid,
    cell: prefs.glassLists ? module : solidCell,
    label: dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
    label2: dark ? const Color(0x9EEBEBF5) : const Color(0x9E3C3C43),
    label3: dark ? const Color(0x4DEBEBF5) : const Color(0x4D3C3C43),
    separator: dark ? const Color(0x1FFFFFFF) : const Color(0x293C3C43),
    fill: dark ? const Color(0x5C787880) : const Color(0x33787880),
    fill2: dark ? const Color(0x3D767680) : const Color(0x1F767680),
    page: dark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
    rimHi: dark ? const Color(0x94FFFFFF) : const Color(0xFFFFFFFF),
    rimMid: dark ? const Color(0x12FFFFFF) : const Color(0x47FFFFFF),
    rimLo: dark ? const Color(0x42FFFFFF) : const Color(0xCCFFFFFF),
    highlight: dark ? const Color(0x38FFFFFF) : const Color(0xF2FFFFFF),
    platter: dark ? const Color(0x1CFFFFFF) : const Color(0x12000000),
    thumb: dark ? const Color(0x38FFFFFF) : const Color(0xF5FFFFFF),
    dim: dark ? const Color(0x6B000000) : const Color(0x2E000000),
    sheet: dark ? const Color(0xF51E1E20) : const Color(0xF5F9F9FB),
    menu: dark ? const Color(0xF528282A) : const Color(0xF5FCFCFD),
    green: dark ? const Color(0xFF30D158) : const Color(0xFF34C759),
    red: dark ? const Color(0xFFFF4245) : const Color(0xFFFF383C),
    orange: dark ? const Color(0xFFFF9230) : const Color(0xFFFF8D28),
    shadow: dark ? const Color(0x80000000) : const Color(0x1F000000),
    translucent: prefs.translucent,
    reduced: reduced,
  );
}

/// The original's `glassColorScheme()` verbatim (`GlassTheme.kt`): a
/// hand-mapped table over the tint and the fixed iOS system colours.
ColorScheme glassScheme(GlassTokens c) {
  const white = Colors.white;
  const black = Colors.black;
  Color lerp(Color a, Color b, double t) => Color.lerp(a, b, t)!;
  if (c.dark) {
    const base = Color(0xFF1C1C1E);
    return ColorScheme(
      brightness: Brightness.dark,
      primary: c.tint,
      onPrimary: white,
      primaryContainer: lerp(base, c.tint, 0.32),
      onPrimaryContainer: lerp(c.tint, white, 0.55),
      inversePrimary: lerp(c.tint, black, 0.2),
      secondary: c.tint,
      onSecondary: white,
      secondaryContainer: const Color(0xFF2C2C2E),
      onSecondaryContainer: white,
      tertiary: c.green,
      onTertiary: black,
      tertiaryContainer: lerp(base, c.green, 0.3),
      onTertiaryContainer: lerp(c.green, white, 0.5),
      error: c.red,
      onError: white,
      errorContainer: lerp(base, c.red, 0.3),
      onErrorContainer: lerp(c.red, white, 0.5),
      surface: black,
      onSurface: white,
      onSurfaceVariant: const Color(0xFF8D8D93),
      surfaceTint: c.tint,
      inverseSurface: const Color(0xFFF2F2F7),
      onInverseSurface: black,
      outline: const Color(0xFF545458),
      outlineVariant: const Color(0xFF38383A),
      shadow: black,
      scrim: black,
      surfaceBright: const Color(0xFF2C2C2E),
      surfaceDim: black,
      surfaceContainerLowest: black,
      surfaceContainerLow: base,
      surfaceContainer: base,
      surfaceContainerHigh: const Color(0xFF2C2C2E),
      surfaceContainerHighest: const Color(0xFF3A3A3C),
    );
  }
  return ColorScheme(
    brightness: Brightness.light,
    primary: c.tint,
    onPrimary: white,
    primaryContainer: lerp(white, c.tint, 0.16),
    onPrimaryContainer: lerp(c.tint, black, 0.45),
    inversePrimary: lerp(c.tint, white, 0.35),
    secondary: c.tint,
    onSecondary: white,
    secondaryContainer: const Color(0xFFE5E5EA),
    onSecondaryContainer: black,
    tertiary: c.green,
    onTertiary: white,
    tertiaryContainer: lerp(white, c.green, 0.18),
    onTertiaryContainer: lerp(c.green, black, 0.5),
    error: c.red,
    onError: white,
    errorContainer: lerp(white, c.red, 0.15),
    onErrorContainer: lerp(c.red, black, 0.45),
    surface: const Color(0xFFF2F2F7),
    onSurface: black,
    onSurfaceVariant: const Color(0xFF8A8A8E),
    surfaceTint: c.tint,
    inverseSurface: const Color(0xFF1C1C1E),
    onInverseSurface: white,
    outline: const Color(0xFFC6C6C8),
    outlineVariant: const Color(0xFFD8D8DC),
    shadow: black,
    scrim: black,
    surfaceBright: white,
    surfaceDim: const Color(0xFFE5E5EA),
    surfaceContainerLowest: white,
    surfaceContainerLow: white,
    surfaceContainer: white,
    surfaceContainerHigh: const Color(0xFFF9F9FB),
    surfaceContainerHighest: const Color(0xFFE5E5EA),
  );
}

/// The Glass tokens as a theme extension, present only under Glass.
class ZedGlass extends ThemeExtension<ZedGlass> {
  const ZedGlass(this.tokens);

  final GlassTokens tokens;

  @override
  ZedGlass copyWith({GlassTokens? tokens}) => ZedGlass(tokens ?? this.tokens);

  @override
  ZedGlass lerp(ZedGlass? other, double t) => t < 0.5 ? this : (other ?? this);

  static GlassTokens? of(BuildContext context) =>
      Theme.of(context).extension<ZedGlass>()?.tokens;
}

/// One named theme profile (`ThemeProfiles.kt`): a whole block of
/// Pixel/Old personalisation applied at once.
class ZedProfile {
  const ZedProfile(
    this.id,
    this.name,
    this.accentIndex,
    this.amoled, {
    required this.download,
    required this.upload,
    required this.downloadTile,
    required this.uploadTile,
    required this.connect,
    required this.connected,
    required this.tapHint,
    required this.serverCard,
    required this.serverActive,
    required this.configCard,
    required this.configCardText,
  });

  final String id;
  final String name;
  final int accentIndex;
  final bool amoled;
  final Color download;
  final Color upload;
  final Color downloadTile;
  final Color uploadTile;
  final Color connect;
  final Color connected;
  final Color tapHint;
  final Color serverCard;
  final Color serverActive;
  final Color configCard;
  final Color configCardText;

  List<Color> get swatches => [connect, download, upload];
}

Color _hex(int v) => Color(0xFF000000 | v);

/// The 11 profiles, values verbatim from `ThemeProfiles.kt` (§7).
final zedProfiles = <ZedProfile>[
  ZedProfile(
    'aurora',
    'Aurora',
    2,
    false,
    download: _hex(0x4FE3D8),
    upload: _hex(0xB49BFF),
    downloadTile: _hex(0x0D3B37),
    uploadTile: _hex(0x241A48),
    connect: _hex(0x12A594),
    connected: _hex(0x7C5CFF),
    tapHint: _hex(0xA9E9E2),
    serverCard: _hex(0x11302E),
    serverActive: _hex(0x12A594),
    configCard: _hex(0x12332F),
    configCardText: _hex(0xEAFFFB),
  ),
  ZedProfile(
    'ember',
    'Ember',
    4,
    false,
    download: _hex(0xFFB870),
    upload: _hex(0xFF8A65),
    downloadTile: _hex(0x3D2409),
    uploadTile: _hex(0x43200F),
    connect: _hex(0xE07A1F),
    connected: _hex(0xC0392B),
    tapHint: _hex(0xFFD9AE),
    serverCard: _hex(0x33200C),
    serverActive: _hex(0xE07A1F),
    configCard: _hex(0x3A2410),
    configCardText: _hex(0xFFF1E2),
  ),
  ZedProfile(
    'midnight',
    'Midnight',
    1,
    true,
    download: _hex(0x7FB2FF),
    upload: _hex(0x9BC4FF),
    downloadTile: _hex(0x0B1730),
    uploadTile: _hex(0x101B36),
    connect: _hex(0x2563EB),
    connected: _hex(0x1E3A8A),
    tapHint: _hex(0xA9C6F5),
    serverCard: _hex(0x0C1526),
    serverActive: _hex(0x2563EB),
    configCard: _hex(0x0D1932),
    configCardText: _hex(0xE6EEFF),
  ),
  ZedProfile(
    'sakura',
    'Sakura',
    5,
    false,
    download: _hex(0xFFA8C5),
    upload: _hex(0xFFC2D6),
    downloadTile: _hex(0x3E1226),
    uploadTile: _hex(0x45182C),
    connect: _hex(0xD9407A),
    connected: _hex(0x8E2751),
    tapHint: _hex(0xFFCFE0),
    serverCard: _hex(0x351023),
    serverActive: _hex(0xD9407A),
    configCard: _hex(0x3B1428),
    configCardText: _hex(0xFFF0F5),
  ),
  ZedProfile(
    'citrus',
    'Citrus',
    3,
    false,
    download: _hex(0xC7F24E),
    upload: _hex(0x8FD14F),
    downloadTile: _hex(0x243007),
    uploadTile: _hex(0x1E2A0A),
    connect: _hex(0x9BC91F),
    connected: _hex(0x3F6212),
    tapHint: _hex(0xDDF59A),
    serverCard: _hex(0x1E2708),
    serverActive: _hex(0x9BC91F),
    configCard: _hex(0x232E09),
    configCardText: _hex(0xF2FFD6),
  ),
  ZedProfile(
    'mono',
    'Mono',
    9,
    false,
    download: _hex(0xE4E4E7),
    upload: _hex(0xB4B4BB),
    downloadTile: _hex(0x1C1C1E),
    uploadTile: _hex(0x232326),
    connect: _hex(0x3F3F46),
    connected: _hex(0x71717A),
    tapHint: _hex(0xC7C7CC),
    serverCard: _hex(0x1A1A1C),
    serverActive: _hex(0x3F3F46),
    configCard: _hex(0x1D1D20),
    configCardText: _hex(0xF2F2F7),
  ),
  ZedProfile(
    'neonlime',
    'Neon Lime',
    3,
    true,
    download: _hex(0xD4FF3F),
    upload: _hex(0x9EE84A),
    downloadTile: _hex(0x0A0F00),
    uploadTile: _hex(0x0C1200),
    connect: _hex(0xC7F24E),
    connected: _hex(0x4A7C0F),
    tapHint: _hex(0xDFFF9E),
    serverCard: _hex(0x080B00),
    serverActive: _hex(0xC7F24E),
    configCard: _hex(0x0B1000),
    configCardText: _hex(0xEBFFC2),
  ),
  ZedProfile(
    'tokyo',
    'Tokyo',
    1,
    true,
    download: _hex(0x7AA2F7),
    upload: _hex(0xBB9AF7),
    downloadTile: _hex(0x0B0D17),
    uploadTile: _hex(0x11101F),
    connect: _hex(0x7AA2F7),
    connected: _hex(0xBB9AF7),
    tapHint: _hex(0x9AA5CE),
    serverCard: _hex(0x090B14),
    serverActive: _hex(0x7AA2F7),
    configCard: _hex(0x0C0F1A),
    configCardText: _hex(0xC0CAF5),
  ),
  ZedProfile(
    'solar',
    'Solar',
    4,
    false,
    download: _hex(0xFFD54F),
    upload: _hex(0xFFB300),
    downloadTile: _hex(0x3A2E05),
    uploadTile: _hex(0x33280A),
    connect: _hex(0xFFC107),
    connected: _hex(0x8D6E00),
    tapHint: _hex(0xFFE9A8),
    serverCard: _hex(0x2E2506),
    serverActive: _hex(0xFFC107),
    configCard: _hex(0x352A07),
    configCardText: _hex(0xFFF6DA),
  ),
  ZedProfile(
    'moss',
    'Moss',
    3,
    false,
    download: _hex(0x6EE7A8),
    upload: _hex(0x34D399),
    downloadTile: _hex(0x07231A),
    uploadTile: _hex(0x0A2A20),
    connect: _hex(0x10B981),
    connected: _hex(0x065F46),
    tapHint: _hex(0xA7F3D0),
    serverCard: _hex(0x061D16),
    serverActive: _hex(0x10B981),
    configCard: _hex(0x08251C),
    configCardText: _hex(0xE3FFF4),
  ),
  ZedProfile(
    'clay',
    'Clay',
    6,
    false,
    download: _hex(0xE0A08A),
    upload: _hex(0xD97757),
    downloadTile: _hex(0x33201A),
    uploadTile: _hex(0x3A231B),
    connect: _hex(0xD97757),
    connected: _hex(0x8C4A34),
    tapHint: _hex(0xF0C8B6),
    serverCard: _hex(0x2B1B15),
    serverActive: _hex(0xD97757),
    configCard: _hex(0x32201A),
    configCardText: _hex(0xFFEDE3),
  ),
];

ZedProfile? zedProfileOf(String id) {
  for (final p in zedProfiles) {
    if (p.id == id) return p;
  }
  return null;
}

/// `AppSettings.applyThemeProfile`: writes the profile's whole block
/// into the personalisation prefs (design/corner/connect untouched).
void applyZedProfile(PixelPrefs prefs, ZedProfile profile) {
  prefs.accentIndex = profile.accentIndex;
  prefs.amoled = profile.amoled;
  prefs.customDownload = profile.download.toARGB32();
  prefs.customUpload = profile.upload.toARGB32();
  prefs.customDownloadTile = profile.downloadTile.toARGB32();
  prefs.customUploadTile = profile.uploadTile.toARGB32();
  prefs.customConnect = profile.connect.toARGB32();
  prefs.customConnected = profile.connected.toARGB32();
  prefs.customTapHint = profile.tapHint.toARGB32();
  prefs.customServerCard = profile.serverCard.toARGB32();
  prefs.customServerActive = profile.serverActive.toARGB32();
  prefs.customConfigCard = profile.configCard.toARGB32();
  prefs.customConfigCardText = profile.configCardText.toARGB32();
  prefs.profileId = profile.id;
}

abstract final class ZedTheme {
  /// Builds the app's [ThemeData] for [prefs] at [brightness]; [locale]
  /// picks the font exactly as the app's theme always has.
  static ThemeData build(Brightness brightness, Locale locale, ZedPrefs prefs) {
    final dark = brightness == Brightness.dark;
    final font = languageFont(locale.languageCode);
    final bento = bentoTokensFor(
      prefs.bento.palette,
      dark,
      amoled: prefs.bento.amoled,
      seedArgb: pixelAccents[prefs.pixel.accentIndex.clamp(0, 9)].toARGB32(),
    );
    final glass = glassTokensFor(prefs.glass, dark);
    final (scheme, bg, surface, cardShape) = switch (prefs.design) {
      ZedDesign.bento => (
        bentoScheme(bento),
        bento.ground,
        bento.surface,
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            bentoCardRadius(prefs.bento.corners),
          ),
        ) as ShapeBorder,
      ),
      ZedDesign.pixel => (
        pixelScheme(prefs.pixel, brightness),
        dark ? const Color(0xFF111218) : const Color(0xFFF5F5FA),
        dark ? const Color(0xFF1A1B23) : Colors.white,
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            cornerStyleServerRadius(prefs.pixel.cornerStyle),
          ),
        ) as ShapeBorder,
      ),
      ZedDesign.old => (
        pixelScheme(prefs.old, brightness),
        dark ? const Color(0xFF111218) : const Color(0xFFF5F5FA),
        dark ? const Color(0xFF1A1B23) : Colors.white,
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            cornerStyleServerRadius(prefs.old.cornerStyle),
          ),
        ) as ShapeBorder,
      ),
      ZedDesign.glass => (
        glassScheme(glass),
        Colors.transparent,
        glass.module,
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))
            as ShapeBorder,
      ),
    };
    final theme = ThemeData(
      extensions: [
        if (prefs.design == ZedDesign.bento) ZedColors(bento),
        if (prefs.design == ZedDesign.glass) ZedGlass(glass),
      ],
      colorScheme: scheme,
      fontFamily: font,
      scaffoldBackgroundColor: bg,
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        shape: cardShape is RoundedRectangleBorder
            ? cardShape.copyWith(
                side: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.4),
                ),
              )
            : cardShape,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: prefs.design == ZedDesign.glass ? glass.sheet : null,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: prefs.design == ZedDesign.glass ? glass.sheet : null,
        shape: prefs.design == ZedDesign.glass
            ? const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(38)),
              )
            : null,
      ),
    );
    return theme.copyWith(
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: prefs.design == ZedDesign.bento
            ? bento.dock
            : prefs.design == ZedDesign.glass
            ? glass.chromeSolid
            : (dark ? const Color(0xFF15161D) : const Color(0xFFECECF4)),
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
        backgroundColor: prefs.design == ZedDesign.bento ? bento.dock : surface,
        indicatorColor: scheme.secondaryContainer,
      ),
    );
  }
}
