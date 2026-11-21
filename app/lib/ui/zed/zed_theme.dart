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

/// A (container, content) colour pair — the original's `BentoTone`.
/// Five of them ride along in every palette (blue, violet, cyan,
/// pink, coral) and feed both the tile colours and scheme roles.
class BentoTone {
  const BentoTone(this.container, this.content);

  final Color container;
  final Color content;
}

/// One Bento palette fully resolved for one brightness — the exact
/// `BentoColors` field set of the original (ZED-TOKENS-EXTRACT §1.1):
/// the ground the page sits on, the surfaces modules are made of, the
/// stage the hero module wears, the lime accent, the dock's own fill,
/// and the five tonal pairs. (Round 3: the pairs were missing from
/// the port entirely — the extract's palette tables omitted them,
/// but BentoPalette.kt carries them in all sixteen tables and the
/// tile/mono derivations; without them the scheme's secondary,
/// tertiary and dark errorContainer roles had no correct source.)
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
  );
}

/// The eight hardcoded palettes, dark (§1.2 of the extract).
const _bentoDark = <BentoPalette, BentoTokens>{
  BentoPalette.zedLime: BentoTokens(
    ground: Color(0xFF0B0A10),
    surface: Color(0xFF18161F),
    surface2: Color(0xFF24212D),
    line: Color(0xFF3A3646),
    ink: Color(0xFFEEEAF6),
    muted: Color(0xFFA6A0B8),
    stage: Color(0xFF311B6B),
    onStage: Color(0xFFEFE8FF),
    chipOnStage: Color(0x1FFFFFFF),
    goodOnStage: Color(0xFF9BF0AE),
    lime: Color(0xFFC7F24E),
    onLime: Color(0xFF1A2200),
    blue: BentoTone(Color(0xFF15294A), Color(0xFFCFE1FF)),
    violet: BentoTone(Color(0xFF2A2352), Color(0xFFDDD5FF)),
    cyan: BentoTone(Color(0xFF103D3A), Color(0xFFB3F1EC)),
    pink: BentoTone(Color(0xFF4A1C35), Color(0xFFFFD0E5)),
    coral: BentoTone(Color(0xFF4A251D), Color(0xFFFFD3C6)),
    good: Color(0xFF7BE495),
    mid: Color(0xFFF2C14E),
    bad: Color(0xFFFF8A80),
    selected: Color(0xFF2B1D57),
    dock: Color(0xFF1E1B27),
    dockLine: Color(0x24FFFFFF),
    danger: Color(0xFFFFB4AB),
    onDanger: Color(0xFF690005),
  ),
  BentoPalette.citrus: BentoTokens(
    ground: Color(0xFF0C0D07),
    surface: Color(0xFF181A0F),
    surface2: Color(0xFF23261A),
    line: Color(0xFF3A3D2A),
    ink: Color(0xFFF1F2E4),
    muted: Color(0xFFB0B39A),
    stage: Color(0xFF2D3A0B),
    onStage: Color(0xFFEEF8CF),
    chipOnStage: Color(0x1FFFFFFF),
    goodOnStage: Color(0xFF9BF0AE),
    lime: Color(0xFFE2F53A),
    onLime: Color(0xFF1F2400),
    blue: BentoTone(Color(0xFF3B3608), Color(0xFFFFF3A1)),
    violet: BentoTone(Color(0xFF123A2A), Color(0xFFB9F5D7)),
    cyan: BentoTone(Color(0xFF22370F), Color(0xFFD3F5A7)),
    pink: BentoTone(Color(0xFF40280C), Color(0xFFFFD6A6)),
    coral: BentoTone(Color(0xFF43201A), Color(0xFFFFC8BC)),
    good: Color(0xFF7BE495),
    mid: Color(0xFFF2C14E),
    bad: Color(0xFFFF8A80),
    selected: Color(0xFF3A4A12),
    dock: Color(0xFF23261A),
    dockLine: Color(0x24FFFFFF),
    danger: Color(0xFFFFB4AB),
    onDanger: Color(0xFF690005),
  ),
  BentoPalette.matcha: BentoTokens(
    ground: Color(0xFF0A0D0A),
    surface: Color(0xFF151A15),
    surface2: Color(0xFF20271F),
    line: Color(0xFF364034),
    ink: Color(0xFFE8F0E6),
    muted: Color(0xFFA3B09F),
    stage: Color(0xFF1F3D27),
    onStage: Color(0xFFDDF3E2),
    chipOnStage: Color(0x1FFFFFFF),
    goodOnStage: Color(0xFF9BF0AE),
    lime: Color(0xFFB4E36B),
    onLime: Color(0xFF172600),
    blue: BentoTone(Color(0xFF1E3326), Color(0xFFCDEDD6)),
    violet: BentoTone(Color(0xFF2C3416), Color(0xFFE1EFB6)),
    cyan: BentoTone(Color(0xFF0F393A), Color(0xFFB2EDEE)),
    pink: BentoTone(Color(0xFF3D2619), Color(0xFFF4CDB6)),
    coral: BentoTone(Color(0xFF36301E), Color(0xFFF2E6C2)),
    good: Color(0xFF7BE495),
    mid: Color(0xFFF2C14E),
    bad: Color(0xFFFF8A80),
    selected: Color(0xFF28452F),
    dock: Color(0xFF20271F),
    dockLine: Color(0x24FFFFFF),
    danger: Color(0xFFFFB4AB),
    onDanger: Color(0xFF690005),
  ),
  BentoPalette.neon: BentoTokens(
    ground: Color(0xFF08070C),
    surface: Color(0xFF15131C),
    surface2: Color(0xFF201D2A),
    line: Color(0xFF383346),
    ink: Color(0xFFF2EEFA),
    muted: Color(0xFFABA3BF),
    stage: Color(0xFF3D0B4F),
    onStage: Color(0xFFFBDDFF),
    chipOnStage: Color(0x1FFFFFFF),
    goodOnStage: Color(0xFF9BF0AE),
    lime: Color(0xFFB9FF3B),
    onLime: Color(0xFF142400),
    blue: BentoTone(Color(0xFF4A0E3B), Color(0xFFFFC1EA)),
    violet: BentoTone(Color(0xFF07344A), Color(0xFFA3EAFF)),
    cyan: BentoTone(Color(0xFF2B1657), Color(0xFFE1D0FF)),
    pink: BentoTone(Color(0xFF373A08), Color(0xFFF8FFA0)),
    coral: BentoTone(Color(0xFF4A1810), Color(0xFFFFC5B5)),
    good: Color(0xFF7BE495),
    mid: Color(0xFFF2C14E),
    bad: Color(0xFFFF8A80),
    selected: Color(0xFF4A1060),
    dock: Color(0xFF201D2A),
    dockLine: Color(0x24FFFFFF),
    danger: Color(0xFFFFB4AB),
    onDanger: Color(0xFF690005),
  ),
  BentoPalette.pistachio: BentoTokens(
    ground: Color(0xFF0B0C0A),
    surface: Color(0xFF171915),
    surface2: Color(0xFF22251F),
    line: Color(0xFF393D34),
    ink: Color(0xFFEEF1E9),
    muted: Color(0xFFA8AE9F),
    stage: Color(0xFF2B2348),
    onStage: Color(0xFFE9E2FF),
    chipOnStage: Color(0x1FFFFFFF),
    goodOnStage: Color(0xFF9BF0AE),
    lime: Color(0xFFD3F2A2),
    onLime: Color(0xFF1E2A08),
    blue: BentoTone(Color(0xFF2A3420), Color(0xFFDDEFC7)),
    violet: BentoTone(Color(0xFF2C2547), Color(0xFFE2DAFF)),
    cyan: BentoTone(Color(0xFF14363A), Color(0xFFC2EDF0)),
    pink: BentoTone(Color(0xFF43242E), Color(0xFFFFD6E1)),
    coral: BentoTone(Color(0xFF3A3420), Color(0xFFF7EBC4)),
    good: Color(0xFF7BE495),
    mid: Color(0xFFF2C14E),
    bad: Color(0xFFFF8A80),
    selected: Color(0xFF352C57),
    dock: Color(0xFF22251F),
    dockLine: Color(0x24FFFFFF),
    danger: Color(0xFFFFB4AB),
    onDanger: Color(0xFF690005),
  ),
  BentoPalette.ocean: BentoTokens(
    ground: Color(0xFF070B10),
    surface: Color(0xFF121923),
    surface2: Color(0xFF1C2431),
    line: Color(0xFF313D4F),
    ink: Color(0xFFE7EEF8),
    muted: Color(0xFF9FAABD),
    stage: Color(0xFF0E2F57),
    onStage: Color(0xFFD8E9FF),
    chipOnStage: Color(0x1FFFFFFF),
    goodOnStage: Color(0xFF9BF0AE),
    lime: Color(0xFF5CF2C8),
    onLime: Color(0xFF00281D),
    blue: BentoTone(Color(0xFF10304F), Color(0xFFC4E2FF)),
    violet: BentoTone(Color(0xFF1E2357), Color(0xFFD6D9FF)),
    cyan: BentoTone(Color(0xFF0A3838), Color(0xFFA8F0EC)),
    pink: BentoTone(Color(0xFF0A3340), Color(0xFFA6E8FF)),
    coral: BentoTone(Color(0xFF38301F), Color(0xFFF2E2BA)),
    good: Color(0xFF7BE495),
    mid: Color(0xFFF2C14E),
    bad: Color(0xFFFF8A80),
    selected: Color(0xFF123A6A),
    dock: Color(0xFF1C2431),
    dockLine: Color(0x24FFFFFF),
    danger: Color(0xFFFFB4AB),
    onDanger: Color(0xFF690005),
  ),
  BentoPalette.sunset: BentoTokens(
    ground: Color(0xFF0E0A09),
    surface: Color(0xFF1C1513),
    surface2: Color(0xFF28201D),
    line: Color(0xFF43362F),
    ink: Color(0xFFF8EDE8),
    muted: Color(0xFFBBA79E),
    stage: Color(0xFF4A1F12),
    onStage: Color(0xFFFFE3D6),
    chipOnStage: Color(0x1FFFFFFF),
    goodOnStage: Color(0xFF9BF0AE),
    lime: Color(0xFFFFB547),
    onLime: Color(0xFF2E1800),
    blue: BentoTone(Color(0xFF4A2A16), Color(0xFFFFD8B8)),
    violet: BentoTone(Color(0xFF2E1A40), Color(0xFFE6D2FF)),
    cyan: BentoTone(Color(0xFF3F3110), Color(0xFFFFE7A3)),
    pink: BentoTone(Color(0xFF4A1A2A), Color(0xFFFFC6D9)),
    coral: BentoTone(Color(0xFF4A1F1A), Color(0xFFFFC4B8)),
    good: Color(0xFF7BE495),
    mid: Color(0xFFF2C14E),
    bad: Color(0xFFFF8A80),
    selected: Color(0xFF5A2A18),
    dock: Color(0xFF28201D),
    dockLine: Color(0x24FFFFFF),
    danger: Color(0xFFFFB4AB),
    onDanger: Color(0xFF690005),
  ),
  BentoPalette.berry: BentoTokens(
    ground: Color(0xFF0D080C),
    surface: Color(0xFF1B1219),
    surface2: Color(0xFF271B24),
    line: Color(0xFF42303D),
    ink: Color(0xFFF7EAF2),
    muted: Color(0xFFB8A2B0),
    stage: Color(0xFF4A0E3A),
    onStage: Color(0xFFFFD9F2),
    chipOnStage: Color(0x1FFFFFFF),
    goodOnStage: Color(0xFF9BF0AE),
    lime: Color(0xFFD7F59A),
    onLime: Color(0xFF1E2A06),
    blue: BentoTone(Color(0xFF4A1230), Color(0xFFFFC6E0)),
    violet: BentoTone(Color(0xFF341B4A), Color(0xFFEBD3FF)),
    cyan: BentoTone(Color(0xFF123A2C), Color(0xFFB8F2D8)),
    pink: BentoTone(Color(0xFF4A1C24), Color(0xFFFFCCD5)),
    coral: BentoTone(Color(0xFF46281A), Color(0xFFFFD9C2)),
    good: Color(0xFF7BE495),
    mid: Color(0xFFF2C14E),
    bad: Color(0xFFFF8A80),
    selected: Color(0xFF5A1548),
    dock: Color(0xFF271B24),
    dockLine: Color(0x24FFFFFF),
    danger: Color(0xFFFFB4AB),
    onDanger: Color(0xFF690005),
  ),
};

