import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/data/db/app_database.dart';
import 'package:kampuslink/data/lessons/lesson_content.dart';
import 'package:kampuslink/ui/storage_banner.dart';

import '../helpers/pump_in_app.dart';

LessonRow _row(String json) => LessonRow(
  id: 1,
  moduleId: 1,
  position: 1,
  i18nJson: json,
  resourceLinksJson: '[]',
);

void main() {
  test('a big lesson decodes off the UI thread to the same content', () async {
    final blocks = [
      for (var i = 0; i < 600; i++)
        {'id': 'b$i', 'type': 'paragraph', 'content': 'Texte num\u00e9ro $i'},
    ];
    final json = jsonEncode({
      'fr': {'title': 'Grande le\u00e7on', 'blocks': blocks},
      'ar': {'title': '\u062f\u0631\u0633', 'blocks': const []},
    });
    expect(json.length, greaterThan(lessonDecodeIsolateBytes));
    final i18n = await decodeLessonI18n(json);
    final a = LessonContent.fromI18n(_row(json), i18n, 'ar');
    final b = LessonContent.of(_row(json), 'ar');
    // Arabic has no blocks: both fall back to French, same blocks.
    expect(a.language, 'fr');
    expect(b.language, 'fr');
    expect(a.title, 'Grande le\u00e7on');
    expect(a.blocks.length, 600);
    expect(a.blocks.last['id'], b.blocks.last['id']);
    expect(await decodeLessonI18n('not json'), isEmpty);
    expect(await decodeLessonI18n(null), isEmpty);
  });

  test('only unsafe browser storage is a problem', () {
    expect(webStorageUnsafe('inMemory'), isTrue);
    expect(webStorageUnsafe('unsafeIndexedDb'), isTrue);
    expect(webStorageUnsafe('sharedIndexedDb'), isFalse);
    expect(webStorageUnsafe('opfsShared'), isFalse);
    expect(webStorageUnsafe(null), isFalse);
  });

  testWidgets('the storage warning shows only when storage is unsafe', (
    tester,
  ) async {
    final status = ValueNotifier<String?>('opfsShared');
    addTearDown(status.dispose);
    await pumpInApp(tester, StorageWarningBanner(status: status));
    const text =
        'Downloads may be lost when you close the browser. Use the phone app.';
    expect(find.text(text), findsNothing);
    status.value = 'inMemory';
    await tester.pump();
    expect(find.text(text), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    expect(find.text(text), findsNothing);
  });
}
