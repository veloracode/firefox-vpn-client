import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arman_vpn/ui/zed/zed_motion.dart';
import 'package:arman_vpn/ui/zed/zed_prefs.dart';

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
  });
}
