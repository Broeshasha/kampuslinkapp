import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/core/l10n/locale_controller.dart';
import 'package:kampuslink/data/db/app_database.dart';
import 'package:kampuslink/data/profile/study_level.dart';
import 'package:kampuslink/data/providers.dart';
import 'package:kampuslink/data/reminders/notification_templates.dart';
import 'package:kampuslink/data/reminders/reminder_controller.dart';
import 'package:kampuslink/data/reminders/reminder_notifier.dart';
import 'package:kampuslink/data/reminders/reminder_state.dart';
import 'package:kampuslink/data/reminders/reminder_texts.dart';
import 'package:shared_preferences/shared_preferences.dart';

NotificationTemplate _t(
  String id,
  String kind,
  String body, {
  String lang = 'en',
  String title = 'KampusLink',
  double weight = 1,
}) => NotificationTemplate(
  id: id,
  kind: kind,
  lang: lang,
  title: title,
  body: body,
  weight: weight,
);

const _all = TemplateValues(
  name: 'Amine',
  count: 12,
  module: 'Ondes et vibrations',
  streak: 4,
  minutes: 10,
);

class _Phone implements ReminderNotifier {
  List<ReminderSlot> scheduled = [];

  @override
  Future<void> init(void Function(String?, String?) onTap) async {}

  @override
  Future<bool> enabled() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> cancelAll() async => scheduled = [];

  @override
  Future<void> schedule(List<ReminderSlot> slots, ReminderTexts texts) async =>
      scheduled = [...slots];

  @override
  Future<String?> launchPayload() async => null;
}

void main() {
  test('every placeholder is filled from local values', () {
    expect(
      fillTemplate(
        '{name}, {count} cards in {module}, streak {streak}, {minutes} min',
        _all,
      ),
      'Amine, 12 cards in Ondes et vibrations, streak 4, 10 min',
    );
  });

  test('a missing value (or unknown placeholder) skips the template', () {
    expect(fillTemplate('Hi {name}', const TemplateValues()), isNull);
    expect(fillTemplate('{count} cards', const TemplateValues()), isNull);
    expect(fillTemplate('{weather} today', _all), isNull);
    expect(
      fillTemplate('No placeholder', const TemplateValues()),
      'No placeholder',
    );
  });

  test('Arabic: the French module name stays left-to-right', () {
    final s = fillTemplate('\u0641\u064a {module}', _all, lang: 'ar')!;
    expect(s, contains('\u2066Ondes et vibrations\u2069'));
  });

  test('fitting kinds follow the local data', () {
    expect(
      fittingKinds(
        secondChance: false,
        dueCount: 3,
        unreadLesson: true,
        streak: 2,
        examSeason: true,
      ),
      ['due_cards', 'new_lesson', 'streak', 'exam_season', 'generic'],
    );
    expect(
      fittingKinds(
        secondChance: false,
        dueCount: 0,
        unreadLesson: false,
        streak: 1,
        examSeason: false,
      ),
      ['generic'],
    );
    expect(
      fittingKinds(
        secondChance: true,
        dueCount: 9,
        unreadLesson: true,
        streak: 9,
        examSeason: true,
      ),
      ['second_chance'],
    );
  });

  test('weighted pick, never the same body twice, fallback to French', () {
    final templates = [
      _t('1', 'generic', 'Hello {name}'),
      _t('2', 'generic', 'Go {name}', weight: 0),
      _t('3', 'due_cards', '{count} cards'),
      _t('4', 'generic', 'Bonjour {name}', lang: 'fr'),
    ];
    final random = math.Random(1);
    for (var i = 0; i < 20; i++) {
      final p = pickTemplate(
        templates: templates,
        lang: 'en',
        kinds: const ['due_cards', 'generic'],
        valuesFor: (_) => _all,
        random: random,
        lastBody: 'Hello Amine',
      )!;
      expect(p.body, '12 cards'); // weight 0 never; last body never
    }
    final fr = pickTemplate(
      templates: templates,
      lang: 'ar',
      kinds: const ['generic'],
      valuesFor: (_) => _all,
      random: random,
    )!;
    expect(fr.body, 'Bonjour Amine');
    expect(
      pickTemplate(
        templates: templates,
        lang: 'en',
        kinds: const ['streak'],
        valuesFor: (_) => _all,
        random: random,
      ),
      isNull,
    );
  });

  test(
    'scheduling: templates with the first name, no body twice in a row',
    () async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final templates = [
        _t('1', 'generic', 'Ready, {name}?', title: '{name}'),
        _t('2', 'generic', '{minutes} minutes, {name}?', title: '{name}'),
      ];
      SharedPreferences.setMockInitialValues({
        'ui_language': 'en',
        reminderStateKey: jsonEncode(
          const ReminderState(enabled: true).toJson(),
        ),
        reminderTemplatesKey: jsonEncode([
          for (final t in templates) t.toJson(),
        ]),
        'server_stats': jsonEncode({'first_name': 'Amine'}),
      });
      final prefs = await SharedPreferences.getInstance();
      final phone = _Phone();
      final c = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          appDatabaseProvider.overrideWithValue(db),
          reminderNotifierProvider.overrideWithValue(phone),
          reminderClockProvider.overrideWithValue(
            () => algiersToUtc(2026, 11, 2, 10, 0),
          ),
          currentSemesterProvider.overrideWithValue(null),
        ],
      );
      addTearDown(c.dispose);
      await c.read(reminderControllerProvider.notifier).refreshPlan();
      expect(phone.scheduled, hasLength(3));
      expect(phone.scheduled.first.title, 'Amine');
      for (var i = 1; i < phone.scheduled.length; i++) {
        expect(phone.scheduled[i].body, isNot(phone.scheduled[i - 1].body));
      }
      expect(
        phone.scheduled.map((s) => s.body),
        contains('10 minutes, Amine?'),
      );
    },
  );
}
