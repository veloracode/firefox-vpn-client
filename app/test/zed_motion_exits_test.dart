// Round-3 pins for the page-transition EXIT transforms (Part B.2).
//
// The reference gives enter and exit SEPARATE transforms (§6.1 of
// the extract / ScreenTransitions.kt): Slide exits to −sign×w/3,
// Push exits to −sign×w/3 (not a full width back), Depth's back pair
// mirrors its forward pair, Elastic exits by scaling to 0.96 with
// no slide, Curtain's two pages split the slide/scale between them,
// and Flip's leaving page turns to −78° (PostExit), not back to
// +78°. Through round 2 the port ran ONE builder reversed for the
// outgoing page, so every exit above was the enter played backwards.
// These tests switch pages mid-flight and read the actual transform
// ancestors of the incoming ('b') and outgoing ('a') pages.

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firefox_vpn/ui/zed/zed_motion.dart';
import 'package:firefox_vpn/ui/zed/zed_prefs.dart';

Widget _page(ZedTransitionStyle style, String id, {double direction = 1}) =>
    ZedPageSwitcher(
      prefs: ZedPrefs(transitionStyle: style),
      reduceMotion: false,
      direction: direction,
      child: SizedBox(key: ValueKey(id), width: 100, height: 100),
    );

Future<void> _switch(
  WidgetTester tester,
  ZedTransitionStyle style, {
  double direction = 1,
  Duration mid = const Duration(milliseconds: 150),
}) async {
  // No MaterialApp: its route transition would add its own
  // SlideTransition/FractionalTranslation ancestors above the
  // switcher and pollute the findsNothing assertions.
  Widget wrap(Widget child) =>
      Directionality(textDirection: TextDirection.ltr, child: child);
  await tester.pumpWidget(wrap(_page(style, 'a', direction: direction)));
  await tester.pumpWidget(wrap(_page(style, 'b', direction: direction)));
  await tester.pump(mid);
}

FractionalTranslation _translation(WidgetTester tester, String id) =>
    tester.widget<FractionalTranslation>(
      find
          .ancestor(
            of: find.byKey(ValueKey(id)),
            matching: find.byType(FractionalTranslation),
          )
          .first,
    );

Transform _transform(WidgetTester tester, String id) =>
    tester.widget<Transform>(
      find
          .ancestor(
            of: find.byKey(ValueKey(id)),
            matching: find.byType(Transform),
          )
          .first,
    );

double _scaleOf(Transform t) => t.transform.storage[0];

double _angleOf(Transform t) =>
    math.atan2(t.transform.storage[8], t.transform.storage[0]);

void main() {
  testWidgets('slide: the exit continues to −w/3, not back to +w/3', (
    tester,
  ) async {
    await _switch(tester, ZedTransitionStyle.slide);
    final incoming = _translation(tester, 'b').translation.dx;
    final outgoing = _translation(tester, 'a').translation.dx;
    expect(incoming, greaterThan(0.02), reason: 'enter comes from +w/3');
    expect(outgoing, lessThan(-0.02), reason: 'exit heads to −w/3');
    expect(outgoing, greaterThan(-0.34));
  });

  testWidgets('push: the exit is a third of the width, opposite side', (
    tester,
  ) async {
    await _switch(tester, ZedTransitionStyle.push);
    final incoming = _translation(tester, 'b').translation.dx;
    final outgoing = _translation(tester, 'a').translation.dx;
    expect(incoming, greaterThan(0.3), reason: 'enter comes from full width');
    expect(outgoing, lessThan(-0.05), reason: 'exit heads to −w/3');
    expect(outgoing, greaterThan(-0.34), reason: 'not a full width back');
  });

  testWidgets('depth forward: enter shrinks in, exit grows out', (
    tester,
  ) async {
    await _switch(tester, ZedTransitionStyle.depth);
    expect(_scaleOf(_transform(tester, 'b')), lessThan(1.0));
    expect(_scaleOf(_transform(tester, 'a')), greaterThan(1.0));
  });

  testWidgets('depth back: the pair mirrors (enter 1.12, exit 0.88)', (
    tester,
  ) async {
    await _switch(tester, ZedTransitionStyle.depth, direction: -1);
    expect(_scaleOf(_transform(tester, 'b')), greaterThan(1.0));
    expect(_scaleOf(_transform(tester, 'a')), lessThan(1.0));
  });

  testWidgets('elastic exit: scales toward 0.96 with no slide', (tester) async {
    await _switch(
      tester,
      ZedTransitionStyle.elastic,
      mid: const Duration(milliseconds: 100),
    );
    final outgoing = _transform(tester, 'a');
    final scale = _scaleOf(outgoing);
    expect(scale, lessThan(1.0));
    expect(scale, greaterThan(0.95), reason: 'heading for 0.96, not 0.9');
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('a')),
        matching: find.byType(SlideTransition),
      ),
      findsNothing,
      reason: 'the exit has no slide component',
    );
  });

  testWidgets('curtain forward: enter slides, exit only scales', (
    tester,
  ) async {
    await _switch(tester, ZedTransitionStyle.curtain);
    final incomingDy = _translation(tester, 'b').translation.dy;
    expect(incomingDy, greaterThan(0.05), reason: 'enter rises from h/2');
    final outgoingScale = _scaleOf(_transform(tester, 'a'));
    expect(outgoingScale, lessThan(1.0));
    expect(outgoingScale, greaterThan(0.93), reason: 'heading for 0.94');
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('a')),
        matching: find.byType(FractionalTranslation),
      ),
      findsNothing,
      reason: 'the forward exit does not slide',
    );
  });

  testWidgets('curtain back: enter only scales, exit slides away', (
    tester,
  ) async {
    await _switch(tester, ZedTransitionStyle.curtain, direction: -1);
    final incomingScale = _scaleOf(_transform(tester, 'b'));
    expect(incomingScale, lessThan(1.0));
    expect(incomingScale, greaterThan(0.93));
    final outgoingDy = _translation(tester, 'a').translation.dy;
    expect(outgoingDy, greaterThan(0.05), reason: 'exit sinks to h/2');
  });

  testWidgets('flip: the leaving page turns to −78°, not back to +78°', (
    tester,
  ) async {
    await _switch(tester, ZedTransitionStyle.flip);
    expect(_angleOf(_transform(tester, 'b')), greaterThan(0.05));
    expect(_angleOf(_transform(tester, 'a')), lessThan(-0.05));
  });

  test('exit durations and easing follow the spec table', () {
    expect(
      ZedMotion.reverseDuration(ZedTransitionStyle.elastic, false),
      const Duration(milliseconds: 220),
    );
    expect(
      ZedMotion.reverseDuration(ZedTransitionStyle.fade, false),
      const Duration(milliseconds: 180),
    );
    expect(
      ZedMotion.curve(ZedTransitionStyle.slide),
      Curves.fastOutSlowIn,
      reason: 'Compose tween default (finding M-7)',
    );
    expect(ZedMotion.curve(ZedTransitionStyle.depth), Curves.fastOutSlowIn);
  });
}
