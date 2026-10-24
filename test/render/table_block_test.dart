import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/render/lesson_view.dart';
import 'package:kampuslink/render/table_block.dart';

import '../helpers/pump_in_app.dart';

void main() {
  test('cells: strings, maps, latex and localized labels', () {
    final cells = rowCells({
      'cells': [
        'plain',
        {'value': '12', 'unit': 'kg', 'note': 'approx.'},
        {'latex': r'\mathrm{Fe_2O_3}'},
        3.5,
      ],
    }, 'fr');
    expect(cells.map((c) => c.value), ['plain', '12', '', '3.5']);
    expect(cells[1].unit, 'kg');
    expect(cells[2].latex, r'\mathrm{Fe_2O_3}');
    expect(
      rowCells({
        'values': ['a'],
      }, 'fr').single.value,
      'a',
    );
    expect(
      TableCellData.from({'en': 'Row', 'fr': 'Ligne'}, 'fr').value,
      'Ligne',
    );
    expect(looksLikeLatex(r'\mathrm{CO_2}'), isTrue);
    expect(looksLikeLatex('10^{-3}'), isTrue);
    expect(looksLikeLatex('Fer (III)'), isFalse);
    expect(looksLikeLatex(r'\(x\)'), isFalse);
  });

  testWidgets('a table shows every row and draws its formulas', (tester) async {
    await pumpInApp(
      tester,
      const LessonView(
        language: 'fr',
        blocks: [
          {
            'id': 't1',
            'type': 'table',
            'caption': 'Oxydes',
            'columns': ['Corps', 'Formule', 'Masse'],
            'rows': [
              {
                'label': 'Rouille',
                'cells': [
                  r'\mathrm{Fe_2O_3}',
                  {'value': '160', 'unit': 'g/mol'},
                ],
              },
              {
                'label': {'fr': 'Gaz', 'en': 'Gas'},
                'cells': [
                  {'latex': r'\mathrm{CO_2}'},
                  r'\(44\) g/mol',
                ],
              },
            ],
          },
        ],
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Rouille'), findsOneWidget);
    expect(find.text('Gaz'), findsOneWidget);
    expect(find.text('160'), findsOneWidget);
    expect(find.byType(Math), findsAtLeastNWidgets(3));
  });
}
