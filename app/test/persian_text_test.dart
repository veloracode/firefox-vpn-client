import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // Everyday Persian leaves these marks out ("تایید", "پنجره برنامه"); a
  // string written with them reads as stiff, so none may come back.
  test('Persian is written without hamza marks', () {
    const marks = {
      'أ': 'alef with hamza (أ)',
      'ٔ': 'hamza above (ٔ)',
      'ً': 'tanween (ً), as in "لطفا" or "مثلا"',
    };
    final strings = jsonDecode(
      File('lib/l10n/app_fa.arb').readAsStringSync(),
    ) as Map<String, Object?>;
    final readme = File('../docs/readme/README_fa.md').readAsStringSync();
    final found = <String>[];
    strings.forEach((key, value) {
      if (value is! String) return;
      for (final mark in marks.keys) {
        if (value.contains(mark)) found.add('$key: ${marks[mark]}');
      }
    });
    for (final mark in marks.keys) {
      if (readme.contains(mark)) found.add('README_fa.md: ${marks[mark]}');
    }
    expect(found, isEmpty, reason: 'Write these without the mark: $found');
  });
}
