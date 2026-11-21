import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:arman_vpn/l10n/app_localizations.dart';
import 'package:arman_vpn/ui/bypass_apps_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const android = MethodChannel('app/android');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late String clipboard;
  late List<Map<Object?, Object?>> saves;

  setUp(() {
    clipboard = '';
    saves = [];
    messenger.setMockMethodCallHandler(android, (call) async {
      switch (call.method) {
        case 'installedApps':
          return [
            {'package': 'my.bank', 'label': 'Bank'},
            {'package': 'org.telegram', 'label': 'Telegram'},
            {'package': 'com.example.mail', 'label': 'Mail', 'launcher': false},
          ];
        case 'appRouting':
          return {
            'mode': 'exclude',
            'bypass': ['my.bank'],
            'only': ['com.example.other'],
            'region': ['my.bank'],
          };
        case 'setAppRouting':
          saves.add(call.arguments as Map<Object?, Object?>);
          return null;
        case 'setRoutingEnabled':
        case 'appIcon':
          return null;
        default:
          fail('Unexpected platform call: ${call.method}');
      }
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      switch (call.method) {
        case 'Clipboard.getData':
          return {'text': clipboard};
        case 'Clipboard.setData':
          clipboard =
              (call.arguments as Map<Object?, Object?>)['text'] as String;
      }
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(android, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> openPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const BypassAppsPage()),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String action) async {
    await tester.tap(find.byType(PopupMenuButton<void>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(action));
    await tester.pumpAndSettle();
  }

  testWidgets('merges, exports, and replaces the current mode selection', (
    tester,
  ) async {
    await openPage(tester);
    clipboard = ' org.telegram, com.example.mail\r\norg.telegram\nmissing.app ';
    await choose(tester, 'Import from Clipboard');
    await tester.tap(find.text('Merge'));
    await tester.pumpAndSettle();
    expect(find.text('Imported 2 apps.'), findsOneWidget);
    expect(find.text('Mail'), findsOneWidget);
    expect(
      saves.single['bypass'],
      unorderedEquals(['my.bank', 'org.telegram', 'com.example.mail']),
    );
    expect(saves.single['apply'], false);

    await choose(tester, 'Export to Clipboard');
    expect(clipboard, 'com.example.mail\nmy.bank\norg.telegram');

    clipboard = 'org.telegram';
    await choose(tester, 'Import from Clipboard');
    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();
    expect(saves.last['bypass'], ['org.telegram']);
    expect(saves.last['only'], ['com.example.other']);
    expect(saves.last['declined'], ['my.bank']);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(saves.where((save) => save['apply'] == true), hasLength(1));
    expect(saves.last['bypass'], ['org.telegram']);
  });

  testWidgets('ignores unrelated clipboard text without changing selection', (
    tester,
  ) async {
    await openPage(tester);
    clipboard = 'a website URL, missing.app';
    await choose(tester, 'Import from Clipboard');
    expect(
      find.text('No installed apps match the package names in the clipboard.'),
      findsOneWidget,
    );
    expect(saves, isEmpty);
  });
}
