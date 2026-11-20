// Regression tests for the Bento Slide connect control and the
// reduced-motion busy mark. Authored by DeepSeek V4.1 Flash from a
// written spec (the slide's landing-zone thresholds, RTL mirroring,
// hold-at-the-end behaviour); reviewed and integrated by Muse — the
// RTL harness wraps Directionality INSIDE the app (an outer wrapper is
// shadowed by MaterialApp's own locale directionality).

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firefox_vpn/ui/zed/zed_connect.dart';
import 'package:firefox_vpn/ui/zed/zed_prefs.dart';
import 'package:firefox_vpn/ui/zed/zed_theme.dart';

ZedConnectState st(bool on, VoidCallback cb) => ZedConnectState(
  on: on,
  busy: false,
  live: on,
  label: on ? 'On' : 'Off',
  onToggle: cb,
);

Future<void> pump(
  WidgetTester tester, {
  required bool on,
  required VoidCallback cb,
  bool rtl = false,
  bool morphBusy = false,
}) async {
  final prefs = morphBusy
      ? const ZedPrefs(bentoConnect: BentoConnectStyle.morph)
      : const ZedPrefs();

  final state = morphBusy
      ? ZedConnectState(
          on: false,
          busy: true,
          live: false,
          label: 'Connecting',
          onToggle: cb,
        )
      : st(on, cb);

  Widget home = Scaffold(
    body: Center(
      child: SizedBox(
        width: 320,
        child: ZedConnectControl(prefs: prefs, state: state),
      ),
    ),
  );
  if (rtl) {
    home = Directionality(textDirection: TextDirection.rtl, child: home);
  }

  await tester.pumpWidget(
    MaterialApp(
      theme: ZedTheme.build(Brightness.dark, const Locale('en'), prefs),
      home: home,
    ),
  );
}

