import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/render/code_block.dart';
import 'package:kampuslink/render/code_tokens.dart';
import 'package:kampuslink/render/lesson_view.dart';
import 'package:kampuslink/render/segments.dart';

import '../helpers/pump_in_app.dart';

const _code = 'total = 0\nfor n in range(3):  # 0, 1, 2\n    total += n';

Map<String, dynamic> _block() => {
  'id': 'c1',
  'type': 'code',
  'language': 'python',
  'code': _code,
  'output': 'Total: 3',
  'annotations': [
    {
      'line': 2,
      'text': {
        'fr': 'La boucle passe 3 fois.',
        'ar': '\u062a\u062a\u0643\u0631\u0631 \u0627\u0644\u062d\u0644\u0642\u0629 3 \u0645\u0631\u0627\u062a.',
      },
    },
  ],
};

List<String> _of(List<CodeToken> t, CodeTokenKind k) => [
  for (final x in t)
    if (x.kind == k) x.text,
];

void main() {
  test('python line: keywords, builtins, strings, numbers, comments', () {
    final t = tokenizeLine("for n in range(42):  print('a#b')  # loop");
    expect(_of(t, CodeTokenKind.keyword), ['for', 'in']);
    expect(_of(t, CodeTokenKind.builtin), ['range', 'print']);
    expect(_of(t, CodeTokenKind.number), ['42']);
    expect(_of(t, CodeTokenKind.string), ["'a#b'"]);
    expect(_of(t, CodeTokenKind.comment), ['# loop']);
    expect(
      t.map((x) => x.text).join(),
      "for n in range(42):  print('a#b')  # loop",
    );
  });

  test('fences and inline code are found in paragraphs', () {
    final parts = splitFences('Avant :\n```python\nprint(1)\n```\nApres.');
    expect(parts.length, 3);
    expect(parts[1].code, isTrue);
    expect(parts[1].language, 'python');
    expect(parts[1].text, 'print(1)');
    expect(parts[2].text, 'Apres.');
    expect(splitFences('no fence').single.code, isFalse);
    expect(segmentText('use `len(x)` here', const []), const [
      TextSegment('use ', SegmentKind.plain),
      TextSegment('len(x)', SegmentKind.code),
      TextSegment(' here', SegmentKind.plain),
    ]);
  });

  for (final (size, lang) in [
    (const Size(320, 568), 'ar'),
    (const Size(412, 915), 'fr'),
  ]) {
    testWidgets(
      'code block: line numbers, result, note, LTR, copy (${size.width.toInt()}, $lang, 1.5x)',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        String? copied;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String?;
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        await pumpInApp(tester, LessonView(blocks: [_block()], language: lang));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(CodeBlock), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(find.text('Total: 3'), findsOneWidget);
        final box = tester.element(find.byKey(const ValueKey('code-block')));
        expect(Directionality.of(box), TextDirection.ltr);
        await tester.tap(find.byTooltip('Copy'));
        await tester.pump();
        expect(copied, _code);
        expect(find.text('Code copied'), findsOneWidget);
      },
    );
  }

  testWidgets('a fenced block inside a paragraph is drawn as code', (
    tester,
  ) async {
    await pumpInApp(
      tester,
      const LessonView(
        blocks: [
          {
            'id': 'p1',
            'type': 'paragraph',
            'content': 'Run this:\n```python\nprint("hi")\n```\nThen `len` it.',
          },
        ],
        language: 'en',
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(CodeBlock), findsOneWidget);
    expect(find.text('Run this:'), findsOneWidget);
  });
}
