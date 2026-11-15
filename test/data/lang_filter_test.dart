import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/data/content/lang_filter.dart';

void main() {
  test('deep filter follows the server rule', () {
    final out = filterLangsDeep({
      'text': {'fr': 'a', 'ar': 'b', 'en': 'c'},
      'one': {'fr': 'only one key: not a language map'},
      'mixed': {'fr': 'x', 'kind': 'note'},
      'list': [
        {'fr': 'l1', 'ar': 'l2'},
        3,
        'plain',
      ],
      'n': 4,
    }, const ['fr']);
    expect(out, {
      'text': {'fr': 'a'},
      'one': {'fr': 'only one key: not a language map'},
      'mixed': {'fr': 'x', 'kind': 'note'},
      'list': [
        {'fr': 'l1'},
        3,
        'plain',
      ],
      'n': 4,
    });
    expect(filterLangsDeep({'ar': 'x', 'en': 'y'}, const ['fr']), isEmpty);
    expect(filterLangsDeep(null, const ['fr']), isNull);
  });

  test('a lesson file becomes what get_lesson_bundle returns', () {
    final lesson = filterLesson({
      'id': 7,
      'position': 2,
      'source_lang': 'ar',
      'unit': {
        'ref': 'ch1',
        'number': 1,
        'title': {'fr': 'U', 'ar': 'W'},
      },
      'i18n': {
        'fr': {'title': 'T', 'blocks': const []},
        'ar': {'title': 'A', 'blocks': const []},
      },
      'cards': [
        {
          'id': 1,
          'position': 1,
          'figure': {
            'svg': '<svg/>',
            'caption': {'fr': 'c', 'ar': 'd'},
          },
          'i18n': {
            'fr': {'front': 'f', 'back': 'b'},
            'ar': {'front': 'g', 'back': 'h'},
          },
        },
      ],
      'questions': [
        {
          'id': 9,
          'kind': 'mcq',
          'correct_index': 2,
          'position': 1,
          'figure': null,
          'option_figures': null,
          'i18n': {
            'ar': {'prompt': 'p', 'options': const ['1', '2', '3', '4']},
          },
        },
      ],
      'resources': const [],
    }, const ['fr']);
    expect(lesson['id'], 7);
    expect(lesson['source_lang'], 'ar');
    expect((lesson['unit'] as Map)['title'], {'fr': 'U'});
    expect((lesson['unit'] as Map)['ref'], 'ch1');
    expect((lesson['i18n'] as Map).keys, ['fr']);
    final card = (lesson['cards'] as List).single as Map;
    expect(card['i18n'], {
      'fr': {'front': 'f', 'back': 'b'},
    });
    expect((card['figure'] as Map)['caption'], {'fr': 'c'});
    expect((card['figure'] as Map)['svg'], '<svg/>');
    final question = (lesson['questions'] as List).single as Map;
    expect(question['correct_index'], 2);
    expect(question['i18n'], isEmpty);
    expect(lesson['resources'], isEmpty);
  });

  test('extras: glossary languages nulled, sets untouched, no resources', () {
    final extras = filterExtras({
      'glossary': [
        {
          'id': 1,
          'fr': 'mot',
          'ar': 'k',
          'en': 'word',
          'definition': {'fr': 'd', 'en': 'e'},
          'note': 'n',
        },
      ],
      'sets': [
        {
          'id': 5,
          'title': {'fr': 's', 'ar': 't'},
        },
      ],
    }, const ['fr', 'ar']);
    final g = (extras['glossary'] as List).single as Map;
    expect(g['fr'], 'mot');
    expect(g['ar'], 'k');
    expect(g['en'], isNull);
    expect(g.containsKey('en'), isTrue);
    expect(g['definition'], {'fr': 'd'});
    expect(g['note'], 'n');
    expect(((extras['sets'] as List).single as Map)['title'], {
      'fr': 's',
      'ar': 't',
    });
    expect(extras.containsKey('resources'), isFalse);
  });

  test('practice and exam files', () {
    final items = filterPractice([
      {
        'id': 3,
        'chapter_ref': 'ch1',
        'concepts': const ['a', 'b'],
        'title': {'fr': 't', 'ar': 'u'},
        'statement': {'fr': 's', 'ar': 'v'},
        'figure': null,
        'table': null,
        'parts': [
          {
            'q': {'fr': 'q', 'ar': 'r'},
            'points': 2,
          },
        ],
      },
    ], const ['ar']);
    final item = items.single as Map;
    expect(item['title'], {'ar': 'u'});
    expect(item['concepts'], ['a', 'b']);
    expect(((item['parts'] as List).single as Map)['q'], {'ar': 'r'});
    expect(((item['parts'] as List).single as Map)['points'], 2);

    final exam = filterExam({
      'id': 4,
      'duration_min': 90,
      'title': {'fr': 't', 'ar': 'u'},
      'instructions': {'fr': 'i', 'ar': 'j'},
      'exercises': [
        {
          'statement': {'fr': 'e', 'ar': 'f'},
        },
      ],
    }, const ['fr']);
    expect(exam['duration_min'], 90);
    expect(exam['title'], {'fr': 't'});
    expect(((exam['exercises'] as List).single as Map)['statement'], {
      'fr': 'e',
    });
  });
}