/// The eight hardcoded palettes, light (§1.3 of the extract).
const _bentoLight = <BentoPalette, BentoTokens>{
  BentoPalette.zedLime: BentoTokens(
    ground: Color(0xFFF6F6F0),
    surface: Color(0xFFEAEAE2),
    surface2: Color(0xFFDCDCD2),
    line: Color(0xFFC5C5BA),
    ink: Color(0xFF16161C),
    muted: Color(0xFF55555F),
    stage: Color(0xFF2A1361),
    onStage: Color(0xFFF1EBFF),
    chipOnStage: Color(0x24FFFFFF),
    goodOnStage: Color(0xFF9BF0AE),
    lime: Color(0xFFC7F24E),
    onLime: Color(0xFF1A2200),
    blue: BentoTone(Color(0xFFD4E4FF), Color(0xFF123A70)),
    violet: BentoTone(Color(0xFFE3DBFF), Color(0xFF36268A)),
    cyan: BentoTone(Color(0xFFC6F1ED), Color(0xFF0B4A45)),
    pink: BentoTone(Color(0xFFFFD6E7), Color(0xFF6E1543)),
    coral: BentoTone(Color(0xFFFFDCCD), Color(0xFF6D2914)),
    good: Color(0xFF16803F),
    mid: Color(0xFF8A5A00),
    bad: Color(0xFFB3261E),
    selected: Color(0xFFE3DBFF),
    dock: Color(0xFFFFFFFF),
    dockLine: Color(0x1A16161C),
    danger: Color(0xFFFFDAD6),
    onDanger: Color(0xFF410002),
  ),
  BentoPalette.citrus: BentoTokens(
    ground: Color(0xFFF7F8EC),
    surface: Color(0xFFEBEDDB),
    surface2: Color(0xFFDEE1C9),
    line: Color(0xFFC6C9AE),
    ink: Color(0xFF17180F),
    muted: Color(0xFF565A44),
    stage: Color(0xFF2D3A0B),
    onStage: Color(0xFFF2FBD6),
    chipOnStage: Color(0x24FFFFFF),
    goodOnStage: Color(0xFF9BF0AE),
    lime: Color(0xFFD8EE2C),
    onLime: Color(0xFF1F2400),
    blue: BentoTone(Color(0xFFFFF3B0), Color(0xFF5A4A00)),
    violet: BentoTone(Color(0xFFCFF5E2), Color(0xFF0E4A33)),
    cyan: BentoTone(Color(0xFFE0F5C0), Color(0xFF2C4A0C)),
    pink: BentoTone(Color(0xFFFFE0BE), Color(0xFF6A3A06)),
    coral: BentoTone(Color(0xFFFFD9D0), Color(0xFF6E2414)),
    good: Color(0xFF16803F),
    mid: Color(0xFF8A5A00),
    bad: Color(0xFFB3261E),
    selected: Color(0xFFE5F0B8),
    dock: Color(0xFFFFFFFF),
    dockLine: Color(0x1A16161C),
    danger: Color(0xFFFFDAD6),
    onDanger: Color(0xFF410002),
  ),
  BentoPalette.matcha: BentoTokens(
    ground: Color(0xFFF4F7F2),
    surface: Color(0xFFE7EDE4),
    surface2: Color(0xFFD9E1D5),
    line: Color(0xFFBFC9BB),
    ink: Color(0xFF141A13),
    muted: Color(0xFF4E594B),
    stage: Color(0xFF1F3D27),
    onStage: Color(0xFFE2F6E7),
    chipOnStage: Color(0x24FFFFFF),
    goodOnStage: Color(0xFF9BF0AE),
    lime: Color(0xFFA6D65A),
    onLime: Color(0xFF172600),
    blue: BentoTone(Color(0xFFD3EEDB), Color(0xFF1C4A2B)),
    violet: BentoTone(Color(0xFFE6F0C2), Color(0xFF3F4A0E)),
    cyan: BentoTone(Color(0xFFC6EEEE), Color(0xFF0B4748)),
    pink: BentoTone(Color(0xFFF7DCCB), Color(0xFF6A3415)),
    coral: BentoTone(Color(0xFFF3EAC9), Color(0xFF5A4A14)),
    good: Color(0xFF16803F),
    mid: Color(0xFF8A5A00),
    bad: Color(0xFFB3261E),
    selected: Color(0xFFD6EAD9),
    dock: Color(0xFFFFFFFF),
    dockLine: Color(0x1A16161C),
    danger: Color(0xFFFFDAD6),
    onDanger: Color(0xFF410002),
  ),
  BentoPalette.neon: BentoTokens(
    ground: Color(0xFFF8F6FB),
    surface: Color(0xFFECE8F2),
    surface2: Color(0xFFDED8E8),
    line: Color(0xFFC5BDD3),
    ink: Color(0xFF15121C),
    muted: Color(0xFF554C66),
    stage: Color(0xFF3D0B4F),
    onStage: Color(0xFFFCE2FF),
    chipOnStage: Color(0x24FFFFFF),
    goodOnStage: Color(0xFF9BF0AE),
    lime: Color(0xFFA8F21E),
    onLime: Color(0xFF142400),
    blue: BentoTone(Color(0xFFFFD6F1), Color(0xFF6E0F55)),
    violet: BentoTone(Color(0xFFC8F1FF), Color(0xFF00475E)),
    cyan: BentoTone(Color(0xFFE7DBFF), Color(0xFF3D1F80)),
    pink: BentoTone(Color(0xFFF6FAB4), Color(0xFF4F5200)),
    coral: BentoTone(Color(0xFFFFDCD2), Color(0xFF741D0A)),
    good: Color(0xFF16803F),
    mid: Color(0xFF8A5A00),
    bad: Color(0xFFB3261E),
    selected: Color(0xFFF1DDF7),
    dock: Color(0xFFFFFFFF),
    dockLine: Color(0x1A16161C),
    danger: Color(0xFFFFDAD6),
    onDanger: Color(0xFF410002),
  ),
  BentoPalette.pistachio: BentoTokens(
    ground: Color(0xFFF6F7F2),
    surface: Color(0xFFEAECE3),
    surface2: Color(0xFFDDE0D4),
    line: Color(0xFFC4C8BA),
    ink: Color(0xFF151713),
    muted: Color(0xFF535849),
    stage: Color(0xFF2B2348),
    onStage: Color(0xFFEEE8FF),
    chipOnStage: Color(0x24FFFFFF),
    goodOnStage: Color(0xFF9BF0AE),
    lime: Color(0xFFC6EB8A),
    onLime: Color(0xFF1E2A08),
    blue: BentoTone(Color(0xFFE4F0D2), Color(0xFF344A1A)),
    violet: BentoTone(Color(0xFFE7E0FF), Color(0xFF3A2C7A)),
    cyan: BentoTone(Color(0xFFCFEFF1), Color(0xFF134A50)),
    pink: BentoTone(Color(0xFFFFDCE6), Color(0xFF6E2338)),
    coral: BentoTone(Color(0xFFF7EDCC), Color(0xFF5A4614)),
    good: Color(0xFF16803F),
    mid: Color(0xFF8A5A00),
    bad: Color(0xFFB3261E),
    selected: Color(0xFFE3DDF7),
    dock: Color(0xFFFFFFFF),
    dockLine: Color(0x1A16161C),
    danger: Color(0xFFFFDAD6),
    onDanger: Color(0xFF410002),
  ),
  BentoPalette.ocean: BentoTokens(
    ground: Color(0xFFF3F7FB),
    surface: Color(0xFFE4EBF3),
    surface2: Color(0xFFD5DEE9),
    line: Color(0xFFB9C5D4),
    ink: Color(0xFF0F1620),
    muted: Color(0xFF4A5768),
    stage: Color(0xFF0E2F57),
    onStage: Color(0xFFDDEBFF),
    chipOnStage: Color(0x24FFFFFF),
    goodOnStage: Color(0xFF9BF0AE),
    lime: Color(0xFF3BE0B4),
    onLime: Color(0xFF00281D),
    blue: BentoTone(Color(0xFFD2E6FF), Color(0xFF0F3B6E)),
    violet: BentoTone(Color(0xFFDCDEFF), Color(0xFF262E80)),
    cyan: BentoTone(Color(0xFFC4F1EC), Color(0xFF0A4A45)),
    pink: BentoTone(Color(0xFFC6ECF7), Color(0xFF064559)),
    coral: BentoTone(Color(0xFFF3E8CC), Color(0xFF5A4614)),
    good: Color(0xFF16803F),
    mid: Color(0xFF8A5A00),
    bad: Color(0xFFB3261E),
    selected: Color(0xFFD6E5F7),
    dock: Color(0xFFFFFFFF),
    dockLine: Color(0x1A16161C),
    danger: Color(0xFFFFDAD6),
    onDanger: Color(0xFF410002),
  ),
  BentoPalette.sunset: BentoTokens(
    ground: Color(0xFFFBF6F3),
    surface: Color(0xFFF1E8E3),
    surface2: Color(0xFFE5D9D2),
    line: Color(0xFFCDBDB4),
    ink: Color(0xFF1C1310),
    muted: Color(0xFF64514A),
    stage: Color(0xFF4A1F12),
    onStage: Color(0xFFFFE6DA),
    chipOnStage: Color(0x24FFFFFF),
    goodOnStage: Color(0xFF9BF0AE),
    lime: Color(0xFFFFA62B),
    onLime: Color(0xFF2E1800),
    blue: BentoTone(Color(0xFFFFE2C9), Color(0xFF6A3A10)),
    violet: BentoTone(Color(0xFFEBDDFF), Color(0xFF4A2A70)),
    cyan: BentoTone(Color(0xFFFFEDB8), Color(0xFF5A4300)),
    pink: BentoTone(Color(0xFFFFD9E5), Color(0xFF6E1A38)),
    coral: BentoTone(Color(0xFFFFDAD0), Color(0xFF742214)),
    good: Color(0xFF16803F),
    mid: Color(0xFF8A5A00),
    bad: Color(0xFFB3261E),
    selected: Color(0xFFF5DCD0),
    dock: Color(0xFFFFFFFF),
    dockLine: Color(0x1A16161C),
    danger: Color(0xFFFFDAD6),
    onDanger: Color(0xFF410002),
  ),
  BentoPalette.berry: BentoTokens(
    ground: Color(0xFFFBF5F8),
    surface: Color(0xFFF1E6EC),
    surface2: Color(0xFFE5D6DF),
    line: Color(0xFFCDB9C5),
    ink: Color(0xFF1C1018),
    muted: Color(0xFF634C5A),
    stage: Color(0xFF4A0E3A),
    onStage: Color(0xFFFFDDF3),
    chipOnStage: Color(0x24FFFFFF),
    goodOnStage: Color(0xFF9BF0AE),
    lime: Color(0xFFC4EC7C),
    onLime: Color(0xFF1E2A06),
    blue: BentoTone(Color(0xFFFFD7E9), Color(0xFF6E1240)),
    violet: BentoTone(Color(0xFFEEDDFF), Color(0xFF4F2A72)),
    cyan: BentoTone(Color(0xFFC9F2DF), Color(0xFF0F4A34)),
    pink: BentoTone(Color(0xFFFFD9E0), Color(0xFF6E1C2C)),
    coral: BentoTone(Color(0xFFFFE0CE), Color(0xFF6A3414)),
    good: Color(0xFF16803F),
    mid: Color(0xFF8A5A00),
    bad: Color(0xFFB3261E),
    selected: Color(0xFFF5D8E9),
    dock: Color(0xFFFFFFFF),
    dockLine: Color(0x1A16161C),
    danger: Color(0xFFFFDAD6),
    onDanger: Color(0xFF410002),
  ),
};

