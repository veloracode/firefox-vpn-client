import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firefox_vpn/app_settings.dart';
import 'package:firefox_vpn/core/core_process.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('app_settings_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('defaults without a file', () async {
    final s = await AppSettings.load(dir.path);
    expect(s.language, '');
    expect(s.locale, isNull);
    expect(s.themeMode, ThemeMode.system);
    expect(s.closeAction, CloseAction.ask);
    expect(s.firstRun, isTrue);
    // Starting with the computer is off until the user turns it on.
    expect(s.autostart, isFalse);
    // Connecting by itself is the user's choice.
    expect(s.autoConnect, isFalse);
    // Home animations are on until the user turns them off.
    expect(s.animationsEnabled, isTrue);
  });

  test('saves and loads the choices', () async {
    final s = await AppSettings.load(dir.path);
    s.update(
      language: 'fa',
      themeMode: ThemeMode.dark,
      closeAction: CloseAction.tray,
      firstRun: false,
      autostart: true,
      autoConnect: true,
      animationsEnabled: false,
    );
    // update saves in the background.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final again = await AppSettings.load(dir.path);
    expect(again.locale, const Locale('fa'));
    expect(again.themeMode, ThemeMode.dark);
    expect(again.closeAction, CloseAction.tray);
    expect(again.firstRun, isFalse);
    // An explicit on for Start on boot survives the round trip.
    expect(again.autostart, isTrue);
    expect(again.autoConnect, isTrue);
    // An explicit off for Home animations survives the round trip.
    expect(again.animationsEnabled, isFalse);
  });

  test('maps languages to routing regions', () {
    expect(AppSettings.regionForLanguage('fa'), 'ir');
    expect(AppSettings.regionForLanguage('zh'), 'cn');
    expect(AppSettings.regionForLanguage('ru'), 'ru');
    expect(AppSettings.regionForLanguage('en'), isNull);
    expect(AppSettings.suggestedRegion('en', 'TR'), 'tr');
    expect(AppSettings.suggestedRegion('en', 'US'), '');
    expect(AppSettings.suggestedRegion('fa', 'DE'), 'ir');
  });

  test('ignores unknown values', () async {
    File('${dir.path}/app-settings.json')
        .writeAsStringSync('{"language": "xx", "theme": "neon", "close": 7}');
    final s = await AppSettings.load(dir.path);
    expect(s.language, '');
    expect(s.themeMode, ThemeMode.system);
    expect(s.closeAction, CloseAction.ask);
  });

  test('takes the core executable from --core', () {
    expect(
      CoreProcess.executableFrom(['--core=C:/bin/core.exe']),
      'C:/bin/core.exe',
    );
    expect(
      CoreProcess.executableFrom(const []),
      endsWith(
        Platform.isWindows
            ? r'core\firefox-vpn-core.exe'
            : 'core/firefox-vpn-core',
      ),
    );
  });
}
