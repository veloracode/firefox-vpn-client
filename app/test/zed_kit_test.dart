import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arman_vpn/ui/zed/zed_kit.dart';
import 'package:arman_vpn/ui/zed/zed_prefs.dart';
import 'package:arman_vpn/ui/zed/zed_theme.dart';

void main() {
  group('BentoDock auto-hide (confirmation pass 5)', () {
    testWidgets('a slow scroll still hides the dock', (tester) async {
      // Regression: the tracker overwrote its anchor on every
      // event, so a scroll moving <4 dp per event never registered
      // a direction and auto-hide never engaged.
      final controller = ScrollController();
      final prefs = BentoPrefs()..dockAutoHide = true;
      await tester.pumpWidget(
        MaterialApp(
          home: PrimaryScrollController(
            controller: controller,
            child: Stack(
              children: [
                ListView.builder(
                  itemCount: 100,
                  itemBuilder: (_, i) =>
                      SizedBox(height: 50, child: Text('row $i')),
                ),
                PositionedDirectional(
                  bottom: 0,
                  start: 0,
                  end: 0,
                  child: BentoDock(
                    tokens: bentoTokensFor(BentoPalette.brand, true),
                    prefs: prefs,
                    tabs: const [
                      ZedTab(icon: Icons.home, label: 'Home'),
                      ZedTab(icon: Icons.settings, label: 'Settings'),
                    ],
                    index: 0,
                    onSelect: (_) {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      for (var i = 0; i < 12; i++) {
        controller.jumpTo(controller.offset + 3);
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 400));
      final fade = tester.widget<AnimatedOpacity>(
        find.descendant(
          of: find.byType(BentoDock),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(fade.opacity, 0);
    });
  });

  group('GlassTabBar (DeepSeek pass 3b regressions)', () {
    final tabs = <ZedTab>[
      const ZedTab(icon: Icons.home, label: 'Home'),
      const ZedTab(icon: Icons.dns, label: 'Servers'),
      const ZedTab(icon: Icons.person, label: 'Accounts'),
      const ZedTab(icon: Icons.settings, label: 'Settings'),
    ];

    Widget host(int index) => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: 400,
            child: GlassTabBar(
              tabs: tabs,
              index: index,
              onSelect: (_) {},
              tokens: glassTokensFor(GlassPrefs(), true),
            ),
          ),
        ),
      ),
    );

    testWidgets('the platter pill reaches the fourth tab', (tester) async {
      await tester.pumpWidget(host(0));
      await tester.pumpWidget(host(3));
      // Let the platter spring settle.
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final pill = tester
          .widgetList<PositionedDirectional>(
            find.byType(PositionedDirectional),
          )
          .firstWhere((p) => p.start != null && p.start! > 0);
      // itemW = 400 / 4 = 100; the pill starts at 6 + 100 * index.
      expect(pill.start, closeTo(6 + 100 * 3, 2));
    });

    testWidgets('the shrunk bar stays 62 dp tall in a loose slot', (
      tester,
    ) async {
      final controller = ScrollController();
      var shrinkEnabled = true;
      Widget tree() => MaterialApp(
        home: PrimaryScrollController(
          controller: controller,
          child: Stack(
            children: [
              ListView.builder(
                itemCount: 100,
                itemBuilder: (_, i) =>
                    SizedBox(height: 50, child: Text('row $i')),
              ),
              PositionedDirectional(
                bottom: 0,
                start: 0,
                end: 0,
                child: GlassTabBar(
                  tabs: tabs,
                  index: 0,
                  onSelect: (_) {},
                  tokens: glassTokensFor(GlassPrefs(), true),
                  shrinkEnabled: shrinkEnabled,
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(tree());
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pump();
      expect(tester.getSize(find.byType(GlassTabBar)).height, 62);
      // Expanding by tap resets the accumulator: a small further
      // down-scroll must not shrink it again immediately.
      await tester.tap(find.byType(GlassTabBar));
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -10));
      await tester.pump();
      // Still the full bar: four tab icons are present.
      expect(find.byIcon(Icons.settings), findsOneWidget);
      // Toggling shrinkEnabled off and on also resets the
      // accumulator (confirmation-pass regression): shrink again,
      // toggle, then a small scroll must not re-shrink instantly.
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pump();
      // A slow up-scroll (small steps) must also unshrink
      // (confirmation pass 4): the reset accumulates upward travel
      // instead of demanding >2 dp in a single event.
      for (var i = 0; i < 8; i++) {
        controller.jumpTo(controller.offset - 3);
        await tester.pump();
      }
      expect(find.byIcon(Icons.settings), findsOneWidget);
      // A page change (rebuild) restarts the shrink accumulation
      // (confirmation pass 6): 40 dp of travel on the old page plus
      // 9 dp here must not shrink the bar on the new page.
      for (var i = 0; i < 13; i++) {
        controller.jumpTo(controller.offset + 3);
        await tester.pump();
      }
      await tester.pumpWidget(tree());
      for (var i = 0; i < 3; i++) {
        controller.jumpTo(controller.offset + 3);
        await tester.pump();
      }
      expect(find.byIcon(Icons.settings), findsOneWidget);
      // Re-shrink for the toggle check below.
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pump();
      shrinkEnabled = false;
      await tester.pumpWidget(tree());
      shrinkEnabled = true;
      await tester.pumpWidget(tree());
      await tester.drag(find.byType(ListView), const Offset(0, -10));
      await tester.pump();
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });
  });
}