/// The four algorithmic palettes derive from the USER'S accent seed
/// in the original — `system?.primary ?: accentSeed(accentColor)`
/// (Theme.kt:64), the same seed the Pixel accent presets provide.
/// Round 4: the port previously substituted four fixed invented
/// seeds; it now takes the accent seed like the original. The
/// fallback (picker dots, tests) is the default accent, Iris.

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
  // The tile pairs (§1.4): hue offsets +60/+120/+180/+240/+300 at
  // the kind's tile chroma, with per-kind tone pairs.
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
  // The mono tile pairs (§1.4): one near-neutral palette, content
  // pinned at tone 94 (dark) / 10 (light).
  BentoTone tile(int dTone, int lTone) => dark
      ? BentoTone(_tone(n, dTone), _tone(n, 94))
      : BentoTone(_tone(n, lTone), _tone(n, 10));
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
  );
}

/// Resolves a palette for a brightness, with the AMOLED override the
/// original applies to every palette in the dark (pure-black ground).
BentoTokens bentoTokensFor(
  BentoPalette palette,
  bool dark, {
  bool amoled = false,
  int seed = 0xFF5646D6, // accentSeed() of the default accent (Iris)
}) {
  var tokens = switch (palette) {
    BentoPalette.accent || BentoPalette.pastel || BentoPalette.vivid =>
      _tonalTokens(seed, dark, palette),
    BentoPalette.mono => _monoTokens(seed, dark),
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

/// Pixel/Old's ten accent presets (§3.1): the SEED is each preset's
/// LIGHT colour — `accentSeed()` in the original returns `.light` in
/// both brightnesses. (Round 2 corrected 8 of the 10: the port had
/// substituted generic Material-700 colours, so most accents built a
/// scheme from the wrong hue/chroma.)
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

/// Corner radius for a design's modules: Bento follows its corner style
/// (Leaf is asymmetric — see [bentoModuleShape]), Glass modules are
/// always 24. Pixel/Old: the original's personalization offers
/// Squared 6 / Rounded 22 / Pill 34; the port models only the
/// Rounded default (22) — the corner-style preference itself is
/// not ported (documented deviation, round 4).
double zedModuleRadius(ZedPrefs prefs) => switch (prefs.design) {
  ZedDesign.bento => switch (prefs.bentoCorner) {
    BentoCorner.leaf => 36,
    BentoCorner.round => 36,
    BentoCorner.soft => 24,
  },
  ZedDesign.glass => 24,
  ZedDesign.pixel || ZedDesign.old => 22,
};

/// Bento's module (card) shape: BentoShapes.card() — a UNIFORM
/// 30 dp (20 dp Soft) in every corner style, Leaf included
/// (BentoKit.kt). Rounds 1–3 used tile(prominent = true)'s 36 dp
/// values here, which made every card and group one step rounder
/// than the original's cards; the prominent hub tile (36/36/24)
/// has no separate widget in the port (round 4, documented).
BorderRadiusGeometry bentoModuleRadius(BentoCorner corner) => switch (corner) {
  BentoCorner.soft => BorderRadius.circular(20),
  _ => BorderRadius.circular(30),
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

/// Bento's block shape (BentoShapes.block()): the connect controls'
/// own radius — 26 dp in every corner style, 18 for Soft. Uniform
/// even for Leaf (the Leaf asymmetry lives in hero/tile shapes).
BorderRadiusGeometry bentoBlockRadius(BentoCorner corner) =>
    BorderRadius.circular(corner == BentoCorner.soft ? 18 : 26);

/// Bento's prominent tile shape (BentoShapes.tile(true)): Leaf is
/// the asymmetric (36, 36, 36, 12), Round a uniform 36, Soft 24.
/// (These are the values rounds 1–3 wrongly used for EVERY module;
/// since round 4 they belong to the Tile connect control alone.)
BorderRadiusGeometry bentoTileRadius(BentoCorner corner) => switch (corner) {
  BentoCorner.leaf => const BorderRadiusDirectional.only(
    topStart: Radius.circular(36),
    topEnd: Radius.circular(36),
    bottomEnd: Radius.circular(36),
    bottomStart: Radius.circular(12),
  ),
  BentoCorner.round => BorderRadius.circular(36),
  BentoCorner.soft => BorderRadius.circular(24),
};

/// The original's glassColorScheme() verbatim (GlassTheme.kt): a
/// hand-mapped table over the tint and the fixed iOS system colours
/// — NOT a seed-generated scheme. (Round 3, finding T-4: the port
/// used ColorScheme.fromSeed with the fidelity variant, which only
/// approximates the primary and invents tonal error/tertiary/
/// surface colours the original fixes by hand.)
ColorScheme _glassScheme(ZedPrefs prefs, bool dark) {
  final tint = glassTintColor(prefs.glassTint, dark);
  const white = Colors.white;
  const black = Colors.black;
  final green = dark ? const Color(0xFF30D158) : const Color(0xFF34C759);
  final red = dark ? const Color(0xFFFF4245) : const Color(0xFFFF383C);
  Color lerp(Color a, Color b, double t) => Color.lerp(a, b, t)!;
  if (dark) {
    const base = Color(0xFF1C1C1E);
    return ColorScheme(
      brightness: Brightness.dark,
      primary: tint,
      onPrimary: white,
      primaryContainer: lerp(base, tint, 0.32),
      onPrimaryContainer: lerp(tint, white, 0.55),
      inversePrimary: lerp(tint, black, 0.2),
      secondary: tint,
      onSecondary: white,
      secondaryContainer: const Color(0xFF2C2C2E),
      onSecondaryContainer: white,
      tertiary: green,
      onTertiary: black,
      tertiaryContainer: lerp(base, green, 0.3),
      onTertiaryContainer: lerp(green, white, 0.5),
      error: red,
      onError: white,
      errorContainer: lerp(base, red, 0.3),
      onErrorContainer: lerp(red, white, 0.5),
      surface: black,
      onSurface: white,
      onSurfaceVariant: const Color(0xFF8D8D93),
      surfaceTint: tint,
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
    primary: tint,
    onPrimary: white,
    primaryContainer: lerp(white, tint, 0.16),
    onPrimaryContainer: lerp(tint, black, 0.45),
    inversePrimary: lerp(tint, white, 0.35),
    secondary: tint,
    onSecondary: white,
    secondaryContainer: const Color(0xFFE5E5EA),
    onSecondaryContainer: black,
    tertiary: green,
    onTertiary: white,
    tertiaryContainer: lerp(white, green, 0.18),
    onTertiaryContainer: lerp(green, black, 0.5),
    error: red,
    onError: white,
    errorContainer: lerp(white, red, 0.15),
    onErrorContainer: lerp(red, black, 0.45),
    surface: const Color(0xFFF2F2F7),
    onSurface: black,
    onSurfaceVariant: const Color(0xFF8A8A8E),
    surfaceTint: tint,
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

abstract final class ZedTheme {
  /// Builds the app's [ThemeData] for [prefs] at [brightness]; [locale]
  /// picks the font exactly as the app's theme always has.
  static ThemeData build(Brightness brightness, Locale locale, ZedPrefs prefs) {
    final dark = brightness == Brightness.dark;
    final font = languageFont(locale.languageCode);
    final bento = bentoTokensFor(
      prefs.bentoPalette,
      dark,
      amoled: prefs.bentoAmoled,
      // The original's bentoSeed: the user's accent colour
      // (Theme.kt:64). Dynamic system colour is not read by the
      // port; the accent preset is the seed, as on a device
      // without dynamic colour.
      seed: pixelAccents[prefs.pixelAccent.clamp(0, 9)].toARGB32(),
    );
    final (scheme, bg, surface) = switch (prefs.design) {
      ZedDesign.bento => (
        // The original's bentoColorScheme() verbatim (BentoTheme.kt):
        // light leads with the stage, dark with the lime; secondary
        // and tertiary are the violet/cyan pairs (content on
        // container, as the source maps them); the surface IS the
        // ground; the dark error container is the palette's own
        // coral pair. (Round 3, findings T-1/T-2/T-3: the port's
        // earlier mapping invented its roles — primary/container
        // swapped in the light, secondary/tertiary pointing at the
        // stage/selected greys, and round 2's dark errorContainer
        // was a generic Material red no palette contains.)
        ColorScheme(
          brightness: brightness,
          primary: dark ? bento.lime : bento.stage,
          onPrimary: dark ? bento.onLime : bento.onStage,
          primaryContainer: dark ? bento.stage : bento.lime,
          onPrimaryContainer: dark ? bento.onStage : bento.onLime,
          inversePrimary: dark ? bento.stage : bento.lime,
          secondary: bento.violet.content,
          onSecondary: bento.violet.container,
          secondaryContainer: bento.violet.container,
          onSecondaryContainer: bento.violet.content,
          tertiary: bento.cyan.content,
          onTertiary: bento.cyan.container,
          tertiaryContainer: bento.cyan.container,
          onTertiaryContainer: bento.cyan.content,
          error: dark ? bento.danger : bento.bad,
          onError: dark ? bento.onDanger : Colors.white,
          errorContainer: dark ? bento.coral.container : bento.danger,
          onErrorContainer: dark ? bento.coral.content : bento.onDanger,
          surface: bento.ground,
          onSurface: bento.ink,
          onSurfaceVariant: bento.muted,
          surfaceTint: dark ? bento.lime : bento.stage,
          inverseSurface: bento.ink,
          onInverseSurface: bento.ground,
          // muted at 70% composited over the ground.
          outline: Color.alphaBlend(
            bento.muted.withValues(alpha: 0.7),
            bento.ground,
          ),
          outlineVariant: bento.line,
          shadow: Colors.black,
          scrim: Colors.black,
          surfaceBright: dark ? bento.surface2 : bento.ground,
          surfaceDim: dark ? bento.ground : bento.surface2,
          surfaceContainerLowest: dark ? bento.ground : Colors.white,
          surfaceContainerLow: Color.lerp(bento.ground, bento.surface, 0.5)!,
          surfaceContainer: bento.surface,
          surfaceContainerHigh: bento.surface,
          surfaceContainerHighest: dark
              ? Color.lerp(bento.surface2, bento.line, 0.25)!
              : bento.surface2,
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
        _glassScheme(prefs, dark),
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
      extensions: [if (prefs.design == ZedDesign.bento) ZedColors(bento)],
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
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
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
      // The scheme itself must carry the AMOLED surfaces too: the
      // scaffold/card tuple alone leaves Material surfaces and the
      // dark rail (which blends scheme.surface) on the seeded colour.
      // The override is the documented eight-role set (§3.1), not
      // just `surface` — dialogs, menus and sheets read the
      // surfaceContainer roles (round-2 finding T2).
      return (
        scheme.copyWith(
          surface: const Color(0xFF000000),
          surfaceDim: const Color(0xFF000000),
          surfaceContainerLowest: const Color(0xFF000000),
          surfaceContainerLow: const Color(0xFF0B0B0B),
          surfaceContainer: const Color(0xFF0F0F0F),
          surfaceContainerHigh: const Color(0xFF161616),
          surfaceContainerHighest: const Color(0xFF1E1E1E),
          surfaceBright: const Color(0xFF1A1A1A),
        ),
        Colors.black,
        const Color(0xFF000000),
      );
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
  Color(0xFF3CD3FE), // cyan — the original's tint set has Cyan here;
  // "Yellow" exists only as a colour function, with no GlassTint
  // (extract §2.5) — round-2 finding T4.
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
  Color(0xFF00C0E8), // cyan (light pair of #3CD3FE)
  Color(0xFF00C8B3),
  Color(0xFF6155F5),
  Color(0xFFAC7F5E),
  Color(0xFF8E8E93),
];

/// A Glass tint by index, in the brightness's own value.
Color glassTintColor(int index, bool dark) => (dark
    ? glassTintColors
    : glassTintColorsLight)[index.clamp(0, glassTintColors.length - 1)];
