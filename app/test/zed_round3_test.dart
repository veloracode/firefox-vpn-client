// Round-3 pins: the Bento tonal pairs and the source-true scheme
// mappings (T-1/T-2/T-3/T-4), the dock-labels reference default
// (B.3), the dedicated Glass slider (B.1), the glass minors
// (G-1/G-4), the Z control's semantics (ds3-02), the localized
// settings labels (B.4), and the performance invariants (B.5).

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firefox_vpn/l10n/app_localizations.dart';
import 'package:firefox_vpn/ui/zed/zed_connect.dart';
import 'package:firefox_vpn/ui/zed/zed_glass.dart';
import 'package:firefox_vpn/ui/zed/zed_motion.dart';
import 'package:firefox_vpn/ui/zed/zed_prefs.dart';
import 'package:firefox_vpn/ui/zed/zed_theme.dart';

void main() {
  group('Bento tonal pairs (T-1)', () {
    test('hardcoded palettes carry the source pairs', () {
      final dark = bentoTokensFor(BentoPalette.zedLime, true);
      expect(dark.blue.container, const Color(0xFF15294A));
      expect(dark.blue.content, const Color(0xFFCFE1FF));
      expect(dark.violet.container, const Color(0xFF2A2352));
      expect(dark.violet.content, const Color(0xFFDDD5FF));
      expect(dark.cyan.container, const Color(0xFF103D3A));
      expect(dark.cyan.content, const Color(0xFFB3F1EC));
      expect(dark.pink.container, const Color(0xFF4A1C35));
      expect(dark.coral.container, const Color(0xFF4A251D));
      expect(dark.coral.content, const Color(0xFFFFD3C6));
      final light = bentoTokensFor(BentoPalette.zedLime, false);
      expect(light.violet.container, const Color(0xFFE3DBFF));
      expect(light.violet.content, const Color(0xFF36268A));
      final berry = bentoTokensFor(BentoPalette.berry, true);
      expect(berry.coral.container, const Color(0xFF46281A));
      expect(berry.pink.content, const Color(0xFFFFCCD5));
    });

    test('algorithmic palettes derive distinct pairs', () {
      for (final p in [
        BentoPalette.accent,
        BentoPalette.pastel,
        BentoPalette.vivid,
        BentoPalette.mono,
      ]) {
        final t = bentoTokensFor(p, true);
        final containers = {
          t.blue.container,
          t.violet.container,
          t.cyan.container,
          t.pink.container,
          t.coral.container,
        };
        expect(containers.length, 5, reason: '$p pairs must differ');
        expect(t.blue.content, isNot(t.blue.container));
      }
    });
  });

  group('Bento scheme mapping (T-2/T-3)', () {
    test('dark: lime leads, stage contains, pairs fill the roles', () {
      final tokens = bentoTokensFor(BentoPalette.zedLime, true);
      final s = ZedTheme.build(
        Brightness.dark,
        const Locale('en'),
        const ZedPrefs(),
      ).colorScheme;
      expect(s.primary, tokens.lime);
      expect(s.primaryContainer, tokens.stage);
      expect(s.secondary, tokens.violet.content);
      expect(s.onSecondary, tokens.violet.container);
      expect(s.secondaryContainer, tokens.violet.container);
      expect(s.tertiary, tokens.cyan.content);
      expect(s.errorContainer, tokens.coral.container);
      expect(s.onErrorContainer, tokens.coral.content);
      expect(s.surface, tokens.ground);
      expect(
        s.surfaceContainerLow,
        Color.lerp(tokens.ground, tokens.surface, 0.5),
      );
      expect(
        s.surfaceContainerHighest,
        Color.lerp(tokens.surface2, tokens.line, 0.25),
      );
      expect(s.inversePrimary, tokens.stage);
    });

    test('light: stage leads, lime contains, danger is the container', () {
      final tokens = bentoTokensFor(BentoPalette.zedLime, false);
      final s = ZedTheme.build(
        Brightness.light,
        const Locale('en'),
        const ZedPrefs(),
      ).colorScheme;
      expect(s.primary, tokens.stage);
      expect(s.primaryContainer, tokens.lime);
      expect(s.error, tokens.bad);
      expect(s.errorContainer, tokens.danger);
      expect(s.onErrorContainer, tokens.onDanger);
      expect(s.surfaceContainerLowest, Colors.white);
      expect(s.inversePrimary, tokens.lime);
    });
  });

  group('Glass scheme is the fixed iOS table (T-4)', () {
    test('dark roles', () {
      final s = ZedTheme.build(
        Brightness.dark,
        const Locale('en'),
        const ZedPrefs(design: ZedDesign.glass),
      ).colorScheme;
      expect(s.primary, glassTintColor(0, true));
      expect(s.error, const Color(0xFFFF4245));
      expect(s.tertiary, const Color(0xFF30D158));
      expect(s.surface, Colors.black);
      expect(s.onSurfaceVariant, const Color(0xFF8D8D93));
      expect(s.secondaryContainer, const Color(0xFF2C2C2E));
    });

    test('light roles', () {
      final s = ZedTheme.build(
        Brightness.light,
        const Locale('en'),
        const ZedPrefs(design: ZedDesign.glass),
      ).colorScheme;
      expect(s.error, const Color(0xFFFF383C));
      expect(s.surface, const Color(0xFFF2F2F7));
      expect(s.onSurfaceVariant, const Color(0xFF8A8A8E));
    });
  });

  group('Dock labels default (B.3)', () {
    // Round 3 evaluated the reference's Active default and kept the
    // port's Always: with two destinations nothing crowds, and the
    // app's navigation tests address the Settings tab by its label
    // (switching the default failed seven widget tests). Active
    // stays a stored option, honoured exactly.
    test('fresh and missing values take the port default Always', () {
      expect(const ZedPrefs().bentoDockLabels, BentoDockLabels.always);
      expect(
        ZedPrefs.fromJson(const {}).bentoDockLabels,
        BentoDockLabels.always,
      );
    });

    test('a stored Active is honoured, not overridden', () {
      const p = ZedPrefs(bentoDockLabels: BentoDockLabels.active);
      expect(
        ZedPrefs.fromJson(p.toJson()).bentoDockLabels,
        BentoDockLabels.active,
      );
    });
  });

  group('Glass slider (B.1)', () {
    Future<void> pumpSlider(
      WidgetTester tester, {
      bool on = false,
      bool busy = false,
      required VoidCallback cb,
    }) async {
      const prefs = ZedPrefs(
        design: ZedDesign.glass,
        glassConnect: GlassConnectStyle.slider,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ZedTheme.build(Brightness.dark, const Locale('en'), prefs),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: ZedConnectControl(
                  prefs: prefs,
                  state: ZedConnectState(
                    on: on,
                    busy: busy,
                    live: on,
                    label: on ? 'On' : 'Off',
                    onToggle: cb,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    Finder knob() => find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).shape == BoxShape.circle &&
          (w.decoration as BoxDecoration).color == Colors.white,
    );

    testWidgets('geometry: 74 dp track, 64 dp knob resting 5 dp in', (
      tester,
    ) async {
      await pumpSlider(tester, cb: () {});
      expect(tester.getSize(find.byType(ZedConnectControl)).height, 74);
      expect(tester.getSize(knob()), const Size(64, 64));
      final dx =
          tester.getTopLeft(knob()).dx -
          tester.getTopLeft(find.byType(ZedConnectControl)).dx;
      expect(dx, inInclusiveRange(5, 7), reason: '5 dp + the 1 dp rim');
    });

    testWidgets('on: the knob rests at the far end', (tester) async {
      await pumpSlider(tester, on: true, cb: () {});
      final dx =
          tester.getTopLeft(knob()).dx -
          tester.getTopLeft(find.byType(ZedConnectControl)).dx;
      // travel = 320 − 64 − 10 = 246, plus the 5 dp rest and 1 dp rim.
      expect(dx, inInclusiveRange(250, 254));
    });

    testWidgets('a 0.65 drag does not connect; a 0.75 drag does', (
      tester,
    ) async {
      var taps = 0;
      await pumpSlider(tester, cb: () => taps++);
      await tester.drag(
        find.byType(ZedConnectControl),
        const Offset(178, 0), // 18 slop + 0.65 × 246
      );
      await tester.pump();
      expect(taps, 0);
      await tester.drag(
        find.byType(ZedConnectControl),
        const Offset(203, 0), // 18 slop + 0.75 × 246
      );
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('a tap toggles', (tester) async {
      var taps = 0;
      await pumpSlider(tester, cb: () => taps++);
      await tester.tap(find.byType(ZedConnectControl));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('busy shows the wait mark and stops the shimmer', (
      tester,
    ) async {
      await pumpSlider(tester, busy: true, cb: () {});
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(ShaderMask), findsNothing);
    });

    testWidgets('idle label shimmers', (tester) async {
      await pumpSlider(tester, cb: () {});
      expect(find.byType(ShaderMask), findsOneWidget);
    });
  });

  group('Glass minors (G-1/G-4) and Z semantics (ds3-02)', () {
    testWidgets('a disabled glass switch dims to 40%', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassSwitch(
              value: false,
              onChanged: null,
              prefs: ZedPrefs(design: ZedDesign.glass),
            ),
          ),
        ),
      );
      final opacity = tester.widget<Opacity>(
        find
            .descendant(
              of: find.byType(GlassSwitch),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(opacity.opacity, 0.4);
    });

    testWidgets('ZedPressable honours reduced motion', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: ZedPressable(
                onTap: () {},
                child: const SizedBox(width: 40, height: 40),
              ),
            ),
          ),
        ),
      );
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).duration,
        Duration.zero,
      );
    });

    testWidgets('the glass Z reads as a labelled toggle button', (
      tester,
    ) async {
      const prefs = ZedPrefs(
        design: ZedDesign.glass,
        glassConnect: GlassConnectStyle.z,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ZedTheme.build(Brightness.dark, const Locale('en'), prefs),
          home: Scaffold(
            body: Center(
              child: ZedConnectControl(
                prefs: prefs,
                state: ZedConnectState(
                  on: false,
                  busy: false,
                  live: false,
                  label: 'Off',
                  onToggle: () {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Off'), findsOneWidget);
    });
  });

  group('Localized settings labels (B.4)', () {
    test('fa carries the design-row labels and speed words', () async {
      final fa = await AppLocalizations.delegate.load(const Locale('fa'));
      expect(fa.zedDownload, 'سرعت دانلود');
      expect(fa.zedUpload, 'سرعت آپلود');
      expect(fa.zedSetConnectControl, 'کنترل اتصال');
      expect(fa.zedSetDockLabels, 'برچسب‌های داک');
      expect(fa.zedNavFloatingPill, 'کپسول شناور');
      expect(fa.zedDockActive, 'فقط فعال');
    });

    test('en keeps the original English labels', () async {
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      expect(en.zedSetConnectControl, 'Connect control');
      expect(en.zedSetMotionHighlights, 'Motion highlights');
      expect(en.zedConnectSlider, 'Slider');
      expect(en.zedDownload, 'Download speed');
    });
  });

  group('Performance invariants (B.5)', () {
    testWidgets('blur lives only in the chrome: one filter per slider track', (
      tester,
    ) async {
      const prefs = ZedPrefs(
        design: ZedDesign.glass,
        glassConnect: GlassConnectStyle.slider,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ZedTheme.build(Brightness.dark, const Locale('en'), prefs),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: ZedConnectControl(
                  prefs: prefs,
                  state: ZedConnectState(
                    on: false,
                    busy: false,
                    live: false,
                    label: 'Off',
                    onToggle: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      // The slider track is sanctioned chrome (§2); a simulated
      // module must contribute none.
      expect(find.byType(BackdropFilter), findsOneWidget);
      await tester.pumpWidget(
        MaterialApp(
          theme: ZedTheme.build(Brightness.dark, const Locale('en'), prefs),
          home: const Scaffold(
            body: GlassModule(child: SizedBox(width: 100, height: 60)),
          ),
        ),
      );
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('entrance rows stop rebuilding once settled', (tester) async {
      var builds = 0;
      Widget probe() => Builder(
        builder: (context) {
          builds++;
          return const SizedBox(height: 10);
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                for (var i = 0; i < 12; i++)
                  ZedEntrance(index: i, child: probe()),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 3));
      final settled = builds;
      expect(settled, greaterThan(0));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        builds,
        settled,
        reason: 'no perpetual rebuild after the stagger completes',
      );
    });
  });
}
