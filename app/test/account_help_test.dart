import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firefox_vpn/l10n/app_localizations.dart';
import 'package:firefox_vpn/ui/account_help.dart';

void main() {
  Future<void> openDialog(WidgetTester tester, Locale locale) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDotMethodDialog(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('the dot method dialog explains the method (en)', (
    tester,
  ) async {
    await openDialog(tester, const Locale('en'));
    final l = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l.dotMethodTitle), findsOneWidget);
    expect(find.text(l.dotMethodIntro), findsOneWidget);
    expect(find.text(l.dotMethodPoint), findsOneWidget);
    expect(find.text(l.dotMethodStep1), findsOneWidget);
    expect(find.text(l.dotMethodStep2), findsOneWidget);
    expect(find.text(l.dotMethodStep3), findsOneWidget);
    expect(find.text('name@gmail.com'), findsOneWidget);
    expect(find.textContaining('n.ame@gmail.com'), findsOneWidget);
    expect(find.text(l.createAccountButton), findsOneWidget);
  });

  testWidgets('the dot method dialog is translated (fa)', (tester) async {
    await openDialog(tester, const Locale('fa'));
    final l = lookupAppLocalizations(const Locale('fa'));
    expect(find.text(l.dotMethodTitle), findsOneWidget);
    expect(find.text(l.dotMethodStep1), findsOneWidget);
    expect(find.text(l.dotMethodExample), findsOneWidget);
  });

  testWidgets('the help links offer creation and the dot method', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: AccountHelpLinks()),
      ),
    );
    await tester.pumpAndSettle();
    final l = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l.createAccountButton), findsOneWidget);
    expect(find.text(l.dotMethodEntry), findsOneWidget);
    // The entry opens the explainer.
    await tester.tap(find.text(l.dotMethodEntry));
    await tester.pumpAndSettle();
    expect(find.text(l.dotMethodTitle), findsOneWidget);
  });
}
