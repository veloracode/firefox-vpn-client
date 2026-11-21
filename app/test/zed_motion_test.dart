import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arman_vpn/ui/zed/zed_motion.dart';
import 'package:arman_vpn/ui/zed/zed_prefs.dart';

class _StatefulPage extends StatefulWidget {
  const _StatefulPage({super.key});
  static int creations = 0;
  @override
  State<_StatefulPage> createState() => _StatefulPageState();
}

class _StatefulPageState extends State<_StatefulPage> {
  @override
  void initState() {
    super.initState();
    _StatefulPage.creations++;
  }

  @override
  Widget build(BuildContext context) =>
      const SizedBox.expand(child: ColoredBox(color: Color(0xFF223344)));
}

void main() {
  group('spring conversion', () {
    test('composeSpring converts damping ratio + stiffness', () {
      // damping = 2 * ratio * sqrt(stiffness * mass), mass 1.
      final s = composeSpring(0.7, 400);
      expect(s.mass, 1);
      expect(s.stiffness, 400);
      expect(s.damping, closeTo(2 * 0.7 * math.sqrt(400), 0.001));
    });

    test('the named springs keep the source values', () {
      // Extract §6: glass press ζ0.5/k1500, switch knob ζ0.62/k400.
      expect(springPressGlass.stiffness, 1500);
      expect(springPressGlass.damping, closeTo(2 * 0.5 * math.sqrt(1500), 0.001));
      expect(springKnob.stiffness, 400);
      expect(springKnob.damping, closeTo(2 * 0.62 * math.sqrt(400), 0.001));
    });
  });

  group('ZedPageTransition', () {
    Widget host(ZedPrefs prefs, Widget child) => MaterialApp(
      home: Scaffold(
        body: ZedPageTransition(
          style: prefs.transition,
          reduceMotion: prefs.reduceMotion,
          forward: true,
          child: child,
        ),
      ),
    );

    testWidgets('shows the incoming page', (tester) async {
      final prefs = ZedPrefs();
      await tester.pumpWidget(
        host(prefs, const Text('one', key: ValueKey('one'))),
      );
      await tester.pumpAndSettle();
      expect(find.text('one'), findsOneWidget);
      await tester.pumpWidget(
        host(prefs, const Text('two', key: ValueKey('two'))),
      );
      await tester.pumpAndSettle();
      expect(find.text('two'), findsOneWidget);
      expect(find.text('one'), findsNothing);
    });

    testWidgets('reduce motion settles at once, no lingering frames', (
      tester,
    ) async {
      final prefs = ZedPrefs()..reduceMotion = true;
      await tester.pumpWidget(
        host(prefs, const Text('one', key: ValueKey('one'))),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        host(prefs, const Text('two', key: ValueKey('two'))),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('two'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('every style renders the incoming page', (tester) async {
      for (final style in ZedTransition.values) {
        final prefs = ZedPrefs()..transition = style;
        await tester.pumpWidget(
          host(prefs, Text('a', key: ValueKey('a-$style'))),
        );
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          host(prefs, Text('b', key: ValueKey('b-$style'))),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('b'),
          findsOneWidget,
          reason: 'style $style should land on the new page',
        );
      }
    });
  });

  group('ZedEntrance', () {
    testWidgets('the child is present after the entrance window', (
      tester,
    ) async {
      ZedEntrance.resetWindow();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ZedEntrance(index: 0, enabled: true, child: Text('in')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('in'), findsOneWidget);
      final opacity = tester
          .widgetList<Opacity>(find.byType(Opacity))
          .firstOrNull;
      if (opacity != null) expect(opacity.opacity, closeTo(1, 0.01));
    });

    testWidgets('disabled entrances show the child immediately', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ZedEntrance(index: 3, enabled: false, child: Text('now')),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('now'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('enabled changes after mount are honoured', (tester) async {
      // Regression (confirmation pass 3): ZedEntrance read enabled
      // only in initState, so a reduce-motion toggle while the
      // servers page was alive never took effect.
      Widget tree(bool enabled) => MaterialApp(
        home: Scaffold(
          body: ZedEntrance(index: 0, enabled: enabled, child: Text('x')),
        ),
      );
      ZedEntrance.resetWindow();
      await tester.pumpWidget(tree(false));
      expect(find.byType(Opacity), findsNothing);
      await tester.pumpWidget(tree(true));
      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, 0);
      await tester.pumpWidget(tree(false));
      expect(find.byType(Opacity), findsNothing);
      ZedEntrance.resetWindow();
    });

    testWidgets('resetWindow mid-group cannot crash a later start', (
      tester,
    ) async {
      // Regression (confirmation pass 5): the group count tracked
      // enabled entrances, not mounted ones, and _start dereferenced
      // a window the test hook can clear mid-group.
      Widget tree(bool second) => MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const ZedEntrance(index: 0, enabled: true, child: Text('a')),
              ZedEntrance(index: 1, enabled: second, child: Text('b')),
            ],
          ),
        ),
      );
      await tester.pumpWidget(tree(false));
      ZedEntrance.resetWindow();
      await tester.pumpWidget(tree(true));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      ZedEntrance.resetWindow();
    });

    testWidgets('a stale window starts a fresh mount group', (tester) async {
      // Regression (DeepSeek pass 3): the window anchor was
      // once-per-process, so entrances never animated again after
      // the first 800 ms of the app's life.
      ZedEntrance.windowStart = DateTime.now().subtract(
        const Duration(seconds: 10),
      );
      ZedEntrance.lastEntranceInit = DateTime.now().subtract(
        const Duration(seconds: 10),
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ZedEntrance(index: 0, enabled: true, child: Text('x')),
          ),
        ),
      );
      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, 0);
      ZedEntrance.resetWindow();
    });
  });

  group('ZedPressScale', () {
    testWidgets('the glass press scale overshoots past 1.0', (tester) async {
      // Regression (DeepSeek pass 3): a bounded AnimationController
      // clamped the spring at 1.0, so the 1.07 glass press never
      // rendered. The controller is unbounded now.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ZedPressScale(
                pressedScale: 1.07,
                spring: springPressGlass,
                child: Container(
                  width: 100,
                  height: 100,
                  color: const Color(0xFF0000FF),
                ),
              ),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ZedPressScale)),
      );
      final pressTransform = find.descendant(
        of: find.byType(ZedPressScale),
        matching: find.byType(Transform),
      );
      var maxScale = 0.0;
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final t = tester.widget<Transform>(pressTransform);
        if (t.transform.storage[0] > maxScale) {
          maxScale = t.transform.storage[0];
        }
      }
      await gesture.up();
      expect(maxScale, greaterThan(1.03));
    });

    testWidgets('press scale springs back when disabled mid-press', (
      tester,
    ) async {
      // Regression (confirmation pass): _to() returned early when
      // disabled, so a mid-press disable left the child scaled.
      Widget host(bool enabled) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: ZedPressScale(
              pressedScale: 0.9,
              spring: springPressCard,
              enabled: enabled,
              child: Container(
                width: 100,
                height: 100,
                color: const Color(0xFF0000FF),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(host(true));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ZedPressScale)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(host(false));
      await gesture.up();
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final t = tester.widget<Transform>(
        find.descendant(
          of: find.byType(ZedPressScale),
          matching: find.byType(Transform),
        ),
      );
      expect(t.transform.storage[0], closeTo(1.0, 0.02));
    });
  });

    testWidgets('a second pointer keeps the press held', (tester) async {
      // Regression (confirmation pass 3): the first pointer-up
      // sprang the scale back even with another pointer still down.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ZedPressScale(
                pressedScale: 0.9,
                spring: springPressCard,
                child: Container(
                  width: 100,
                  height: 100,
                  color: const Color(0xFF0000FF),
                ),
              ),
            ),
          ),
        ),
      );
      double scale() => tester
          .widget<Transform>(
            find.descendant(
              of: find.byType(ZedPressScale),
              matching: find.byType(Transform),
            ),
          )
          .transform
          .storage[0];
      final center = tester.getCenter(find.byType(ZedPressScale));
      final g1 = await tester.startGesture(center);
      final g2 = await tester.startGesture(center);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(scale(), lessThan(0.96));
      await g1.up();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(scale(), lessThan(0.98));
      await g2.up();
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(scale(), closeTo(1.0, 0.02));
    });

  group('ZedPageTransition regressions', () {
    Widget page(String label) => SizedBox.expand(
      key: ValueKey(label),
      child: ColoredBox(color: const Color(0xFF112233), child: Text(label)),
    );

    testWidgets('a settled page exits through its full animation', (
      tester,
    ) async {
      // Regression (confirmation pass): the exit seeding mapped the
      // entrance progress onto the exit's t directly, so a settled
      // page started its exit already fully gone. Exit t is
      // 1 - progress: mid-exit the outgoing page is still visible.
      await tester.pumpWidget(
        MaterialApp(
          home: ZedPageTransition(
            style: ZedTransition.fade,
            forward: true,
            reduceMotion: false,
            child: page('A'),
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ZedPageTransition(
            style: ZedTransition.fade,
            forward: true,
            reduceMotion: false,
            child: page('B'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 60));
      final opacities = tester
          .widgetList<Opacity>(find.byType(Opacity))
          .map((o) => o.opacity)
          .toList();
      // A is ~1/3 through its 180 ms exit: still mostly visible.
      expect(opacities.any((o) => o > 0.5), isTrue);
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('a mid-entrance exit runs the full exit spec', (
      tester,
    ) async {
      // Source semantics (confirmation pass 4): an interrupted
      // page's exit runs its own spec from t=0 for the full exit
      // duration — the enter progress is not blended into it.
      Widget tree(String label) => MaterialApp(
        home: ZedPageTransition(
          style: ZedTransition.fade,
          forward: true,
          reduceMotion: false,
          child: page(label),
        ),
      );
      await tester.pumpWidget(tree('A'));
      await tester.pumpWidget(tree('B'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(tree('C'));
      await tester.pump(const Duration(milliseconds: 100));
      // 100 ms into the full 180 ms exit, B is still leaving.
      expect(find.text('B'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('B'), findsNothing);
    });

    testWidgets('a fast reverse navigation has no duplicate keys', (
      tester,
    ) async {
      // Regression (confirmation pass 5): returning to a page whose
      // exit was still running added a second entry with the same
      // key — duplicate sibling keys in the transition stack. The
      // stale exit is now cancelled when the page returns.
      Widget tree(String label) => MaterialApp(
        home: ZedPageTransition(
          style: ZedTransition.slide,
          forward: label != 'A',
          reduceMotion: false,
          child: page(label),
        ),
      );
      await tester.pumpWidget(tree('A'));
      await tester.pumpWidget(tree('B'));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpWidget(tree('A'));
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.takeException(), isNull);
      expect(find.text('A'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('the incoming page keeps its State after cleanup', (
      tester,
    ) async {
      // Regression (confirmation pass 4): the Stack children were
      // unkeyed, so removing the completed exit entry shifted the
      // incoming page into the exit's element and its State was
      // destroyed and recreated.
      _StatefulPage.creations = 0;
      Widget tree(String label) => MaterialApp(
        home: ZedPageTransition(
          style: ZedTransition.fade,
          forward: true,
          reduceMotion: false,
          child: label == 'B'
              ? const _StatefulPage(key: ValueKey('B'))
              : page(label),
        ),
      );
      await tester.pumpWidget(tree('A'));
      await tester.pumpWidget(tree('B'));
      expect(_StatefulPage.creations, 1);
      // Run past the exit cleanup.
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(_StatefulPage), findsOneWidget);
      expect(_StatefulPage.creations, 1);
    });

    testWidgets('the elastic fade runs on time, not the spring value', (
      tester,
    ) async {
      // Regression (confirmation pass 6): the elastic entrance fed
      // its 180 ms fade with the spring VALUE, which saturates the
      // fade within the first frames. At ~60 ms the entering page
      // must still be well under full opacity.
      Widget tree(String label) => MaterialApp(
        home: ZedPageTransition(
          style: ZedTransition.elastic,
          forward: true,
          reduceMotion: false,
          child: page(label),
        ),
      );
      await tester.pumpWidget(tree('A'));
      await tester.pumpWidget(tree('B'));
      await tester.pump(const Duration(milliseconds: 60));
      final opacities = tester
          .widgetList<Opacity>(find.byType(Opacity))
          .map((o) => o.opacity)
          .toList();
      expect(opacities.any((o) => o > 0.05 && o < 0.6), isTrue);
      await tester.pump(const Duration(milliseconds: 800));
    });

    testWidgets('the flip fade starts at zero after its 90 ms delay', (
      tester,
    ) async {
      // Regression (DeepSeek pass 3): the delayed fade jumped to
      // ~0.41 of full at the delay boundary; it must start at 0.
      await tester.pumpWidget(
        MaterialApp(
          home: ZedPageTransition(
            style: ZedTransition.flip,
            forward: true,
            reduceMotion: false,
            child: page('A'),
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ZedPageTransition(
            style: ZedTransition.flip,
            forward: true,
            reduceMotion: false,
            child: page('B'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));
      final opacities = tester
          .widgetList<Opacity>(find.byType(Opacity))
          .map((o) => o.opacity)
          .toList();
      // The entering page (B) is still nearly invisible at 120 ms.
      expect(opacities.reduce((a, b) => a < b ? a : b), lessThan(0.08));
      await tester.pump(const Duration(milliseconds: 300));
    });
  });
}
