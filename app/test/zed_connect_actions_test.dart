// Every connect-control style branch through its REAL action
// (round-2 review, T5): before this file, only 6 of the 17 style
// branches had an action test, so a dead toggle in any other branch
// (a switch that never calls onToggle, a bar that swallows its tap)
// would have passed the whole suite. Each case below drives the
// control the way a finger does and expects exactly one toggle.

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firefox_vpn/ui/zed/zed_connect.dart';
import 'package:firefox_vpn/ui/zed/zed_glass.dart';
import 'package:firefox_vpn/ui/zed/zed_prefs.dart';
import 'package:firefox_vpn/ui/zed/zed_theme.dart';

void main() {
  Future<int> run(
    WidgetTester tester,
    ZedPrefs prefs, {
    required Future<void> Function() act,
  }) async {
    var taps = 0;
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
                  onToggle: () => taps++,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await act();
    await tester.pumpAndSettle();
    return taps;
  }

  Future<void> tapControl(WidgetTester tester) =>
      tester.tap(find.byType(ZedConnectControl));

  group('Bento remaining styles', () {
    for (final style in [
      BentoConnectStyle.morph,
      BentoConnectStyle.rail,
      BentoConnectStyle.tile,
    ]) {
      testWidgets('$style toggles on tap', (tester) async {
        final taps = await run(
          tester,
          ZedPrefs(bentoConnect: style),
          act: () => tapControl(tester),
        );
        expect(taps, 1);
      });
    }
  });

  group('Pixel remaining styles', () {
    for (final style in [
      PixelConnectStyle.pill,
      PixelConnectStyle.ring,
      PixelConnectStyle.bar,
      PixelConnectStyle.icon,
    ]) {
      testWidgets('$style toggles on tap', (tester) async {
        final taps = await run(
          tester,
          ZedPrefs(design: ZedDesign.pixel, pixelConnect: style),
          act: () => tapControl(tester),
        );
        expect(taps, 1);
      });
    }

    testWidgets('switchStyle toggles via the switch itself', (tester) async {
      final taps = await run(
        tester,
        const ZedPrefs(
          design: ZedDesign.pixel,
          pixelConnect: PixelConnectStyle.switchStyle,
        ),
        act: () => tester.tap(find.byType(Switch)),
      );
      expect(taps, 1);
    });
  });

  group('Old remaining styles (shared Pixel kit)', () {
    for (final style in [
      PixelConnectStyle.hero,
      PixelConnectStyle.ring,
      PixelConnectStyle.bar,
      PixelConnectStyle.icon,
    ]) {
      testWidgets('$style toggles on tap', (tester) async {
        final taps = await run(
          tester,
          ZedPrefs(design: ZedDesign.old, oldConnect: style),
          act: () => tapControl(tester),
        );
        expect(taps, 1);
      });
    }

    testWidgets('switchStyle toggles via the switch itself', (tester) async {
      final taps = await run(
        tester,
        const ZedPrefs(
          design: ZedDesign.old,
          oldConnect: PixelConnectStyle.switchStyle,
        ),
        act: () => tester.tap(find.byType(Switch)),
      );
      expect(taps, 1);
    });
  });

  group('Glass remaining styles', () {
    testWidgets('button toggles on tap', (tester) async {
      final taps = await run(
        tester,
        const ZedPrefs(
          design: ZedDesign.glass,
          glassConnect: GlassConnectStyle.button,
        ),
        act: () => tapControl(tester),
      );
      expect(taps, 1);
    });

    testWidgets('switchStyle toggles via the glass switch', (tester) async {
      final taps = await run(
        tester,
        const ZedPrefs(
          design: ZedDesign.glass,
          glassConnect: GlassConnectStyle.switchStyle,
        ),
        act: () => tester.tap(find.byType(GlassSwitch)),
      );
      expect(taps, 1);
    });

    testWidgets('slider toggles after a past-threshold drag', (tester) async {
      final taps = await run(
        tester,
        const ZedPrefs(
          design: ZedDesign.glass,
          glassConnect: GlassConnectStyle.slider,
        ),
        act: () =>
            tester.drag(find.byType(ZedConnectControl), const Offset(300, 0)),
      );
      expect(taps, 1);
    });
  });
}
