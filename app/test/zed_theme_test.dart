import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arman_vpn/ui/zed/zed_prefs.dart';
import 'package:arman_vpn/ui/zed/zed_theme.dart';

void main() {
  group('per-field theme behaviour', () {
    test('bento amoled turns the dark ground pure black', () {
      final normal = bentoTokensFor(BentoPalette.brand, true);
      final amoled = bentoTokensFor(
        BentoPalette.brand,
        true,
        amoled: true,
      );
      expect(normal.ground, isNot(const Color(0xFF000000)));
      expect(amoled.ground, const Color(0xFF000000));
      // Light is untouched by the amoled switch.
      expect(
        bentoTokensFor(BentoPalette.brand, false, amoled: true).ground,
        bentoTokensFor(BentoPalette.brand, false).ground,
      );
    });

    test('bento palettes resolve differently from each other', () {
      final a = bentoTokensFor(BentoPalette.brand, true);
      final b = bentoTokensFor(BentoPalette.neon, true);
      expect(a.violet.container, isNot(b.violet.container));
    });

    test('bento corners drive the card radius', () {
      // Source: soft is the one smaller step; round and leaf share 30.
      expect(bentoCardRadius(BentoCorners.soft), 20);
      expect(bentoCardRadius(BentoCorners.round), 30);
      expect(bentoCardRadius(BentoCorners.leaf), 30);
      expect(
        bentoChipRadius(BentoCorners.soft),
        lessThan(bentoChipRadius(BentoCorners.round)),
      );
    });

    test('pixel contrast raises the scheme contrast level', () {
      final p = PixelPrefs();
      final low = pixelScheme(p, Brightness.light);
      p.contrast = PixelContrast.high;
      final high = pixelScheme(p, Brightness.light);
      expect(high.primary, isNot(low.primary));
    });

    test('pixel amoled darkens the dark scheme background', () {
      final p = PixelPrefs();
      final normal = pixelScheme(p, Brightness.dark);
      p.amoled = true;
      final amoled = pixelScheme(p, Brightness.dark);
      expect(amoled.surface, const Color(0xFF000000));
      expect(normal.surface, isNot(const Color(0xFF000000)));
    });

    test('corner style maps to the source radii', () {
      expect(cornerStyleServerRadius(CardCornerStyle.squared), 6);
      expect(cornerStyleServerRadius(CardCornerStyle.rounded), 22);
      expect(cornerStyleServerRadius(CardCornerStyle.pill), 34);
    });

    test('glass tint changes the token tint colour', () {
      final blue = glassTokensFor(GlassPrefs(), true);
      final pink = glassTokensFor(
        GlassPrefs()..tint = GlassTint.pink,
        true,
      );
      expect(blue.tint, isNot(pink.tint));
      expect(pink.tint, glassTintColor(GlassTint.pink, true));
    });

    test('glass material changes the module fill', () {
      final clear = glassTokensFor(GlassPrefs(), true);
      final tinted = glassTokensFor(
        GlassPrefs()..material = GlassMaterial.tinted,
        true,
      );
      expect(clear.module, isNot(tinted.module));
    });

    test('glass reduceTransparency makes fills opaque', () {
      final t = glassTokensFor(
        GlassPrefs()..reduceTransparency = true,
        true,
      );
      expect(t.module.a, 1.0);
    });

    test('amoled reaches the scaffold and card surfaces', () {
      // Regression (DeepSeek pass 2b): pixelScheme computed the
      // AMOLED role set but ZedTheme.build used fixed greys for the
      // scaffold/card, so the toggle changed nothing visible.
      final p = ZedPrefs()..design = ZedDesign.pixel;
      p.pixel.amoled = true;
      final theme = ZedTheme.build(Brightness.dark, const Locale('en'), p);
      expect(theme.scaffoldBackgroundColor, const Color(0xFF000000));
      expect(theme.cardTheme.color, const Color(0xFF0F0F0F));
      final plain = ZedTheme.build(
        Brightness.dark,
        const Locale('en'),
        ZedPrefs()..design = ZedDesign.pixel,
      );
      expect(plain.scaffoldBackgroundColor, const Color(0xFF111218));
    });

    test('the glass rail uses the chrome material, not the solid', () {
      // Regression (DeepSeek pass 2b): the rail bypassed the
      // reduceTransparency/tinted logic by always using chromeSolid.
      final p = ZedPrefs()..design = ZedDesign.glass;
      p.glass.material = GlassMaterial.tinted;
      final theme = ZedTheme.build(Brightness.dark, const Locale('en'), p);
      expect(
        theme.navigationRailTheme.backgroundColor,
        glassTokensFor(p.glass, true).chrome,
      );
      p.glass.reduceTransparency = true;
      final reduced = ZedTheme.build(
        Brightness.dark,
        const Locale('en'),
        p,
      );
      expect(
        reduced.navigationRailTheme.backgroundColor,
        glassTokensFor(p.glass, true).chromeSolid,
      );
    });

    test('theme profiles write a whole pixel block at once', () {
      final p = PixelPrefs();
      final profile = zedProfileOf('aurora');
      expect(profile, isNotNull);
      applyZedProfile(p, profile!);
      expect(p.profileId, 'aurora');
      expect(p.customDownload, isNotNull);
      // The extract's applyThemeProfile list includes the connect
      // and connected colours (only the connect STYLE is untouched).
      expect(p.customConnect, profile.connect.toARGB32());
      expect(p.customConnected, profile.connected.toARGB32());
      expect(p.cornerStyle, CardCornerStyle.rounded);
    });

    test('ZedTheme.build carries the design extensions', () {
      final bento = ZedTheme.build(Brightness.dark, const Locale("en"), ZedPrefs());
      expect(bento.extension<ZedColors>(), isNotNull);
      expect(bento.extension<ZedGlass>(), isNull);
      final glass = ZedTheme.build(
        Brightness.dark,
        const Locale('en'),
        ZedPrefs()..design = ZedDesign.glass,
      );
      expect(glass.extension<ZedGlass>(), isNotNull);
      expect(glass.extension<ZedColors>(), isNull);
    });

    test('pixel card shape follows cornerStyle', () {
      double radius(ZedPrefs prefs) {
        final theme = ZedTheme.build(Brightness.light, const Locale("en"), prefs);
        final shape = theme.cardTheme.shape as RoundedRectangleBorder;
        return shape.borderRadius.resolve(TextDirection.ltr).topLeft.x;
      }

      final squared = ZedPrefs()..design = ZedDesign.pixel;
      squared.pixel.cornerStyle = CardCornerStyle.squared;
      final pill = ZedPrefs()..design = ZedDesign.pixel;
      pill.pixel.cornerStyle = CardCornerStyle.pill;
      expect(radius(squared), 6);
      expect(radius(pill), 34);
    });
  });
}
