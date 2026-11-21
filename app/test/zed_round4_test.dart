// Round-4 pins: the fidelity fixes proven against the Kotlin
// source this round (Bento slide/rail/hold/morph/tile geometry and
// RTL mirroring, the algorithmic-palette accent seed, the Pixel
// active-phase container, both switches' active checked state, the
// GlassSwitch press squash, the GlassTopEdge, the glass dock) and
// the lag fixes (wallpaper repaint discipline, the entrance
// window gate). "Improvement" this round meant NO new features:
// the UIs sit exactly like the original, with no lag.

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firefox_vpn/ui/zed/zed_connect.dart';
import 'package:firefox_vpn/ui/zed/zed_glass.dart';
import 'package:firefox_vpn/ui/zed/zed_kit.dart';
import 'package:firefox_vpn/ui/zed/zed_motion.dart';
import 'package:firefox_vpn/ui/zed/zed_prefs.dart';
import 'package:firefox_vpn/ui/zed/zed_theme.dart';

Widget _host(ZedPrefs prefs, Widget child, {TextDirection dir = TextDirection.ltr}) {
  return MaterialApp(
    theme: ZedTheme.build(Brightness.dark, const Locale('en'), prefs),
    home: Directionality(
      textDirection: dir,
      child: Scaffold(body: Center(child: SizedBox(width: 320, child: child))),
    ),
  );
}

ZedConnectState _state({
  bool on = false,
  bool busy = false,
  bool live = false,
  String label = 'Off',
  String hint = 'Tap to connect',
  required VoidCallback cb,
}) => ZedConnectState(
  on: on,
  busy: busy,
  live: live,
  label: label,
  hint: hint,
  onToggle: cb,
);

