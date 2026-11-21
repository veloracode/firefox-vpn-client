import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:arman_vpn/app_settings.dart';
import 'package:arman_vpn/ui/zed/zed_prefs.dart';

void main() {
  group('ZedPrefs defaults (the source defaults)', () {
    test('top level', () {
      final p = ZedPrefs();
      expect(p.design, ZedDesign.bento);
      expect(p.transition, ZedTransition.push);
      expect(p.navStyle, ZedNavStyle.expressivePill);
      expect(p.reduceMotion, isFalse);
    });

    test('glass defaults: motion highlights off, lists on', () {
      final g = GlassPrefs();
      expect(g.motionHighlights, isFalse);
      expect(g.glassLists, isTrue);
      expect(g.shrinkTabBar, isTrue);
      expect(g.homeTimer, isTrue);
    });
  });

  group('JSON round-trip', () {
    test('every field survives a round trip', () {
      final p = ZedPrefs(
        design: ZedDesign.glass,
        transition: ZedTransition.flip,
        navStyle: ZedNavStyle.minimal,
        reduceMotion: true,
      );
      p.bento.palette = BentoPalette.neon;
      p.bento.corners = BentoCorners.leaf;
      p.bento.title = BentoTitleSize.huge;
      p.bento.density = BentoDensity.compact;
      p.bento.dockLabels = BentoDockLabels.never;
      p.bento.dockAutoHide = true;
      p.bento.connect = BentoConnect.hold;
      p.bento.motifs = false;
      p.bento.playfulTouch = false;
      p.bento.indexes = true;
      p.bento.liveTiles = false;
      p.bento.wave = false;
      p.bento.homeSpeed = false;
      p.bento.homeSession = false;
      p.bento.homeQuick = false;
      p.bento.homeChips = false;
      p.bento.amoled = true;
      p.bento.navStyle = ZedNavStyle.fullBar;
      p.pixel.accentIndex = 7;
      p.pixel.colorStyle = PixelColorStyle.monochrome;
      p.pixel.contrast = PixelContrast.high;
      p.pixel.cornerStyle = CardCornerStyle.pill;
      p.pixel.connect = PixelConnect.ring;
      p.pixel.trafficStyle = TrafficCardStyle.graph;
      p.pixel.trafficTileSize = TrafficTileSize.large;
      p.pixel.profileId = 'claude';
      p.pixel.customDownload = 0xFF112233;
      p.pixel.customServerCard = 0xFF445566;
      p.pixel.amoled = true;
      p.old.accentIndex = 3;
      p.glass.tint = GlassTint.pink;
      p.glass.wallpaper = GlassWallpaper.dusk;
      p.glass.material = GlassMaterial.tinted;
      p.glass.connect = GlassConnect.slider;
      p.glass.glassLists = false;
      p.glass.shrinkTabBar = false;
      p.glass.motionHighlights = true;
      p.glass.reduceTransparency = true;
      p.glass.homeSpeed = true;
      p.glass.homeTimer = false;
      p.glass.homeCard = false;

      final q = ZedPrefs.fromJson(p.toJson());
      expect(q.design, ZedDesign.glass);
      expect(q.transition, ZedTransition.flip);
      expect(q.navStyle, ZedNavStyle.minimal);
      expect(q.reduceMotion, isTrue);
      expect(q.bento.palette, BentoPalette.neon);
      expect(q.bento.corners, BentoCorners.leaf);
      expect(q.bento.title, BentoTitleSize.huge);
      expect(q.bento.density, BentoDensity.compact);
      expect(q.bento.dockLabels, BentoDockLabels.never);
      expect(q.bento.dockAutoHide, isTrue);
      expect(q.bento.connect, BentoConnect.hold);
      expect(q.bento.motifs, isFalse);
      expect(q.bento.indexes, isTrue);
      expect(q.bento.liveTiles, isFalse);
      expect(q.bento.wave, isFalse);
      expect(q.bento.homeQuick, isFalse);
      expect(q.bento.amoled, isTrue);
      expect(q.bento.navStyle, ZedNavStyle.fullBar);
      expect(q.pixel.accentIndex, 7);
      expect(q.pixel.colorStyle, PixelColorStyle.monochrome);
      expect(q.pixel.contrast, PixelContrast.high);
      expect(q.pixel.cornerStyle, CardCornerStyle.pill);
      expect(q.pixel.connect, PixelConnect.ring);
      expect(q.pixel.trafficStyle, TrafficCardStyle.graph);
      expect(q.pixel.trafficTileSize, TrafficTileSize.large);
      expect(q.pixel.profileId, 'claude');
      expect(q.pixel.customDownload, 0xFF112233);
      expect(q.pixel.customServerCard, 0xFF445566);
      expect(q.old.accentIndex, 3);
      expect(q.glass.tint, GlassTint.pink);
      expect(q.glass.wallpaper, GlassWallpaper.dusk);
      expect(q.glass.material, GlassMaterial.tinted);
      expect(q.glass.connect, GlassConnect.slider);
      expect(q.glass.glassLists, isFalse);
      expect(q.glass.motionHighlights, isTrue);
      expect(q.glass.homeTimer, isFalse);
      expect(q.glass.homeCard, isFalse);
    });

    test('an empty map yields the defaults, field by field', () {
      final q = ZedPrefs.fromJson(const {});
      final d = ZedPrefs();
      expect(q.toJson().toString(), d.toJson().toString());
    });

    test('garbage values fall back per field, never throw', () {
      final q = ZedPrefs.fromJson(const {
        'design': 'nope',
        'bento': {'palette': 42, 'motifs': 'yes'},
        'pixel': {'accent_index': 'x'},
        'glass': {'tint': null},
      });
      expect(q.design, ZedDesign.bento);
      expect(q.bento.palette, BentoPalette.brand);
      expect(q.bento.motifs, isTrue);
    });

    test('upgrade fixture: a v1.0.19 settings file loads with defaults',
        () async {
      // The previous generation's file has no zed block at all; the
      // upgrade must come up on the source defaults, not crash or
      // resurrect anything.
      final dir = await Directory.systemTemp.createTemp('zed_upgrade');
      addTearDown(() => dir.delete(recursive: true));
      await File('${dir.path}/app-settings.json').writeAsString(
        jsonEncode({'language': 'fa', 'theme': 'dark', 'welcome_done': true}),
      );
      final s = await AppSettings.load(dir.path);
      expect(s.language, 'fa');
      expect(s.zedPrefs.design, ZedDesign.bento);
      expect(s.zedPrefs.toJson().toString(), ZedPrefs().toJson().toString());
    });

    test('upgrade fixture: a partial zed block fills the rest by default',
        () async {
      final dir = await Directory.systemTemp.createTemp('zed_partial');
      addTearDown(() => dir.delete(recursive: true));
      await File('${dir.path}/app-settings.json').writeAsString(
        jsonEncode({
          'zed': {
            'design': 'glass',
            'glass': {'tint': 'pink'},
          },
        }),
      );
      final s = await AppSettings.load(dir.path);
      expect(s.zedPrefs.design, ZedDesign.glass);
      expect(s.zedPrefs.glass.tint, GlassTint.pink);
      expect(s.zedPrefs.glass.wallpaper, GlassPrefs().wallpaper);
      expect(s.zedPrefs.bento.palette, BentoPrefs().palette);
    });

    test('corrupt custom-colour values read as unset, never throw', () {
      // Regression (DeepSeek pass 1, confirmed): the custom colours
      // and profile id used raw casts; a wrong-typed value in the
      // settings file threw on every zedPrefs access.
      final q = ZedPrefs.fromJson(const {
        'pixel': {
          'c_download': 1.5,
          'c_upload': 'red',
          'c_server_card': true,
          'profile': 123,
        },
        'old': {'c_connect': 0xFF102030},
      });
      expect(q.pixel.customDownload, isNull);
      expect(q.pixel.customUpload, isNull);
      expect(q.pixel.customServerCard, isNull);
      expect(q.pixel.profileId, '');
      expect(q.old.customConnect, 0xFF102030);
    });

    test('activePixel follows the design', () {
      final p = ZedPrefs();
      p.pixel.accentIndex = 1;
      p.old.accentIndex = 9;
      p.design = ZedDesign.pixel;
      expect(p.activePixel.accentIndex, 1);
      p.design = ZedDesign.old;
      expect(p.activePixel.accentIndex, 9);
      p.design = ZedDesign.bento;
      expect(p.activePixel.accentIndex, 1);
    });
  });
}
