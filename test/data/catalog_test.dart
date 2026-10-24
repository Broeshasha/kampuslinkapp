import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/core/theme/app_theme.dart';
import 'package:kampuslink/data/catalog/catalog.dart';
import 'package:kampuslink/render/figure_block.dart' show svgPalette;
import 'package:kampuslink/ui/module_look.dart';

/// A speciality the app has never seen: unified years, no semesters.
Map<String, dynamic> proofCatalog() => {
  'schema': 1,
  'config': {'semester_banner_windows': const [], 'show_demo_cases': false},
  'me': {'academic_year': 'Y3', 'current_semester': null},
  'speciality': {
    'id': 77,
    'name': 'G\u00e9ologie appliqu\u00e9e',
    'year_system': 'unified',
    'learn_enabled': true,
  },
  'levels': [
    {
      'year': 'Y3',
      'position': 3,
      'semesters': const [],
      'label': {'en': 'Year 3', 'fr': 'Ann\u00e9e 3', 'ar': 'Y3-ar'},
    },
    {
      'year': 'Y2',
      'position': 2,
      'semesters': const [],
      'label': {'en': 'Year 2', 'fr': 'Ann\u00e9e 2'},
    },
  ],
  'modules': [
    {
      'id': 501,
      'name': 'Roches',
      'icon': 'rock',
      'color': 'c3',
      'semester': null,
      'counts': {'lessons': 12, 'sets': 4},
    },
    {'id': 502, 'name': 'Vide', 'icon': 'hologram', 'color': 'c9'},
    {'id': 503, 'name': 'Cartes', 'icon': null, 'semester': null},
  ],
};

void main() {
  test('a new speciality is read with no app change', () {
    final c = Catalog.fromMap(proofCatalog());
    expect(c.levels.map((l) => l.year), ['Y2', 'Y3']);
    expect(c.level('Y3')!.semesters, isEmpty);
    expect(c.level('Y3')!.labelIn('fr'), 'Ann\u00e9e 3');
    expect(c.level('Y2')!.labelIn('ar'), 'Ann\u00e9e 2');
    expect(c.module(501)!.count('lessons'), 12);
    expect(c.module(502)!.count('lessons'), 0);
    expect(c.orderOf(503), 2);
    expect(c.orderOf(999), greaterThan(100));
    expect(c.learnEnabled, isTrue);
    expect(
      Catalog.fromMap(const {
        'speciality': {'learn_enabled': false},
      }).learnEnabled,
      isFalse,
    );
    expect(localized({'en': 'A', 'fr': 'B'}, 'ar'), 'B');
  });

  test('icons and colours: known keys mapped, unknown = defaults', () {
    final c = Catalog.fromMap(proofCatalog());
    expect(moduleIcon('rock'), Icons.landscape_outlined);
    expect(moduleIcon('hologram'), Icons.menu_book_rounded);
    expect(moduleIcon(null), Icons.menu_book_rounded);
    final kc = KampusColors.dark;
    expect(moduleColor(kc, 501, c.module(501)), svgPalette(kc)[2]);
    expect(moduleColor(kc, 502, c.module(502)), svgPalette(kc)[0]);
  });
}
