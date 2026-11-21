import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arman_vpn/ui/zed/zed_connect.dart';
import 'package:arman_vpn/ui/zed/zed_home.dart';
import 'package:arman_vpn/ui/zed/zed_prefs.dart';
import 'package:arman_vpn/ui/zed/zed_theme.dart';

void main() {
  testWidgets('the traffic graph samples steady rates too', (tester) async {
    // Regression (DeepSeek pass 5): the graph history only appended
    // when the rates CHANGED, so steady traffic never produced
    // bars and the strip sat on its text fallback forever.
    final prefs = ZedPrefs()..design = ZedDesign.pixel;
    prefs.pixel.trafficStyle = TrafficCardStyle.graph;
    ZedConnectSpec spec() => ZedConnectSpec(
      phase: ZedPhase.on,
      onToggle: () {},
      stateLabel: 'On',
      actionLabel: 'Disconnect',
      hint: '',
      elapsed: '00:01',
      serverName: 'X',
    );
    Widget hero() => MaterialApp(
      theme: ZedTheme.build(Brightness.light, const Locale('en'), prefs),
      home: Scaffold(
        body: ZedHero(
          prefs: prefs,
          spec: spec(),
          upText: '3 KB/s',
          downText: '5 KB/s',
          upRate: 3000,
          downRate: 5000,
        ),
      ),
    );
    await tester.pumpWidget(hero());
    await tester.pumpWidget(hero()); // same rates, new widget
    final bars = find.byWidgetPredicate((w) {
      if (w is! Container) return false;
      final d = w.decoration;
      return d is BoxDecoration && d.color != null && d.color!.a == 0.75;
    });
    expect(bars, findsAtLeastNWidgets(2));
  });
}
