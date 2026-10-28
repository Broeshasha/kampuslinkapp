import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/core/l10n/locale_controller.dart';
import 'package:kampuslink/data/db/app_database.dart';
import 'package:kampuslink/data/profile/study_level.dart';
import 'package:kampuslink/data/providers.dart';
import 'package:kampuslink/data/reminders/reminder_controller.dart';
import 'package:kampuslink/data/reminders/reminder_notifier.dart';
import 'package:kampuslink/data/reminders/reminder_state.dart';
import 'package:kampuslink/data/reminders/reminder_texts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeNotifier implements ReminderNotifier {
  bool allowed = true;
  List<ReminderSlot> scheduled = [];

  @override
  Future<void> init(void Function(String?, String?) onTap) async {}

  @override
  Future<bool> enabled() async => allowed;

  @override
  Future<bool> requestPermission() async => allowed;

  @override
  Future<void> cancelAll() async => scheduled = [];

  @override
  Future<void> schedule(List<ReminderSlot> slots, ReminderTexts texts) async =>
      scheduled = [...slots];

  @override
  Future<String?> launchPayload() async => null;
}

const _on = ReminderState(enabled: true);
const _nn = ReminderResponse.notNow;
const _ig = ReminderResponse.ignored;
const _st = ReminderResponse.started;

/// Monday 2 Nov 2026, [h]:[m] Algiers time.
DateTime _mon(int h, [int m = 0]) => algiersToUtc(2026, 11, 2, h, m);

