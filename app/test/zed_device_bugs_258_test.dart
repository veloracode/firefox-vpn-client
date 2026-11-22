import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arman_vpn/app_settings.dart';
import 'package:arman_vpn/core/core_api.dart';
import 'package:arman_vpn/core/core_controller.dart';
import 'package:arman_vpn/l10n/app_localizations.dart';
import 'package:arman_vpn/ui/app.dart' show VpnApp;
import 'package:arman_vpn/ui/settings_page.dart';
import 'package:arman_vpn/ui/zed/zed_connect_glass.dart' show GlassSwitch;
import 'package:arman_vpn/ui/zed/zed_kit.dart';
import 'package:arman_vpn/ui/zed/zed_prefs.dart';
import 'package:arman_vpn/ui/zed/zed_theme.dart';

/// Behavioural proof for the three +257 device rejections
/// (DEFECT-CRITERIA I1/I2/I3), fixed in +258:
///  I1 — buttons/toggles register the FIRST tap and have an effect.
///  I2 — the Glass tab bar's bar-to-mini morph ANimates (intermediate
///       states sampled, not just endpoints).
///  I3 — settings rows are real inline controls, bound both ways.

CoreController _deadCore() => CoreController(
  () async => throw const CoreUnavailable(CoreProblem.noCore),
  pollInterval: const Duration(hours: 1),
);

