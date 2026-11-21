import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:firefox_vpn/app_settings.dart';
import 'package:firefox_vpn/ui/zed/zed_connect.dart';
import 'package:firefox_vpn/ui/zed/zed_prefs.dart';
import 'package:firefox_vpn/ui/zed/zed_theme.dart';

void main() {
  group('ZedPrefs', () {
    test('defaults are ZedSecure defaults: Bento, ZedLime, Push', () {
      const p = ZedPrefs();
      expect(p.design, ZedDesign.bento);
      expect(p.bentoPalette, BentoPalette.zedLime);
      expect(p.transitionStyle, ZedTransitionStyle.push);
      expect(p.glassMaterial, GlassMaterial.clear);
      // The documented defaults (extract §0/§3): ExpressivePill nav,
      // Leaf corners — both corrected in round 2 (P1).
      expect(p.navStyle, NavBarStyle.expressivePill);
      expect(p.bentoCorner, BentoCorner.leaf);
      // The documented GlassPrefs defaults: lists and shrink on,
      // motion highlights OFF (opt-in).
      expect(p.glassLists, isTrue);
      expect(p.glassShrinkBar, isTrue);
      expect(p.glassMotionHighlights, isFalse);
    });

    test('JSON round-trips EVERY field, each set off its default', () {
      // Every field carries a value that differs from both the Dart
      // default and the fromJson fallback, so a dropped or misnamed
      // JSON key anywhere fails this test (round-2 review, T4).
      const p = ZedPrefs(
        design: ZedDesign.glass,
        bentoPalette: BentoPalette.berry,
        bentoCorner: BentoCorner.leaf,
        bentoConnect: BentoConnectStyle.tile,
        bentoDockLabels: BentoDockLabels.never,
        bentoAmoled: true,
        glassMaterial: GlassMaterial.tinted,
        glassWallpaper: GlassWallpaper.graphite,
        glassTint: 11,
        glassConnect: GlassConnectStyle.slider,
        glassLists: false,
        glassShrinkBar: false,
        glassMotionHighlights: true,
        reduceTransparency: true,
        glassShowSpeed: false,
        glassShowTimer: false,
        pixelAccent: 9,
        pixelConnect: PixelConnectStyle.ring,
        pixelAmoled: true,
        oldConnect: PixelConnectStyle.bar,
        oldAmoled: true,
        navStyle: NavBarStyle.minimal,
        transitionStyle: ZedTransitionStyle.flip,
        profile: ZedThemeProfile.clay,
      );
      final b = ZedPrefs.fromJson(p.toJson());
      expect(b.design, p.design);
      expect(b.bentoPalette, p.bentoPalette);
      expect(b.bentoCorner, p.bentoCorner);
      expect(b.bentoConnect, p.bentoConnect);
      expect(b.bentoDockLabels, p.bentoDockLabels);
      expect(b.bentoAmoled, p.bentoAmoled);
      expect(b.glassMaterial, p.glassMaterial);
      expect(b.glassWallpaper, p.glassWallpaper);
      expect(b.glassTint, p.glassTint);
      expect(b.glassConnect, p.glassConnect);
      expect(b.glassLists, p.glassLists);
      expect(b.glassShrinkBar, p.glassShrinkBar);
      expect(b.glassMotionHighlights, p.glassMotionHighlights);
      expect(b.reduceTransparency, p.reduceTransparency);
      expect(b.glassShowSpeed, p.glassShowSpeed);
      expect(b.glassShowTimer, p.glassShowTimer);
      expect(b.pixelAccent, p.pixelAccent);
      expect(b.pixelConnect, p.pixelConnect);
      expect(b.pixelAmoled, p.pixelAmoled);
      expect(b.oldConnect, p.oldConnect);
      expect(b.oldAmoled, p.oldAmoled);
      expect(b.navStyle, p.navStyle);
      expect(b.transitionStyle, p.transitionStyle);
      expect(b.profile, p.profile);
    });

    test('JSON round-trips every block', () {
      const p = ZedPrefs(
        design: ZedDesign.glass,
        bentoPalette: BentoPalette.ocean,
        glassTint: 5,
        glassConnect: GlassConnectStyle.slider,
        pixelAccent: 3,
        oldAmoled: true,
        transitionStyle: ZedTransitionStyle.flip,
      );
      final back = ZedPrefs.fromJson(p.toJson());
      expect(back.design, ZedDesign.glass);
      expect(back.bentoPalette, BentoPalette.ocean);
      expect(back.glassTint, 5);
      expect(back.glassConnect, GlassConnectStyle.slider);
      expect(back.pixelAccent, 3);
      expect(back.oldAmoled, isTrue);
      expect(back.transitionStyle, ZedTransitionStyle.flip);
    });

    test('per-design isolation: editing Bento leaves Glass untouched', () {
      const p = ZedPrefs(glassTint: 7, glassWallpaper: GlassWallpaper.dusk);
      final q = p.copyWith(bentoPalette: BentoPalette.berry);
      expect(q.glassTint, 7);
      expect(q.glassWallpaper, GlassWallpaper.dusk);
      expect(q.bentoPalette, BentoPalette.berry);
    });

    test('a broken or partial block falls back to defaults', () {
      final p = ZedPrefs.fromJson({'design': 'nope', 'glass': {'tint': 99}});
      expect(p.design, ZedDesign.bento);
      expect(p.glassTint, 0);
    });
  });

  group('AppSettings design mapping', () {
    Future<AppSettings> loadWith(Map<String, Object?> json) async {
      final dir = await Directory.systemTemp.createTemp('zed-settings');
      await File(
        '${dir.path}${Platform.pathSeparator}app-settings.json',
      ).writeAsString(jsonEncode(json));
      return AppSettings.load(dir.path);
    }

    test('legacy portal becomes Glass, foxy/classic become Bento', () async {
      expect((await loadWith({'ui_design': 'portal'})).uiDesign,
          UiDesign.glass);
      expect(
        (await loadWith({'ui_design': 'foxy'})).uiDesign,
        UiDesign.bento,
      );
      expect(
        (await loadWith({'ui_design': 'classic'})).uiDesign,
        UiDesign.bento,
      );
      expect(
        (await loadWith({'ui_design': 'pixel'})).uiDesign,
        UiDesign.pixel,
      );
      expect((await loadWith({'ui_design': 'old'})).uiDesign, UiDesign.old);
    });

    test('migration sets the field the app renders from (zed.design)',
        () async {
      // The theme, the home switch and both shells all read
      // settings.zed.design — the legacy branch must set THAT, not
      // just the uiDesign mirror (round-2 review, T3).
      expect(
        (await loadWith({'ui_design': 'portal'})).zed.design,
        ZedDesign.glass,
      );
      expect(
        (await loadWith({'ui_design': 'pixel'})).zed.design,
        ZedDesign.pixel,
      );
      expect(
        (await loadWith({'ui_design': 'nonsense'})).zed.design,
        ZedDesign.bento,
      );
    });

    test('a conflicting stored zed block beats ui_design', () async {
      final s = await loadWith({
        'ui_design': 'pixel',
        'zed': const ZedPrefs(design: ZedDesign.glass).toJson(),
      });
      expect(s.zed.design, ZedDesign.glass);
      expect(s.uiDesign, UiDesign.glass);
    });

    test('a malformed zed value degrades to defaults, no crash', () async {
      final s = await loadWith({'zed': 'junk'});
      expect(s.zed.design, ZedDesign.bento);
      expect(s.uiDesign, UiDesign.bento);
    });

    test('a stored zed block wins and round-trips through update', () async {
      final s = await loadWith({
        'zed': const ZedPrefs(
          design: ZedDesign.glass,
          glassTint: 4,
        ).toJson(),
      });
      expect(s.uiDesign, UiDesign.glass);
      expect(s.zed.glassTint, 4);
      s.update(uiDesign: UiDesign.pixel);
      expect(s.zed.design, ZedDesign.pixel);
      expect(s.zed.glassTint, 4, reason: 'other blocks stay isolated');
    });
  });

  group('Exact tokens (ZED-TOKENS-EXTRACT)', () {
    test('Brand dark carries the hardcoded stage and lime', () {
      final t = bentoTokensFor(BentoPalette.zedLime, true);
      expect(t.ground, const Color(0xFF0B0A10));
      expect(t.surface, const Color(0xFF18161F));
      expect(t.stage, const Color(0xFF311B6B));
      expect(t.onStage, const Color(0xFFEFE8FF));
      expect(t.lime, const Color(0xFFC7F24E));
      expect(t.onLime, const Color(0xFF1A2200));
      expect(t.dock, const Color(0xFF1E1B27));
      expect(t.selected, const Color(0xFF2B1D57));
    });

    test('Brand light is the light table, not an inversion', () {
      final t = bentoTokensFor(BentoPalette.zedLime, false);
      expect(t.ground, const Color(0xFFF6F6F0));
      expect(t.surface, const Color(0xFFEAEAE2));
      expect(t.stage, const Color(0xFF2A1361));
      expect(t.dock, const Color(0xFFFFFFFF));
      expect(t.good, const Color(0xFF16803F));
    });

    test('every hardcoded palette resolves in both brightnesses', () {
      for (final p in BentoPalette.values) {
        for (final dark in [true, false]) {
          final t = bentoTokensFor(p, dark);
          expect(t.ink, isNot(t.ground), reason: '$p dark=$dark');
        }
      }
    });

    test('AMOLED rewrites only the dark surfaces', () {
      final t = bentoTokensFor(BentoPalette.ocean, true, amoled: true);
      expect(t.ground, const Color(0xFF000000));
      expect(t.surface, const Color(0xFF111015));
      expect(t.dock, const Color(0xFF141319));
      final light = bentoTokensFor(BentoPalette.ocean, false, amoled: true);
      expect(light.ground, const Color(0xFFF3F7FB));
    });

    test('glass tints are the iOS pairs', () {
      expect(glassTintColor(0, true), const Color(0xFF0091FF));
      expect(glassTintColor(0, false), const Color(0xFF0088FF));
      expect(glassTintColor(1, true), const Color(0xFF30D158));
      expect(glassTintColor(6, false), const Color(0xFFFF383C));
      expect(glassTintColor(99, true), glassTintColor(11, true));
    });

    test('bento shapes are the source radii', () {
      // BentoShapes.card() (BentoKit.kt): a uniform 30 in every
      // corner style, 20 for Soft — Leaf cards are NOT asymmetric
      // (rounds 1–3 pinned tile(prominent)'s 36 values here).
      expect(bentoModuleRadius(BentoCorner.leaf), BorderRadius.circular(30));
      expect(bentoModuleRadius(BentoCorner.round), BorderRadius.circular(30));
      expect(bentoModuleRadius(BentoCorner.soft), BorderRadius.circular(20));
      expect(bentoHeroRadius(BentoCorner.soft), BorderRadius.circular(22));
    });

    test('new bento prefs round-trip', () {
      const p = ZedPrefs(
        bentoDockLabels: BentoDockLabels.never,
        bentoAmoled: true,
      );
      final back = ZedPrefs.fromJson(p.toJson());
      expect(back.bentoDockLabels, BentoDockLabels.never);
      expect(back.bentoAmoled, isTrue);
    });
  });

  group('ZedTheme', () {
    test('builds a theme for every design, light and dark', () {
      for (final design in ZedDesign.values) {
        for (final brightness in Brightness.values) {
          final theme = ZedTheme.build(
            brightness,
            const Locale('en'),
            ZedPrefs(design: design),
          );
          expect(theme.colorScheme.brightness, brightness);
        }
      }
    });

    test('Glass scaffold is transparent (the wallpaper shows through)',
        () {
      final theme = ZedTheme.build(
        Brightness.dark,
        const Locale('en'),
        const ZedPrefs(design: ZedDesign.glass),
      );
      expect(theme.scaffoldBackgroundColor, Colors.transparent);
    });

    test('AMOLED rewrites Pixel surfaces to true black', () {
      final theme = ZedTheme.build(
        Brightness.dark,
        const Locale('en'),
        const ZedPrefs(design: ZedDesign.pixel, pixelAmoled: true),
      );
      expect(theme.scaffoldBackgroundColor, Colors.black);
    });
  });

  group('ZedConnectControl actions', () {
    ZedConnectState state(VoidCallback onToggle) => ZedConnectState(
      on: false,
      busy: false,
      live: false,
      label: 'Off',
      onToggle: onToggle,
    );

    Future<void> pump(
      WidgetTester tester,
      ZedPrefs prefs,
      VoidCallback onToggle,
    ) => tester.pumpWidget(
      MaterialApp(
        theme: ZedTheme.build(Brightness.dark, const Locale('en'), prefs),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: ZedConnectControl(prefs: prefs, state: state(onToggle)),
            ),
          ),
        ),
      ),
    );

    testWidgets('Bento Button toggles on tap', (tester) async {
      var taps = 0;
      await pump(
        tester,
        const ZedPrefs(bentoConnect: BentoConnectStyle.button),
        () => taps++,
      );
      // The source's Bento Button is a custom block, not a Material
      // FilledButton (round 4): tap the control itself.
      await tester.tap(find.byType(ZedConnectControl));
      expect(taps, 1);
    });

    testWidgets('Bento Slide toggles after a past-threshold drag', (
      tester,
    ) async {
      var taps = 0;
      await pump(tester, const ZedPrefs(), () => taps++);
      await tester.drag(find.byType(ZedConnectControl), const Offset(300, 0));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('Bento Hold toggles only after the 650 ms hold', (
      tester,
    ) async {
      var taps = 0;
      await pump(
        tester,
        const ZedPrefs(bentoConnect: BentoConnectStyle.hold),
        () => taps++,
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ZedConnectControl)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(taps, 0, reason: 'a short press must not toggle');
      await tester.pump(const Duration(milliseconds: 400));
      expect(taps, 1, reason: 'holding past 650 ms toggles');
      await gesture.up();
    });

    testWidgets('Pixel Hero toggles on tap', (tester) async {
      var taps = 0;
      await pump(
        tester,
        const ZedPrefs(
          design: ZedDesign.pixel,
          pixelConnect: PixelConnectStyle.hero,
        ),
        () => taps++,
      );
      await tester.tap(find.byType(GestureDetector).first);
      expect(taps, 1);
    });

    testWidgets('Glass Z toggles on tap', (tester) async {
      var taps = 0;
      await pump(
        tester,
        const ZedPrefs(design: ZedDesign.glass),
        () => taps++,
      );
      // The Z is custom-painted since round 4 (no text glyph to
      // find): tap the control itself.
      await tester.tap(find.byType(ZedConnectControl));
      expect(taps, 1);
    });

    testWidgets('Old Pill toggles on tap', (tester) async {
      var taps = 0;
      await pump(
        tester,
        const ZedPrefs(
          design: ZedDesign.old,
          oldConnect: PixelConnectStyle.pill,
        ),
        () => taps++,
      );
      await tester.tap(find.byType(FilledButton));
      expect(taps, 1);
    });
  });
}