void main() {
  group('Algorithmic Bento palettes take the user accent seed', () {
    test('the seed changes the derived colours', () {
      final iris = bentoTokensFor(BentoPalette.accent, true, seed: 0xFF5646D6);
      final crimson = bentoTokensFor(
        BentoPalette.accent,
        true,
        seed: 0xFFC0362C,
      );
      expect(iris.lime, isNot(crimson.lime));
      expect(iris.ground, isNot(crimson.ground));
    });

    test('the default seed is the default accent (Iris)', () {
      expect(
        bentoTokensFor(BentoPalette.vivid, false).lime,
        bentoTokensFor(BentoPalette.vivid, false, seed: 0xFF5646D6).lime,
      );
    });

    test('named palettes ignore the seed', () {
      expect(
        bentoTokensFor(BentoPalette.zedLime, true, seed: 0xFFC0362C).lime,
        bentoTokensFor(BentoPalette.zedLime, true).lime,
      );
    });
  });

  group('Lag: wallpaper repaint discipline', () {
    testWidgets('an equal rebuild does not repaint the glow layer', (
      tester,
    ) async {
      const prefs = ZedPrefs(
        design: ZedDesign.glass,
        glassWallpaper: GlassWallpaper.lagoon,
      );
      CustomPainter? glowPainter() {
        for (final e in find.byType(CustomPaint).evaluate()) {
          final w = e.widget as CustomPaint;
          if (w.painter.runtimeType.toString() == '_GlowPainter') {
            return w.painter;
          }
        }
        return null;
      }

      await tester.pumpWidget(
        _host(prefs, const GlassWallpaperView(prefs: prefs, dark: true)),
      );
      final first = glowPainter();
      expect(first, isNotNull, reason: 'Lagoon carries glows');
      // A fresh, equal widget tree — the shell rebuild case.
      await tester.pumpWidget(
        _host(prefs, const GlassWallpaperView(prefs: prefs, dark: true)),
      );
      final second = glowPainter();
      expect(second, isNotNull);
      expect(
        second!.shouldRepaint(first!),
        isFalse,
        reason:
            'equal glows must not repaint the full-screen layer '
            '(round 4: value comparison, not list identity)',
      );
    });
  });

  group('Lag: the entrance window gate', () {
    testWidgets('a row composed after the window renders settled', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZedEntrance(
            index: 3,
            startedAt: DateTime.now().subtract(const Duration(seconds: 2)),
            child: const Text('row'),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('row'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ZedEntrance),
          matching: find.byType(Opacity),
        ),
        findsNothing,
        reason: 'post-window rows carry no animation wrapper at all',
      );
    });

    testWidgets('a row inside the window still animates in', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZedEntrance(
            index: 0,
            startedAt: DateTime.now(),
            child: const Text('row'),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(ZedEntrance),
          matching: find.byType(Opacity),
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 900));
    });
  });

  group('GlassTopEdge (the 4th sanctioned blur site)', () {
    testWidgets('height is the status inset + 14; absent without one', (
      tester,
    ) async {
      const prefs = ZedPrefs(design: ZedDesign.glass);
      Widget strip(double top) => MaterialApp(
        home: Align(
          alignment: Alignment.topCenter,
          child: MediaQuery(
            data: MediaQueryData(viewPadding: EdgeInsets.only(top: top)),
            child: const GlassTopEdge(prefs: prefs, dark: true),
          ),
        ),
      );
      await tester.pumpWidget(strip(24));
      expect(tester.getSize(find.byType(GlassTopEdge)).height, 38);
      expect(find.byType(BackdropFilter), findsOneWidget);

      await tester.pumpWidget(strip(0));
      expect(tester.getSize(find.byType(GlassTopEdge)).height, 0);
      expect(find.byType(BackdropFilter), findsNothing);
    });
  });

  group('GlassSwitch press squash', () {
    testWidgets('pressing stretches the knob; releasing restores it', (
      tester,
    ) async {
      const prefs = ZedPrefs(design: ZedDesign.glass);
      await tester.pumpWidget(
        _host(
          prefs,
          GlassSwitch(value: false, onChanged: (_) {}, prefs: prefs),
        ),
      );
      // The knob is the white 37x24 capsule; measure its RENDERED
      // width — the squash scales it toward 1 + 0.22 = 1.22x.
      // (While pressed its colour lerps to white at 55% alpha —
      // the RGB stays 1.0, only the alpha moves.)
      Finder knob() => find.byWidgetPredicate((w) {
        if (w is! Container || w.decoration is! BoxDecoration) return false;
        final d = w.decoration as BoxDecoration;
        final c = d.color;
        return c != null &&
            c.r == 1 &&
            c.g == 1 &&
            c.b == 1 &&
            d.borderRadius == BorderRadius.circular(12);
      });
      expect(tester.getRect(knob()).width, 37);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(GlassSwitch)),
      );
      // One frame to rebuild with the press state, one to run the
      // 180 ms squash tween to its end.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        tester.getRect(knob()).width,
        greaterThan(41),
        reason: 'the pressed knob squashes toward 1 + 0.22·s',
      );
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getRect(knob()).width, 37);
    });
  });

  group('Glass dock (GlassTabBar)', () {
    const items = <(IconData, IconData, String)>[
      (Icons.home_outlined, Icons.home_rounded, 'Home'),
      (Icons.dns_outlined, Icons.dns_rounded, 'Servers'),
      (Icons.settings_outlined, Icons.settings_rounded, 'Settings'),
    ];

    testWidgets('the bar is 62 high; icon sits above its label', (
      tester,
    ) async {
      const prefs = ZedPrefs(design: ZedDesign.glass);
      await tester.pumpWidget(
        MaterialApp(
          theme: ZedTheme.build(Brightness.dark, const Locale('en'), prefs),
          home: Scaffold(
            bottomNavigationBar: ZedDock(
              prefs: prefs,
              items: items,
              selected: 0,
              onSelect: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.getSize(find.byType(GlassChrome)).height, 62);
      final iconY = tester.getCenter(find.byIcon(Icons.home_rounded)).dy;
      final labelY = tester.getCenter(find.text('Home')).dy;
      expect(iconY, lessThan(labelY), reason: 'icon over label, 1 dp apart');
    });

    testWidgets('shrunk: only the current tab, as a circle', (tester) async {
      const prefs = ZedPrefs(design: ZedDesign.glass);
      await tester.pumpWidget(
        MaterialApp(
          theme: ZedTheme.build(Brightness.dark, const Locale('en'), prefs),
          home: Scaffold(
            bottomNavigationBar: ZedDock(
              prefs: prefs,
              items: items,
              selected: 1,
              onSelect: (_) {},
              shrunk: true,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.dns_rounded), findsOneWidget);
      expect(find.byIcon(Icons.home_rounded), findsNothing);
      expect(find.text('Servers'), findsNothing);
    });

    testWidgets('glass ignores the full-bar nav style', (tester) async {
      const prefs = ZedPrefs(
        design: ZedDesign.glass,
        navStyle: NavBarStyle.fullBar,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ZedTheme.build(Brightness.dark, const Locale('en'), prefs),
          home: Scaffold(
            bottomNavigationBar: ZedDock(
              prefs: prefs,
              items: items,
              selected: 0,
              onSelect: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(GlassChrome), findsOneWidget);
    });
  });

  group('Bento slide', () {
    const prefs = ZedPrefs(
      design: ZedDesign.bento,
      bentoConnect: BentoConnectStyle.slide,
    );

    testWidgets('the block is 84 high', (tester) async {
      await tester.pumpWidget(
        _host(
          prefs,
          ZedConnectControl(prefs: prefs, state: _state(cb: () {})),
        ),
      );
      expect(tester.getSize(find.byType(ZedConnectControl)).height, 84);
    });

    testWidgets('RTL mirrors the drag: sliding left connects', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          prefs,
          ZedConnectControl(prefs: prefs, state: _state(cb: () => taps++)),
          dir: TextDirection.rtl,
        ),
      );
      await tester.drag(find.byType(ZedConnectControl), const Offset(-240, 0));
      await tester.pump();
      expect(taps, 1, reason: 'in RTL the position grows toward the end');
    });

    testWidgets('RTL: sliding right does not connect', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          prefs,
          ZedConnectControl(prefs: prefs, state: _state(cb: () => taps++)),
          dir: TextDirection.rtl,
        ),
      );
      await tester.drag(find.byType(ZedConnectControl), const Offset(240, 0));
      await tester.pump();
      expect(taps, 0);
    });
  });

  group('Bento rail', () {
    const prefs = ZedPrefs(
      design: ZedDesign.bento,
      bentoConnect: BentoConnectStyle.rail,
    );

    testWidgets('off: the middle carries the tap hint', (tester) async {
      await tester.pumpWidget(
        _host(
          prefs,
          ZedConnectControl(prefs: prefs, state: _state(cb: () {})),
        ),
      );
      expect(find.text('Tap to connect'), findsOneWidget);
    });

    testWidgets('busy: the wave runs and the knob sits at the end', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          prefs,
          ZedConnectControl(
            prefs: prefs,
            state: _state(busy: true, label: 'Connecting', cb: () {}),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final wave = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_RailWavePainter',
      );
      // The painter rides a CustomPaint; assert via its widget type.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is CustomPaint &&
              w.painter.runtimeType.toString() == '_RailWavePainter',
        ),
        findsOneWidget,
      );
      expect(wave, findsNothing, reason: 'finder sanity (painters are not widgets)');
      final knob = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle,
      );
      final controlBox = tester.getRect(find.byType(ZedConnectControl));
      final knobBox = tester.getRect(knob.first);
      expect(
        controlBox.right - knobBox.right,
        inInclusiveRange(6, 10),
        reason: 'busy counts as on: the knob travels to the end (8 padding)',
      );
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Bento hold', () {
    testWidgets('the knob disc is 64 across', (tester) async {
      const prefs = ZedPrefs(
        design: ZedDesign.bento,
        bentoConnect: BentoConnectStyle.hold,
      );
      await tester.pumpWidget(
        _host(
          prefs,
          ZedConnectControl(prefs: prefs, state: _state(cb: () {})),
        ),
      );
      final disc = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle,
      );
      expect(tester.getSize(disc.first), const Size(64, 64));
    });
  });

  group('Pixel switch: busy is active', () {
    testWidgets('the container activates and the knob travels while busy', (
      tester,
    ) async {
      const prefs = ZedPrefs(
        design: ZedDesign.pixel,
        pixelConnect: PixelConnectStyle.switchStyle,
      );
      await tester.pumpWidget(
        _host(
          prefs,
          ZedConnectControl(
            prefs: prefs,
            state: _state(busy: true, label: 'Connecting', cb: () {}),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      final scheme = Theme.of(
        tester.element(find.byType(ZedConnectControl)),
      ).colorScheme;
      final box = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == scheme.secondaryContainer,
      );
      expect(box, findsOneWidget, reason: 'containerFor(): busy is active');
      final knob = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle,
      );
      final controlBox = tester.getRect(find.byType(ZedConnectControl));
      final knobBox = tester.getRect(knob.first);
      expect(knobBox.center.dx, greaterThan(controlBox.center.dx));
    });
  });

  group('Glass card switch: busy reads ON', () {
    testWidgets('the switch is checked while connecting', (tester) async {
      const prefs = ZedPrefs(
        design: ZedDesign.glass,
        glassConnect: GlassConnectStyle.switchStyle,
      );
      await tester.pumpWidget(
        _host(
          prefs,
          ZedConnectControl(
            prefs: prefs,
            state: _state(busy: true, label: 'Connecting', cb: () {}),
          ),
        ),
      );
      final sw = tester.widget<GlassSwitch>(find.byType(GlassSwitch));
      expect(sw.value, isTrue, reason: 'checked = phase != Off');
    });
  });

  group('Glass group cells wear the cell shape', () {
    testWidgets('a group container is radius 26, a module 24', (tester) async {
      const prefs = ZedPrefs(design: ZedDesign.glass);
      await tester.pumpWidget(
        _host(
          prefs,
          Column(
            children: [
              ZedGroup(prefs: prefs, rows: const [Text('a')]),
              const ZedModule(prefs: prefs, child: Text('b')),
            ],
          ),
        ),
      );
      final modules = tester
          .widgetList<GlassModule>(find.byType(GlassModule))
          .toList();
      expect(modules.length, 2);
      expect(modules.map((m) => m.radius), containsAll(<double>[26, 24]));
    });
  });

  group('Morph: the press squash sits on the blob alone', () {
    testWidgets('pressing scales the 90 dp blob box to 0.94', (tester) async {
      const prefs = ZedPrefs(
        design: ZedDesign.bento,
        bentoConnect: BentoConnectStyle.morph,
      );
      await tester.pumpWidget(
        _host(
          prefs,
          ZedConnectControl(prefs: prefs, state: _state(cb: () {})),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ZedConnectControl)),
      );
      await tester.pump(const Duration(milliseconds: 200));
      final scales = tester
          .widgetList<AnimatedScale>(find.byType(AnimatedScale))
          .toList();
      expect(scales.length, 1);
      expect(scales.single.scale, 0.94);
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 300));
    });
  });
}