void main() {
  group('Bento Slide regression', () {
    testWidgets('on: a full leftward drag disconnects exactly once', (
      tester,
    ) async {
      var taps = 0;
      await pump(tester, on: true, cb: () => taps++);
      await tester.drag(
        find.byType(ZedConnectControl),
        const Offset(-300, 0),
      );
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('on: a half leftward drag keeps the connection', (
      tester,
    ) async {
      var taps = 0;
      await pump(tester, on: true, cb: () => taps++);
      await tester.drag(
        find.byType(ZedConnectControl),
        const Offset(-100, 0),
      );
      await tester.pumpAndSettle();
      expect(taps, 0);
    });

    testWidgets('off: a half rightward drag does not connect', (tester) async {
      var taps = 0;
      await pump(tester, on: false, cb: () => taps++);
      await tester.drag(
        find.byType(ZedConnectControl),
        const Offset(100, 0),
      );
      await tester.pumpAndSettle();
      expect(taps, 0);
    });

    testWidgets('off: a full rightward drag connects exactly once', (
      tester,
    ) async {
      var taps = 0;
      await pump(tester, on: false, cb: () => taps++);
      await tester.drag(
        find.byType(ZedConnectControl),
        const Offset(300, 0),
      );
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('rtl: a physical leftward drag connects', (tester) async {
      var taps = 0;
      await pump(tester, on: false, cb: () => taps++, rtl: true);
      await tester.drag(
        find.byType(ZedConnectControl),
        const Offset(-300, 0),
      );
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets(
      'on: holding the knob at the left end does not snap or toggle early',
      (tester) async {
        var taps = 0;
        await pump(tester, on: true, cb: () => taps++);
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(ZedConnectControl)),
        );
        // Drag to the left end in steps, as a finger travels, then
        // HOLD: the knob must stay at the end (no snap back to the
        // rest position) and nothing may toggle before the release.
        for (var i = 0; i < 3; i++) {
          await gesture.moveBy(const Offset(-100, 0));
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        expect(taps, 0);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(taps, 1);
      },
    );
  });

  group('Slide landing zones are the spec thresholds (0.72 / 0.28)', () {
    // Harness travel is 256 dp (320 wide − 56 knob − 8 padding), so
    // the connect threshold 0.72 sits at 184 dp of knob travel and
    // the stay-connected floor 0.28 mirrors it. A test drag loses
    // ~18 dp to touch slop before the recognizer starts reporting,
    // so the physical drags are 190 (knob ≈172 = 0.67, must NOT
    // toggle) and 215 (knob ≈197 = 0.77, must toggle). A plain
    // 0.5/0.5 implementation fails the 190 cases (round-2 review,
    // T1 — the older tests only dragged 100/300 and could not tell
    // 0.72 from 0.5).
    testWidgets('off: a 190 dp drag (knob 0.67) does not connect', (
      tester,
    ) async {
      var taps = 0;
      await pump(tester, on: false, cb: () => taps++);
      await tester.drag(
        find.byType(ZedConnectControl),
        const Offset(190, 0),
      );
      await tester.pumpAndSettle();
      expect(taps, 0);
    });

    testWidgets('off: a 215 dp drag (knob 0.77) connects', (tester) async {
      var taps = 0;
      await pump(tester, on: false, cb: () => taps++);
      await tester.drag(
        find.byType(ZedConnectControl),
        const Offset(215, 0),
      );
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('on: a 190 dp leftward drag (knob 0.33) keeps the link', (
      tester,
    ) async {
      var taps = 0;
      await pump(tester, on: true, cb: () => taps++);
      await tester.drag(
        find.byType(ZedConnectControl),
        const Offset(-190, 0),
      );
      await tester.pumpAndSettle();
      expect(taps, 0);
    });

    testWidgets('on: a 215 dp leftward drag (knob 0.23) disconnects', (
      tester,
    ) async {
      var taps = 0;
      await pump(tester, on: true, cb: () => taps++);
      await tester.drag(
        find.byType(ZedConnectControl),
        const Offset(-215, 0),
      );
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  });

  group('Reduced motion', () {
    testWidgets(
      'morph busy shows no animated spinner when animations are disabled',
      (tester) async {
        // Reduced motion is forced at the platform level — the same
        // pattern the main suite uses. (A MediaQuery override widget
        // loops rebuilds against this framework's own MediaQuery and
        // hangs the tester; the platform flag is the honest route —
        // it is also how a real device reports the setting.)
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        await pump(tester, on: false, cb: () {}, morphBusy: true);
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        // Absence-only is not enough (round-2 review, T6): the still
        // busy arc must actually be there in the spinner's place.
        expect(
          find.descendant(
            of: find.byType(ZedConnectControl),
            matching: find.byType(CustomPaint),
          ),
          findsOneWidget,
          reason: 'the reduced-motion busy mark is a still painted arc',
        );
      },
    );

    testWidgets('morph busy DOES spin when animations are enabled', (
      tester,
    ) async {
      await pump(tester, on: false, cb: () {}, morphBusy: true);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('Bento Hold with its tooltip', () {
    // The homes always pass a tooltip, so ZedConnectControl wraps the
    // control in a Tooltip. The Tooltip's long-press recognizer must
    // not be able to cancel the 650 ms hold (it fires at ~500 ms):
    // the hold's press tracking lives outside the gesture arena.
    testWidgets('the hold completes even though a tooltip wraps it', (
      tester,
    ) async {
      var taps = 0;
      const prefs = ZedPrefs(bentoConnect: BentoConnectStyle.hold);
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
                    tooltip: 'Tap to connect',
                    onToggle: () => taps++,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ZedConnectControl)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(taps, 0, reason: 'a short press must not toggle');
      await tester.pump(const Duration(milliseconds: 400));
      expect(taps, 1, reason: 'holding past 650 ms toggles, tooltip or not');
      await gesture.up();
    });

    testWidgets('the hold fires at 650 ms, not before (tight bracket)', (
      tester,
    ) async {
      var taps = 0;
      const prefs = ZedPrefs(bentoConnect: BentoConnectStyle.hold);
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
                    tooltip: 'Tap to connect',
                    onToggle: () => taps++,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ZedConnectControl)),
      );
      await tester.pump(const Duration(milliseconds: 640));
      expect(taps, 0, reason: 'at 640 ms the 650 ms hold has not fired');
      await tester.pump(const Duration(milliseconds: 20));
      expect(taps, 1, reason: 'at 660 ms it has');
      await gesture.up();
    });

    testWidgets('releasing before 650 ms never toggles', (tester) async {
      // The cancel path (round-2 review, T2): an early release must
      // disarm the hold timer for good — not just delay the toggle.
      var taps = 0;
      const prefs = ZedPrefs(bentoConnect: BentoConnectStyle.hold);
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
                    tooltip: 'Tap to connect',
                    onToggle: () => taps++,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ZedConnectControl)),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(taps, 0, reason: 'an early release cancels the hold');
    });
  });
}
