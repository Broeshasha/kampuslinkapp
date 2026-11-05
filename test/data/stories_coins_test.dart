import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/data/coins/coins_models.dart';
import 'package:kampuslink/data/coins/stories_models.dart';
import 'package:kampuslink/data/sync/sync_results.dart';

void main() {
  test('wallet reads the server answer', () {
    final w = Wallet.fromMap({
      'balance': 120,
      'today_earned': 45,
      'daily_cap': 100,
      'cap_remaining': 55,
      'max_freezes': 2,
      'streak': {'current': 4, 'best': 9, 'freezes': 1, 'protected': true},
      'inventory': [
        {'item_id': 'theme_night', 'kind': 'theme', 'equipped': true},
      ],
    });
    expect(w.balance, 120);
    expect(w.streak, 4);
    expect(w.freezes, 1);
    expect(w.streakProtected, isTrue);
    expect(w.owns('theme_night'), isTrue);
    expect(w.equippedOfKind('theme'), 'theme_night');
    expect(w.owns('theme_forest'), isFalse);
  });

  test('stories: parsing, question detection, grouping', () {
    final data = StoriesData.fromMap({
      'day': '2026-11-05',
      'balance': 10,
      'templates': {
        'question': {
          'name': {'en': 'Question of the day'},
          'colors': {'bg': '#3B3FD9', 'fg': '#FFFFFF', 'accent': '#FFD43B'},
          'duration_ms': 8000,
          'interactive': true,
        },
      },
      'stories': [
        {
          'key': 'qotd:2026-11-05',
          'source': 'auto',
          'template': 'question',
          'payload': {
            'correct_index': 2,
            'lesson_id': 7,
            'module': {'id': 840},
            'i18n': {
              'fr': {
                'prompt': 'Q',
                'options': ['a', 'b', 'c'],
                'explanation': 'x',
              },
            },
          },
          'seen': false,
          'answered': null,
        },
        {
          'key': 'plan:2026-11-05',
          'source': 'auto',
          'template': 'plan',
          'payload': {'due_cards': 3},
          'seen': true,
        },
        {
          'key': 'ed:abc',
          'source': 'editorial',
          'template': 'fun',
          'payload': {'title': 'Hi'},
          'answered': {'choice': 1, 'is_correct': false},
        },
      ],
    });
    expect(data.stories.length, 3);
    final q = data.stories.first;
    expect(q.isQuestion, isTrue);
    expect(q.correctIndex, 2);
    expect(q.moduleId, 840);
    expect(q.lessonId, 7);
    expect(data.templateOf('question').interactive, isTrue);
    expect(data.templateOf('question').durationMs, 8000);
    // unknown type: a safe default, never an error
    expect(data.templateOf('nope').durationMs, 7000);
    final groups = groupStories(data.stories);
    expect(groups.length, 2);
    expect(groups.first.isToday, isTrue);
    expect(groups.first.stories.length, 2);
    expect(groups.first.allSeen, isFalse);
    expect(groups.last.lead.answeredChoice, 1);
    expect(groups.last.lead.answeredCorrect, isFalse);
  });

  test('a story without options text is not a question', () {
    final s = Story.fromMap({
      'key': 'ed:x',
      'template': 'fun',
      'payload': {'title': 'Hi'},
    });
    expect(s.isQuestion, isFalse);
  });

  test('colours: only #RRGGBB', () {
    expect(parseHexColor('#3B3FD9')?.toARGB32(), 0xFF3B3FD9);
    expect(parseHexColor('red'), isNull);
    expect(parseHexColor(null), isNull);
  });

  test('sync results bus answers the op that was asked for', () async {
    final bus = SyncResultsBus();
    final waiting = bus.waitFor('op-1', timeout: const Duration(seconds: 2));
    bus.publish([
      {'op_id': 'other', 'status': 'applied', 'coins': 0},
      {'op_id': 'op-1', 'status': 'applied', 'coins': 10},
    ]);
    final r = await waiting;
    expect(r?['coins'], 10);
    final none = await bus.waitFor(
      'op-2',
      timeout: const Duration(milliseconds: 50),
    );
    expect(none, isNull);
    bus.dispose();
  });
}
