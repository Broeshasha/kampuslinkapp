import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/core/config/app_config.dart';
import 'package:kampuslink/data/catalog/catalog.dart';
import 'package:kampuslink/render/lesson_view.dart';
import 'package:kampuslink/render/segments.dart';
import 'package:kampuslink/render/table_block.dart';

import '../helpers/pump_in_app.dart';

void main() {
  test('update settings read from config, numbers or strings', () {
    final c = VersionConfig.fromMap(const {
      'min_supported_build': '6',
      'latest_build': 7,
      'update_url': '"https://play.google.com/store/apps/details?id=x"',
    });
    expect(c.min, 6);
    expect(c.latest, 7);
    expect(c.updateUrl, 'https://play.google.com/store/apps/details?id=x');
    expect(needsUpdate(5, c.min), isTrue);
    expect(needsUpdate(6, c.min), isFalse);
    expect(needsUpdate(6, c.latest), isTrue);
    expect(const VersionConfig().min, 0);
  });

  test('demo carousels only when config says true', () {
    expect(showDemoCases(null), isFalse);
    expect(showDemoCases(const Catalog()), isFalse);
    expect(
      showDemoCases(const Catalog(config: {'show_demo_cases': true})),
      isTrue,
    );
  });

  test(r'$...$ is inline math; prices with spaces stay text', () {
    expect(segmentText(r'Aire $\pi r^2$ ici', const []), const [
      TextSegment('Aire ', SegmentKind.plain),
      TextSegment(r'\pi r^2', SegmentKind.math),
      TextSegment(' ici', SegmentKind.plain),
    ]);
    expect(
      segmentText(
        r'5 $ et 6 $',
        const [],
      ).every((s) => s.kind == SegmentKind.plain),
      isTrue,
    );
    expect(TableCellData.from(r'$T_{f}$', 'fr').latex, 'T_{f}');
    expect(
      TableCellData.from({
        'id': 'c1',
        'label': r'$\rho$',
        'unit': 'kg',
      }, 'fr').latex,
      r'\rho',
    );
  });

  testWidgets('formulas in table headers and an unknown block card', (
    tester,
  ) async {
    await pumpInApp(
      tester,
      const LessonView(
        language: 'en',
        blocks: [
          {
            'id': 't1',
            'type': 'table',
            'columns': [
              'Body',
              r'$\rho$',
              {'id': 'c2', 'label': r'\mathrm{T_f}', 'unit': 'K'},
            ],
            'rows': [
              {
                'label': 'Iron',
                'cells': ['7874', '1811'],
              },
            ],
          },
          {'id': 'x1', 'type': 'hologram_3d', 'content': 'Still readable'},
        ],
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(Math), findsAtLeastNWidgets(2));
    expect(
      find.text('This part needs a newer version of the app.'),
      findsOneWidget,
    );
    expect(find.text('Still readable'), findsOneWidget);
  });
}
