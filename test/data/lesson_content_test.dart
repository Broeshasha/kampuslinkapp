import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/data/db/app_database.dart';
import 'package:kampuslink/data/lessons/lesson_content.dart';

LessonRow row(Map<String, Object?> i18n) => LessonRow(
  id: 1,
  moduleId: 7,
  position: 1,
  sourceLang: 'fr',
  i18nJson: jsonEncode(i18n),
  resourceLinksJson: '[]',
);

Map<String, Object?> lang(String title, int blocks) => {
  'title': title,
  'blocks': [
    for (var i = 0; i < blocks; i++)
      {'id': 'b$i', 'type': 'paragraph', 'content': title},
  ],
};

void main() {
  test('chosen language first, then French, then any; never empty', () {
    final all = row({
      'ar': lang('AR', 2),
      'fr': lang('FR', 2),
      'en': lang('EN', 2),
    });
    expect(LessonContent.of(all, 'en').title, 'EN');
    final noEnglish = row({'ar': lang('AR', 2), 'fr': lang('FR', 2)});
    expect(LessonContent.of(noEnglish, 'en').title, 'FR');
    final emptyFrench = row({'ar': lang('AR', 2), 'fr': lang('FR', 0)});
    final c = LessonContent.of(emptyFrench, 'fr');
    expect(c.title, 'AR');
    expect(c.blocks, isNotEmpty);
    expect(c.languages, ['ar']);
  });
}
