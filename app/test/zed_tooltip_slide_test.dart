// Regression tests (round-2 review): the production Tooltip wrapper
// must not kill the Slide connect control's drag. The homes always
// pass a tooltip, and the Tooltip's long-press recognizer wins the
// gesture arena when a press pauses (>=500 ms) before sliding — the
// drag was cancelled and the slide silently did nothing (Q3 failed
// before the fix: ZedConnectControl no longer wraps drag-primary
// controls in a Tooltip). Q1/Q2 are the no-tooltip controls.
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firefox_vpn/ui/zed/zed_connect.dart';
import 'package:firefox_vpn/ui/zed/zed_prefs.dart';
import 'package:firefox_vpn/ui/zed/zed_theme.dart';

Future<void> pumpSlide(
  WidgetTester tester,
  VoidCallback cb, {
  String tooltip = '',
}) async {
  const prefs = ZedPrefs();
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
                tooltip: tooltip,
                onToggle: cb,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<int> stepped(
  WidgetTester tester, {
  required Duration pause,
  String tooltip = '',
}) async {
  var taps = 0;
  await pumpSlide(tester, () => taps++, tooltip: tooltip);
  final g = await tester.startGesture(
    tester.getCenter(find.byType(ZedConnectControl)),
  );
  if (pause > Duration.zero) await tester.pump(pause);
  for (var i = 0; i < 3; i++) {
    await g.moveBy(const Offset(100, 0));
    await tester.pump(const Duration(milliseconds: 50));
  }
  await g.up();
  await tester.pumpAndSettle();
  return taps;
}

void main() {
  testWidgets('Q1: stepped, no pause, no tooltip', (tester) async {
    expect(await stepped(tester, pause: Duration.zero), 1);
  });
  testWidgets('Q2: stepped, 600ms pause, no tooltip', (tester) async {
    expect(
      await stepped(tester, pause: const Duration(milliseconds: 600)),
      1,
    );
  });
  testWidgets('Q3: stepped, 600ms pause, WITH tooltip (production)',
      (tester) async {
    expect(
      await stepped(
        tester,
        pause: const Duration(milliseconds: 600),
        tooltip: 'Tap to connect',
      ),
      1,
    );
  });
}
