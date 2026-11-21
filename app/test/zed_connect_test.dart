import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arman_vpn/ui/zed/zed_connect.dart';
import 'package:arman_vpn/ui/zed/zed_connect_glass.dart';
import 'package:arman_vpn/ui/zed/zed_prefs.dart';
import 'package:arman_vpn/ui/zed/zed_theme.dart';

ZedConnectSpec _spec(ZedPhase phase, VoidCallback onToggle) => ZedConnectSpec(
  phase: phase,
  onToggle: onToggle,
  stateLabel: 'State',
  actionLabel: 'Connect',
  hint: 'hint',
);

Widget _host(Widget child) => MaterialApp(
  theme: ZedTheme.build(Brightness.light, const Locale('en'), ZedPrefs()),
  home: Scaffold(
    body: Center(child: SizedBox(width: 360, child: child)),
  ),
);

void main() {
  group('Bento slide', () {
    testWidgets('a tap toggles', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          BentoSlideConnect(
            prefs: BentoPrefs(),
            spec: _spec(ZedPhase.off, () => taps++),
          ),
        ),
      );
      await tester.tap(find.byType(BentoSlideConnect));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('a full slide toggles, a short drag does not', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          BentoSlideConnect(
            prefs: BentoPrefs(),
            spec: _spec(ZedPhase.off, () => taps++),
          ),
        ),
      );
      await tester.drag(find.byType(BentoSlideConnect), const Offset(40, 0));
      await tester.pumpAndSettle();
      expect(taps, 0);
      await tester.drag(find.byType(BentoSlideConnect), const Offset(500, 0));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('while busy a tap still toggles (cancel)', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          BentoSlideConnect(
            prefs: BentoPrefs(),
            spec: _spec(ZedPhase.busy, () => taps++),
          ),
        ),
      );
      await tester.tap(find.byType(BentoSlideConnect));
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('Bento hold', () {
    testWidgets('fires only after the 650 ms hold', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          BentoHoldConnect(
            prefs: BentoPrefs(),
            spec: _spec(ZedPhase.off, () => taps++),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(BentoHoldConnect)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 0);
      final gesture2 = await tester.startGesture(
        tester.getCenter(find.byType(BentoHoldConnect)),
      );
      await tester.pump(const Duration(milliseconds: 800));
      await gesture2.up();
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  });

  group('Glass slider', () {
    testWidgets('a tap toggles; a long slide toggles too', (tester) async {
      var taps = 0;
      final tokens = glassTokensFor(GlassPrefs(), true);
      await tester.pumpWidget(
        _host(
          GlassSliderConnect(
            tokens: tokens,
            spec: _spec(ZedPhase.off, () => taps++),
          ),
        ),
      );
      await tester.tap(find.byType(GlassSliderConnect));
      await tester.pump();
      expect(taps, 1);
      await tester.drag(
        find.byType(GlassSliderConnect),
        const Offset(500, 0),
      );
      // The off-state shimmer repeats forever (by design), so the
      // test pumps bounded frames instead of settling.
      await tester.pump(const Duration(milliseconds: 300));
      expect(taps, 2);
    });
  });

  group('Glass switch', () {
    testWidgets('a tap flips it', (tester) async {
      bool? next;
      final tokens = glassTokensFor(GlassPrefs(), true);
      await tester.pumpWidget(
        _host(GlassSwitch(tokens: tokens, value: false, onChanged: (v) => next = v)),
      );
      await tester.tap(find.byType(GlassSwitch));
      await tester.pump();
      expect(next, isTrue);
    });
  });

  group('Glass Z look table', () {
    test('phases resolve to distinct looks', () {
      final off = zLook(ZedPhase.off, true, glassTintColor(GlassTint.blue, true));
      final on = zLook(ZedPhase.on, true, glassTintColor(GlassTint.blue, true));
      final busy = zLook(
        ZedPhase.busy,
        true,
        glassTintColor(GlassTint.blue, true),
      );
      expect(off.a, isNot(on.a));
      expect(busy.glow, isNot(off.glow));
    });
  });
}