void main() {
  final t = _mon(19);
  final t2 = t.add(const Duration(days: 1));

  group('back-off (same 8 cases as the server)', () {
    test('1. one not now: still on, 1 decline', () {
      final s = _on.respond(_nn, t);
      expect(s.declinesInRow, 1);
      expect(s.active, isTrue);
      expect(s.pausedUntil, isNull);
    });

    test('2. two declines in a row (not now + ignored): pause 3 days', () {
      final s = _on.respond(_nn, t).respond(_ig, t2);
      expect(s.pausedUntil, t2.add(reminderPause));
      expect(s.afterPause, isTrue);
      expect(s.declinesInRow, 0);
      expect(s.allowsAt(t2.add(const Duration(days: 2))), isFalse);
      expect(s.allowsAt(t2.add(reminderPause)), isTrue);
    });

    test('3. two ignored in a row also pause', () {
      final s = _on.respond(_ig, t).respond(_ig, t2);
      expect(s.afterPause, isTrue);
      expect(s.pausedUntil, isNotNull);
    });

    test('4. started resets the count', () {
      final s = _on.respond(_nn, t).respond(_st, t2);
      expect(s.declinesInRow, 0);
      expect(s.respond(_nn, t2).pausedUntil, isNull);
    });

    test('5. after the pause, one more decline: stopped', () {
      final paused = _on.respond(_nn, t).respond(_nn, t2);
      final s = paused.respond(_ig, t2.add(const Duration(days: 4)));
      expect(s.stopped, isTrue);
      expect(s.active, isFalse);
    });

    test('6. after the pause, started: back to normal', () {
      final paused = _on.respond(_nn, t).respond(_nn, t2);
      final s = paused.respond(_st, t2.add(const Duration(days: 4)));
      expect(s.afterPause, isFalse);
      expect(s.pausedUntil, isNull);
      expect(s.respond(_nn, t2).stopped, isFalse);
    });

    test('7. stopped: no reminders until turned on again (clears all)', () {
      final stopped = _on
          .respond(_nn, t)
          .respond(_nn, t2)
          .respond(_nn, t2.add(const Duration(days: 4)));
      expect(planReminders(stopped, t), isEmpty);
      expect(stopped.respond(_nn, t), stopped);
      final again = stopped.turnedOn();
      expect(again.active, isTrue);
      expect(again.declinesInRow, 0);
      expect(again.pausedUntil, isNull);
      expect(again.afterPause, isFalse);
    });

    test('8. server json round trip keeps every field', () {
      final s = _on.respond(_nn, t).respond(_nn, t2);
      final back = ReminderState.fromJson(
        jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>,
      );
      expect(back, s);
      expect(normalizeTime('7:5:00'), '07:05');
      expect(normalizeTime('25:00'), defaultStudyTime);
    });
  });

  group('plan', () {
    const monWed = ReminderState(
      enabled: true,
      studyTime: '07:30',
      studyDays: [1, 3],
    );

    test('chosen days and time; 2 ignored -> pause -> 1 more -> stop', () {
      final plan = planReminders(monWed, _mon(6));
      expect(plan, [
        _mon(7, 30),
        algiersToUtc(2026, 11, 4, 7, 30),
        algiersToUtc(2026, 11, 9, 7, 30),
      ]);
    });

    test('studied today, or the time already passed: not today', () {
      expect(
        planReminders(monWed, _mon(6), studiedToday: true).first,
        algiersToUtc(2026, 11, 4, 7, 30),
      );
      expect(
        planReminders(monWed, _mon(8)).first,
        algiersToUtc(2026, 11, 4, 7, 30),
      );
    });

    test('paused: nothing before the end of the pause', () {
      final s = monWed.copyWith(
        pausedUntil: algiersToUtc(2026, 11, 5, 0, 0),
        afterPause: true,
      );
      final plan = planReminders(s, _mon(6));
      expect(plan, [algiersToUtc(2026, 11, 9, 7, 30)]);
    });

    test('turned off: nothing', () {
      expect(planReminders(const ReminderState(), _mon(6)), isEmpty);
    });
  });

  group('controller', () {
    late AppDatabase db;
    late FakeNotifier phone;
    late DateTime clock;

    Future<ProviderContainer> make(Map<String, Object> prefs) async {
      SharedPreferences.setMockInitialValues(prefs);
      final p = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(p),
          appDatabaseProvider.overrideWithValue(db),
          reminderNotifierProvider.overrideWithValue(phone),
          reminderClockProvider.overrideWithValue(() => clock),
          currentSemesterProvider.overrideWithValue(null),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    final saved = jsonEncode(
      const ReminderState(enabled: true, studyTime: '19:00').toJson(),
    );

    setUp(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      db = AppDatabase(NativeDatabase.memory());
      phone = FakeNotifier();
      clock = _mon(10);
    });
    tearDown(() => db.close());

    test('permission denied: nothing scheduled, no crash', () async {
      phone.allowed = false;
      final c = await make({reminderStateKey: saved});
      await c.read(reminderControllerProvider.notifier).refreshPlan();
      expect(phone.scheduled, isEmpty);
    });

    test('allowed: reminders scheduled in the chosen language', () async {
      final c = await make({reminderStateKey: saved, 'ui_language': 'en'});
      await c.read(reminderControllerProvider.notifier).refreshPlan();
      expect(phone.scheduled, hasLength(3));
      expect(phone.scheduled.first.id, reminderFirstId);
      expect(phone.scheduled.first.at, _mon(19));
      expect(phone.scheduled.first.body, 'Time to study \u00b7 10 minutes?');
    });

    test(
      'a reminder left unanswered when the next one fired = ignored',
      () async {
        final c = await make({reminderStateKey: saved});
        final ctrl = c.read(reminderControllerProvider.notifier);
        await ctrl.refreshPlan();
        clock = _mon(19).add(const Duration(days: 1, hours: 1));
        await ctrl.refreshPlan();
        final ops = await db.select(db.outbox).get();
        expect(ops.map((o) => o.kind), ['reminder_response']);
        expect(jsonDecode(ops.single.payloadJson)['response'], 'ignored');
        expect(c.read(reminderControllerProvider)!.declinesInRow, 1);
      },
    );

    test('Not now tapped while the app was closed is counted once', () async {
      final at = _mon(19).toIso8601String();
      final c = await make({
        reminderStateKey: saved,
        reminderInboxKey: ['$at|not_now'],
      });
      final ctrl = c.read(reminderControllerProvider.notifier);
      await ctrl.refreshPlan();
      await ctrl.respond(at, ReminderResponse.notNow);
      final ops = await db.select(db.outbox).get();
      expect(ops, hasLength(1));
      expect(jsonDecode(ops.single.payloadJson)['response'], 'not_now');
    });

    test('settings change is saved and queued for the server', () async {
      final c = await make({});
      await c
          .read(reminderControllerProvider.notifier)
          .updateSettings(enabled: true, time: '8:15', days: [2, 2, 9, 4]);
      final s = c.read(reminderControllerProvider)!;
      expect(s.studyTime, '08:15');
      expect(s.studyDays, [2, 4]);
      expect(c.read(sharedPrefsProvider).getBool(reminderPendingKey), isTrue);
    });
  });
}