Future<void> _pumpSettings(
  WidgetTester tester,
  AppSettings settings,
) async {
  tester.view.physicalSize = const Size(600, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: VpnApp.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SettingsPage(
        core: _deadCore(),
        settings: settings,
        section: SettingsSection.general,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The Material of the choice chip that carries [label] — the
/// NEAREST Material ancestor (the wider tree has Card/Material
/// ancestors that contain every chip).
Finder _chip(String label) => find
    .ancestor(of: find.text(label), matching: find.byType(Material))
    .first;

bool _chipChecked(String label) =>
    find
        .descendant(of: _chip(label), matching: find.byIcon(Icons.check_rounded))
        .evaluate()
        .isNotEmpty;

void main() {
  group('I1 — first tap registers, with an effect', () {
    testWidgets('GlassSwitch toggles from its padded hit box and corners', (
      tester,
    ) async {
      var value = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: StatefulBuilder(
                builder: (context, setState) => GlassSwitch(
                  tokens: glassTokensFor(GlassPrefs(), true),
                  value: value,
                  onChanged: (v) => setState(() => value = v),
                ),
              ),
            ),
          ),
        ),
      );
      final centre = tester.getCenter(find.byType(GlassSwitch));
      // Inside the 48 dp hit box but BELOW the 28 dp visual: this
      // tap was lost before the fix.
      await tester.tapAt(centre + const Offset(0, 20));
      await tester.pump();
      expect(value, isTrue, reason: 'tap in the padded box must toggle');
      // The stadium's corner region: also lost under deferToChild.
      await tester.tapAt(centre + const Offset(28, 10));
      await tester.pump();
      expect(value, isFalse, reason: 'tap at the corner must toggle');
      // Plain centre tap still works.
      await tester.tapAt(centre);
      await tester.pump();
      expect(value, isTrue);
    });

    testWidgets('a settings switch row toggles from its label, once', (
      tester,
    ) async {
      final settings = AppSettings();
      final before = settings.showPublicIp;
      await _pumpSettings(tester, settings);
      // Tap the LABEL, not the switch: the row itself must toggle.
      await tester.tap(find.text('Show the public IP'));
      await tester.pumpAndSettle();
      expect(
        settings.showPublicIp,
        !before,
        reason: 'tapping the row label must toggle the setting',
      );
      // Tap the switch itself: exactly ONE flip (the row InkWell and
      // the switch must not both fire).
      final row = find.ancestor(
        of: find.text('Show the public IP'),
        matching: find.byType(InkWell),
      );
      final sw = find.descendant(of: row, matching: find.byType(Switch));
      await tester.tap(sw);
      await tester.pumpAndSettle();
      expect(
        settings.showPublicIp,
        before,
        reason: 'tapping the switch must flip exactly once',
      );
    });

    testWidgets('a Glass switch row toggles from its label', (tester) async {
      final settings = AppSettings();
      settings.setZed(ZedPrefs()..design = ZedDesign.glass);
      final before = settings.zedPrefs.glass.shrinkTabBar;
      await _pumpSettings(tester, settings);
      await tester.scrollUntilVisible(
        find.text('Shrinking tab bar'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shrinking tab bar'));
      await tester.pumpAndSettle();
      expect(
        settings.zedPrefs.glass.shrinkTabBar,
        !before,
        reason: 'the Glass bool row must toggle from its label',
      );
    });

    testWidgets('dock and tab items select on the first tap', (tester) async {
      const tabs = [
        ZedTab(icon: Icons.home, label: 'Home'),
        ZedTab(icon: Icons.dns, label: 'Servers'),
        ZedTab(icon: Icons.settings, label: 'Settings'),
      ];
      int? picked;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: 400,
                child: BentoDock(
                  tokens: bentoTokensFor(BentoPalette.brand, true),
                  prefs: BentoPrefs(),
                  tabs: tabs,
                  index: 0,
                  onSelect: (i) => picked = i,
                ),
              ),
            ),
          ),
        ),
      );
      // The Bento dock labels only the selected tab; tap the icon.
      await tester.tap(find.byIcon(Icons.dns));
      await tester.pump();
      expect(picked, 1);

      picked = null;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: 400,
                child: GlassTabBar(
                  tokens: glassTokensFor(GlassPrefs(), true),
                  tabs: tabs,
                  index: 0,
                  onSelect: (i) => picked = i,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pump();
      expect(picked, 2);
    });
  });

  group('I2 — the Glass tab bar morph animates', () {
    testWidgets('bar to mini passes through intermediate states', (
      tester,
    ) async {
      final controller = ScrollController();
      const tabs = [
        ZedTab(icon: Icons.home, label: 'Home'),
        ZedTab(icon: Icons.dns, label: 'Servers'),
        ZedTab(icon: Icons.settings, label: 'Settings'),
      ];
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
                  child: GlassTabBar(
                    tokens: glassTokensFor(GlassPrefs(), true),
                    tabs: tabs,
                    index: 0,
                    onSelect: (_) {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      List<double> opacities() => [
        for (final o in tester.widgetList<Opacity>(
          find.descendant(
            of: find.byType(GlassTabBar),
            matching: find.byType(Opacity),
          ),
        ))
          o.opacity,
      ];

      // The spring settles asymptotically: endpoints are approximate.
      bool settled(List<double> ops) =>
          ops.length == 2 && ops.every((o) => o < 0.001 || o > 0.999);

      // Samples frames until the morph settles; true when some
      // frame was strictly between the endpoints (an animated
      // morph), false when the change was a one-frame snap.
      Future<bool> morphAnimates() async {
        for (var i = 0; i < 200; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          final ops = opacities();
          if (ops.any((o) => o > 0.05 && o < 0.95)) return true;
          if (i > 3 && settled(ops)) {
            return false; // settled with no intermediate frame
          }
        }
        return false;
      }

      expect(settled(opacities()), isTrue);
      // Sustained down-scroll trips the shrink. jumpTo notifies the
      // bar's listener synchronously without advancing fake time, so
      // the sampling below starts at the morph's first frames.
      controller.jumpTo(120);
      expect(
        await morphAnimates(),
        isTrue,
        reason:
            'the bar-to-mini change must pass through intermediate '
            'opacity/scale states — a snap is defect I2',
      );
      // Mid-morph the layers also scale through (0.9, 1.0).
      await tester.pumpAndSettle();
      expect(settled(opacities()), isTrue);
      // Tapping the mini circle morphs back — again animated.
      await tester.tap(find.byType(GlassTabBar));
      expect(
        await morphAnimates(),
        isTrue,
        reason: 'the mini-to-bar change must animate too',
      );
      await tester.pumpAndSettle();
      expect(settled(opacities()), isTrue);
    });
  });

  group('I3 — settings choices are real inline controls', () {
    testWidgets('wallpaper chips: stored value marked, tap applies + persists', (
      tester,
    ) async {
      final settings = AppSettings();
      settings.setZed(
        ZedPrefs()
          ..design = ZedDesign.glass
          ..glass.wallpaper = GlassWallpaper.lagoon,
      );
      await _pumpSettings(tester, settings);
      await tester.scrollUntilVisible(
        find.text('Wallpaper'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      // Load direction: the stored value's chip is the checked one.
      expect(_chipChecked('Lagoon'), isTrue);
      expect(_chipChecked('Dusk'), isFalse);
      // Change direction: one tap on another chip applies at once —
      // no dialog — and the value is persisted to the settings.
      await tester.tap(find.text('Dusk'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(settings.zedPrefs.glass.wallpaper, GlassWallpaper.dusk);
      expect(_chipChecked('Dusk'), isTrue);
      expect(_chipChecked('Lagoon'), isFalse);
    });

    testWidgets('design chips switch the design and its settings panel', (
      tester,
    ) async {
      final settings = AppSettings();
      await _pumpSettings(tester, settings);
      await tester.scrollUntilVisible(
        find.text('Design'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(_chipChecked('Bento'), isTrue);
      await tester.tap(find.text('Glass'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(settings.zedPrefs.design, ZedDesign.glass);
      expect(_chipChecked('Glass'), isTrue);
      // The panel below follows the design: Glass-only rows appear.
      expect(find.text('Wallpaper'), findsWidgets);
    });
  });
}
