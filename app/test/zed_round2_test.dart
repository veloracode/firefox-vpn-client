// Round-2 review fixes, each pinned by the behaviour it changed:
// the three Glass preference toggles that were written but read by
// nothing (glassLists / shrink tab bar / motion highlights), and the
// server-list entrance ignoring reduced motion.

import 'dart:ui' show SemanticsAction;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firefox_vpn/ui/zed/zed_glass.dart';
import 'package:firefox_vpn/ui/zed/zed_kit.dart';
import 'package:firefox_vpn/ui/zed/zed_motion.dart';
import 'package:firefox_vpn/ui/zed/zed_prefs.dart';
import 'package:firefox_vpn/ui/zed/zed_theme.dart';

Widget app(ZedPrefs prefs, Widget home) => MaterialApp(
  theme: ZedTheme.build(Brightness.dark, const Locale('en'), prefs),
  home: Scaffold(body: home),
);

void main() {
  group('Glass lists preference (round-2 D1)', () {
    Future<void> pumpGroup(WidgetTester tester, ZedPrefs prefs) =>
        tester.pumpWidget(
          app(
            prefs,
            ZedGroup(
              prefs: prefs,
              rows: const [ListTile(title: Text('Row'))],
            ),
          ),
        );

    testWidgets('on: group cells are glass modules', (tester) async {
      await pumpGroup(
        tester,
        const ZedPrefs(design: ZedDesign.glass, glassLists: true),
      );
      final module = tester.widget<GlassModule>(find.byType(GlassModule));
      expect(module.solid, isFalse);
    });

    testWidgets('off: group cells render solid, heroes stay glass', (
      tester,
    ) async {
      await pumpGroup(
        tester,
        const ZedPrefs(design: ZedDesign.glass, glassLists: false),
      );
      final module = tester.widget<GlassModule>(find.byType(GlassModule));
      expect(module.solid, isTrue, reason: 'lists off = solid cells');
      // A free module (not a cell) is unaffected by the preference.
      await tester.pumpWidget(
        app(
          const ZedPrefs(design: ZedDesign.glass, glassLists: false),
          const ZedModule(
            prefs: ZedPrefs(design: ZedDesign.glass, glassLists: false),
            child: Text('hero'),
          ),
        ),
      );
      final hero = tester.widget<GlassModule>(find.byType(GlassModule));
      expect(hero.solid, isFalse);
    });
  });

  group('Shrink tab bar (round-2 D1)', () {
    testWidgets('the shrunk dock is icon-only', (tester) async {
      await tester.pumpWidget(
        app(
          const ZedPrefs(design: ZedDesign.glass),
          ZedDock(
            prefs: const ZedPrefs(design: ZedDesign.glass),
            selected: 0,
            shrunk: true,
            onSelect: (_) {},
            items: const [
              (Icons.home_outlined, Icons.home_rounded, 'Home'),
              (Icons.settings_outlined, Icons.settings_rounded, 'Settings'),
            ],
          ),
        ),
      );
      expect(find.text('Home'), findsNothing);
      expect(find.text('Settings'), findsNothing);
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    });

    testWidgets('the unshrunk glass dock still names its destinations', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          const ZedPrefs(design: ZedDesign.glass),
          ZedDock(
            prefs: const ZedPrefs(design: ZedDesign.glass),
            selected: 0,
            onSelect: (_) {},
            items: const [
              (Icons.home_outlined, Icons.home_rounded, 'Home'),
              (Icons.settings_outlined, Icons.settings_rounded, 'Settings'),
            ],
          ),
        ),
      );
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });
  });

  group('Motion highlights (round-2 D1)', () {
    testWidgets('chrome builds and tracks the pointer without error', (
      tester,
    ) async {
      const prefs = ZedPrefs(
        design: ZedDesign.glass,
        glassMotionHighlights: true,
      );
      await tester.pumpWidget(
        app(
          prefs,
          const Center(
            child: GlassChrome(
              prefs: prefs,
              child: SizedBox(width: 200, height: 60),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(GlassChrome)),
      );
      await gesture.moveBy(const Offset(40, 10));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await gesture.up();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('Dock accessibility + text scale (round-2, DeepSeek ds-01)', () {
    Widget dock() => ZedDock(
      prefs: const ZedPrefs(),
      selected: 0,
      onSelect: (_) {},
      items: const [
        (Icons.home_outlined, Icons.home_rounded, 'Home'),
        (Icons.settings_outlined, Icons.settings_rounded, 'Settings'),
      ],
    );

    testWidgets('dock destinations carry a semantics tap action', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(app(const ZedPrefs(), dock()));
      // The visible label is inside ExcludeSemantics (announced
      // once, by the outer node) — that node must ALSO carry the
      // activation action, or a screen-reader user can focus a
      // destination but never switch to it.
      final data = tester
          .getSemantics(find.bySemanticsLabel('Settings'))
          .getSemanticsData();
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });

    testWidgets('the Bento dock grows instead of clipping at 3x text', (
      tester,
    ) async {
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(app(const ZedPrefs(), dock()));
      final heightAt1x = tester.getSize(find.byType(ZedDock)).height;
      // Vertical clipping throws no overflow error (the label is
      // silently cut inside the fixed-height item), so the pin is
      // the geometry itself: at 3x text the dock must be TALLER
      // than at 1x — a fixed-height dock fails this. (At 2x the
      // pill's own slack absorbs the growth; 3x cannot be absorbed.)
      tester.platformDispatcher.textScaleFactorTestValue = 3.0;
      await tester.pumpWidget(app(const ZedPrefs(), dock()));
      await tester.pump();
      expect(tester.takeException(), isNull);
      final heightAt3x = tester.getSize(find.byType(ZedDock)).height;
      expect(heightAt3x, greaterThan(heightAt1x));
    });
  });

  group('Spec-token corrections (round-2, second reviewer)', () {
    test('accent seeds are the documented light colours (§3.1)', () {
      expect(pixelAccents[1], const Color(0xFF1E63D0)); // Ocean
      expect(pixelAccents[4], const Color(0xFFB4690E)); // Amber
      expect(pixelAccents[5], const Color(0xFFC4326B)); // Rose
      expect(pixelAccents[9], const Color(0xFF4A5B7A)); // Slate
    });

    test('glass tint 7 is Cyan, the tint the original has (§2.5)', () {
      expect(glassTintColor(7, true), const Color(0xFF3CD3FE));
      expect(glassTintColor(7, false), const Color(0xFF00C0E8));
    });

    test('Pixel AMOLED overrides the whole surface family (§3.1)', () {
      final theme = ZedTheme.build(
        Brightness.dark,
        const Locale('en'),
        const ZedPrefs(design: ZedDesign.pixel, pixelAmoled: true),
      );
      final scheme = theme.colorScheme;
      expect(scheme.surface, const Color(0xFF000000));
      expect(scheme.surfaceContainerLow, const Color(0xFF0B0B0B));
      expect(scheme.surfaceContainer, const Color(0xFF0F0F0F));
      expect(scheme.surfaceContainerHigh, const Color(0xFF161616));
      expect(scheme.surfaceContainerHighest, const Color(0xFF1E1E1E));
      expect(scheme.surfaceBright, const Color(0xFF1A1A1A));
    });

    test('dark Bento errorContainer is the palette coral pair (round 3)', () {
      // Round 2 pinned the generic Material pair #93000A/#FFDAD6;
      // round 3 checked BentoTheme.kt and REFUTED that premise:
      // bentoColorScheme() maps the dark error container to the
      // palette's own coral tone pair (BrandDark: #4A251D/#FFD3C6).
      final theme = ZedTheme.build(
        Brightness.dark,
        const Locale('en'),
        const ZedPrefs(),
      );
      expect(theme.colorScheme.errorContainer, const Color(0xFF4A251D));
      expect(theme.colorScheme.onErrorContainer, const Color(0xFFFFD3C6));
    });

    testWidgets('the glass switch is the wide green capsule (§2.7)', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          const ZedPrefs(design: ZedDesign.glass),
          Center(
            child: GlassSwitch(
              value: true,
              onChanged: (_) {},
              prefs: const ZedPrefs(design: ZedDesign.glass),
            ),
          ),
        ),
      );
      final size = tester.getSize(find.byType(GlassSwitch));
      expect(size.width, 63);
      expect(size.height, 28);
    });

    testWidgets('a reduced Glass module paints no rim gradient', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          const ZedPrefs(design: ZedDesign.glass, reduceTransparency: true),
          const ZedModule(
            prefs: ZedPrefs(design: ZedDesign.glass, reduceTransparency: true),
            child: Text('cell'),
          ),
        ),
      );
      // The glass path's outer box carries the rim gradient; the
      // reduced path must have no LinearGradient under the module.
      final gradients = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .where(
            (b) =>
                b.decoration is BoxDecoration &&
                (b.decoration as BoxDecoration).gradient is LinearGradient,
          );
      expect(gradients, isEmpty);
    });
  });

  group('ZedEntrance reduced motion (round-2 D4)', () {
    testWidgets('with animations disabled the child renders unanimated', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ZedEntrance(index: 3, child: Text('row'))),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('row'), findsOneWidget);
      // No entrance wrappers at all: no fade, no rise, no scale.
      expect(
        find.ancestor(of: find.text('row'), matching: find.byType(Opacity)),
        findsNothing,
      );
      expect(
        find.ancestor(of: find.text('row'), matching: find.byType(Transform)),
        findsNothing,
      );
    });

    testWidgets('with animations enabled the entrance runs', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ZedEntrance(index: 0, child: Text('row'))),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        find.ancestor(of: find.text('row'), matching: find.byType(Opacity)),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
    });
  });
}
