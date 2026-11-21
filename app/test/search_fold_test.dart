import 'package:flutter_test/flutter_test.dart';
import 'package:arman_vpn/ui/format.dart';

void main() {
  test('a search finds a name whatever keyboard wrote it', () {
    // Case and surrounding space do not matter.
    expect(foldForSearch('  DNS  '), 'dns');

    // The Arabic yeh and kaf are folded to the Persian ones, so a name
    // written with either is found by typing the other.
    const arabicYeh = 'ي';
    const persianYeh = 'ی';
    const arabicKaf = 'ك';
    const persianKaf = 'ک';
    expect(foldForSearch(arabicYeh), persianYeh);
    expect(foldForSearch(arabicKaf), persianKaf);

    // "مسیریابی" written with an Arabic keyboard still matches the menu's name.
    final menu = foldForSearch('مس$persianYehر$persianYehاب$persianYeh');
    final typed = foldForSearch('مس$arabicYehر$arabicYehاب$arabicYeh');
    expect(menu.contains(typed), isTrue);

    // A zero-width non-joiner is a space, so a joined name is found by
    // typing it with a space.
    expect(foldForSearch('برنامه‌ها'), 'برنامه ها');
  });
}
