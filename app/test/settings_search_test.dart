import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:arman_vpn/l10n/app_localizations.dart';
import 'package:arman_vpn/l10n/app_localizations_en.dart';
import 'package:arman_vpn/ui/settings_page.dart';

/// Where a section's own builder sits in the page's source, so a title found
/// there belongs to that section.
const _builders = {
  'general': SettingsSection.general,
  'connection': SettingsSection.connection,
  'bypass': SettingsSection.relay,
  'upstreamProxy': SettingsSection.upstreamProxy,
  'fragment': SettingsSection.fragment,
  'routing': SettingsSection.routing,
  'tun': SettingsSection.tun,
  'dns': SettingsSection.dns,
  'advanced': SettingsSection.advanced,
};

/// The l10n keys each section shows as a row's or a panel's title: what the
/// search must be able to find.
Set<(SettingsSection, String)> _titlesInSource(String source) {
  final starts = <(int, String)>[
    for (final m in RegExp(
      r'\n  Widget _(\w+)\(AppLocalizations l',
    ).allMatches(source))
      (m.start, m.group(1)!),
  ];
  SettingsSection? sectionAt(int position) {
    SettingsSection? found;
    for (final (at, name) in starts) {
      if (at <= position) {
        found = _builders[name];
      } else {
        break;
      }
    }
    return found;
  }

  final titles = <(SettingsSection, String)>{};
  for (final pattern in [
    r'\blabel: l\.(\w+)',
    r'\btitle: l\.(\w+)',
    r'\btitle: Text\(l\.(\w+)\)',
  ]) {
    for (final m in RegExp(pattern).allMatches(source)) {
      final section = sectionAt(m.start);
      if (section != null) titles.add((section, m.group(1)!));
    }
  }
  return titles;
}

void main() {
  test('the search index holds every setting the sections show', () {
    final source = File('lib/ui/settings_page.dart').readAsStringSync();
    final english = jsonDecode(
      File('lib/l10n/app_en.arb').readAsStringSync(),
    ) as Map<String, Object?>;
    final AppLocalizations l = AppLocalizationsEn();
    final index = settingsIndex(l).toSet();

    final missing = <String>[];
    for (final (section, key) in _titlesInSource(source)) {
      final text = english[key];
      expect(text, isA<String>(), reason: '$key is not in app_en.arb');
      if (!index.contains((section, text as String))) {
        missing.add('$key (${section.name})');
      }
    }
    expect(
      missing,
      isEmpty,
      reason:
          'These settings cannot be found by searching. Add them to '
          'settingsIndex in lib/ui/settings_page.dart: ${missing.join(', ')}',
    );
  });

  test('the search index has no entry the sections no longer show', () {
    final source = File('lib/ui/settings_page.dart').readAsStringSync();
    final english = jsonDecode(
      File('lib/l10n/app_en.arb').readAsStringSync(),
    ) as Map<String, Object?>;
    final shown = {
      for (final (section, key) in _titlesInSource(source))
        (section, english[key] as String),
    };
    final stale = [
      for (final entry in settingsIndex(AppLocalizationsEn()))
        if (!shown.contains(entry)) '${entry.$2} (${entry.$1.name})',
    ];
    expect(
      stale,
      isEmpty,
      reason:
          'These are in settingsIndex but no section shows them any more: '
          '${stale.join(', ')}',
    );
  });
}
