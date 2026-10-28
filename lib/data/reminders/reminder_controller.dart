import 'dart:async';
import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/errors/result.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/logging/logger.dart';
import '../db/app_database.dart';
import '../learning/feed_repository.dart';
import '../profile/study_level.dart';
import '../providers.dart';
import 'reminder_api.dart';
import 'reminder_notifier.dart';
import 'reminder_state.dart';
import 'reminder_texts.dart';

const reminderStateKey = 'reminder_state_v1';
const reminderPendingKey = 'reminder_settings_pending_v1';
const reminderPlanKey = 'reminder_plan_v1';
const reminderFiredKey = 'reminder_fired_v1';

final reminderNotifierProvider = Provider<ReminderNotifier>(
  (ref) => LocalReminderNotifier(),
);

/// Overridable clock (tests).
final reminderClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Goes up by one each time the student taps a reminder (or Start): the
/// app opens the 10-minute review session.
class ReminderLaunches extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final reminderLaunchProvider = NotifierProvider<ReminderLaunches, int>(
  ReminderLaunches.new,
);

/// Study reminders on this phone: settings (state), the back-off, the plan
/// of upcoming notifications and the responses (sync op reminder_response).
/// null = not known yet on this phone (new phone: read from the server).
class ReminderController extends Notifier<ReminderState?> {
  bool _started = false;

  @override
  ReminderState? build() {
    final raw = ref.read(sharedPrefsProvider).getString(reminderStateKey);
    return _decodeState(raw);
  }

  SharedPreferences get _prefs => ref.read(sharedPrefsProvider);
  DateTime _now() => ref.read(reminderClockProvider)();
  ReminderNotifier get _notifier => ref.read(reminderNotifierProvider);

  static ReminderState? _decodeState(String? raw) {
    if (raw == null) {
      return null;
    }
    try {
      final v = jsonDecode(raw);
      return v is Map
          ? ReminderState.fromJson(v.cast<String, dynamic>())
          : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> _save(ReminderState next) async {
    state = next;
    await _prefs.setString(reminderStateKey, jsonEncode(next.toJson()));
  }

  /// Once per app start (after the first frame): plugin, the tap that may
  /// have opened the app, then the plan.
  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    await guard(() async {
      await _notifier.init(_onTap);
      final payload = await _notifier.launchPayload();
      if (payload != null) {
        await respond(payload, ReminderResponse.started, plan: false);
        ref.read(reminderLaunchProvider.notifier).bump();
      }
    });
    await refreshPlan();
  }

  void _onTap(String? payload, String? action) {
    final response = action == reminderActionNotNow
        ? ReminderResponse.notNow
        : ReminderResponse.started;
    unawaited(respond(payload, response));
    if (response == ReminderResponse.started) {
      ref.read(reminderLaunchProvider.notifier).bump();
    }
  }

  /// One response to the reminder of [payload] (its time, ISO).
  Future<void> respond(
    String? payload,
    ReminderResponse response, {
    bool plan = true,
  }) async {
    final current = state;
    if (current == null) {
      return;
    }
    final now = _now();
    final at = DateTime.tryParse(payload ?? '')?.toUtc() ?? now.toUtc();
    final fired = _readFired();
    if (fired.any((f) => f.at == at && f.answered)) {
      return; // already counted
    }
    fired.removeWhere((f) => f.at == at);
    fired.add((at: at, answered: true));
    await _writeFired(fired);
    // The reminder's own time, like the 'at' sent to the server.
    await _save(current.respond(response, at));
    await _queue(response, at);
    if (plan) {
      await refreshPlan();
    }
  }

  Future<void> _queue(ReminderResponse response, DateTime at) async {
    await guard(
      () => ref.read(outboxRepositoryProvider).enqueue('reminder_response', {
        'response': response.wire,
        'at': at.toUtc().toIso8601String(),
      }),
    );
  }

  List<({DateTime at, bool answered})> _readFired() {
    final raw = _prefs.getStringList(reminderFiredKey) ?? const <String>[];
    final out = <({DateTime at, bool answered})>[];
    for (final line in raw) {
      final parts = line.split('|');
      final at = DateTime.tryParse(parts.first)?.toUtc();
      if (at != null) {
        out.add((at: at, answered: parts.length > 1 && parts[1] == '1'));
      }
    }
    return out;
  }

  Future<void> _writeFired(List<({DateTime at, bool answered})> fired) async {
    fired.sort((a, b) => a.at.compareTo(b.at));
    final keep = fired.length > 20 ? fired.sublist(fired.length - 20) : fired;
    await _prefs.setStringList(reminderFiredKey, [
      for (final f in keep) '${f.at.toIso8601String()}|${f.answered ? 1 : 0}',
    ]);
  }

  /// "Not now" taps made while the app was closed.
  Future<void> _drainInbox() async {
    await _prefs.reload();
    final inbox = _prefs.getStringList(reminderInboxKey) ?? const <String>[];
    if (inbox.isEmpty) {
      return;
    }
    await _prefs.remove(reminderInboxKey);
    for (final line in inbox) {
      await respond(
        line.split('|').first,
        ReminderResponse.notNow,
        plan: false,
      );
    }
  }

  /// Planned reminders whose time passed have fired. One left without an
  /// answer when a newer one fired = ignored.
  Future<void> _processFired() async {
    final now = _now();
    final planned = [
      for (final s in _prefs.getStringList(reminderPlanKey) ?? const <String>[])
        ?DateTime.tryParse(s)?.toUtc(),
    ];
    final fired = _readFired();
    for (final at in planned) {
      if (!at.isAfter(now) && !fired.any((f) => f.at == at)) {
        fired.add((at: at, answered: false));
      }
    }
    fired.sort((a, b) => a.at.compareTo(b.at));
    for (var i = 0; i < fired.length - 1; i++) {
      final f = fired[i];
      final current = state;
      if (f.answered || current == null) {
        continue;
      }
      fired[i] = (at: f.at, answered: true);
      await _save(current.respond(ReminderResponse.ignored, f.at));
      await _queue(ReminderResponse.ignored, f.at);
    }
    await _writeFired(fired);
  }

  Future<bool> _studiedToday() async {
    final db = ref.read(appDatabaseProvider);
    final row = await (db.select(
      db.studyDays,
    )..where((t) => t.day.equals(dayKey(_now())))).getSingleOrNull();
    return (row?.seconds ?? 0) >= 60;
  }

  int? _semester() {
    try {
      return ref.read(currentSemesterProvider);
    } catch (_) {
      return null;
    }
  }

  /// Cards due by [at] in current-semester modules: the busiest module.
  Future<({int count, String? module})> _due(DateTime at) async {
    final db = ref.read(appDatabaseProvider);
    final semester = _semester();
    final rows =
        await (db.select(
          db.cardProgress,
        )..where((t) => t.dueAt.isSmallerOrEqualValue(at))).join([
          innerJoin(db.cards, db.cards.id.equalsExp(db.cardProgress.cardId)),
          innerJoin(db.modules, db.modules.id.equalsExp(db.cards.moduleId)),
        ]).get();
    final counts = <int, int>{};
    final modules = <int, ModuleRow>{};
    for (final r in rows) {
      final m = r.readTable(db.modules);
      if (!inSemester(m, semester)) {
        continue;
      }
      counts[m.id] = (counts[m.id] ?? 0) + 1;
      modules[m.id] = m;
    }
    if (counts.isEmpty) {
      return (count: 0, module: null);
    }
    final best = counts.entries.reduce((a, b) => b.value > a.value ? b : a);
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    return (count: total, module: modules[best.key]?.name);
  }

  String _language() {
    final chosen = _prefs.getString('ui_language');
    if (chosen != null && supportedLanguageCodes.contains(chosen)) {
      return chosen;
    }
    try {
      final phone = PlatformDispatcher.instance.locale.languageCode;
      return supportedLanguageCodes.contains(phone)
          ? phone
          : fallbackLanguageCode;
    } catch (_) {
      return fallbackLanguageCode;
    }
  }

  /// Recomputes and reschedules the upcoming reminders (app start, app to
  /// background, settings change, a response). Never throws.
  Future<void> refreshPlan() async {
    await guard(() async {
      await _drainInbox();
      await _processFired();
      final current = state;
      await _notifier.cancelAll();
      if (current == null || !current.active || !await _notifier.enabled()) {
        await _prefs.setStringList(reminderPlanKey, const []);
        return;
      }
      final now = _now();
      final plan = planReminders(
        current,
        now,
        studiedToday: await _studiedToday(),
        max: reminderMaxSlots,
      );
      final texts = reminderTexts(_language());
      final slots = <ReminderSlot>[];
      for (var i = 0; i < plan.length; i++) {
        final due = await _due(plan[i]);
        slots.add(
          ReminderSlot(
            id: reminderFirstId + i,
            at: plan[i],
            body: texts.body(due.count, due.module),
            payload: plan[i].toIso8601String(),
          ),
        );
      }
      await _notifier.schedule(slots, texts);
      await _prefs.setStringList(reminderPlanKey, [
        for (final at in plan) at.toIso8601String(),
      ]);
    });
  }

  /// Onboarding / Profile: on/off, time, days. Saved on the phone at once,
  /// sent with set_reminder_settings (queued while offline).
  Future<void> updateSettings({
    required bool enabled,
    String? time,
    List<int>? days,
  }) async {
    final base = state ?? const ReminderState();
    final next = enabled
        ? base.turnedOn(time: time, days: days)
        : base.copyWith(
            enabled: false,
            studyTime: time == null ? null : normalizeTime(time),
            studyDays: days == null ? null : normalizeDays(days),
          );
    await _save(next);
    await _prefs.setBool(reminderPendingKey, true);
    unawaited(syncWithServer());
    await refreshPlan();
  }

  /// Asks Android 13+ for the notification permission (no crash if denied).
  Future<bool> requestPermission() async {
    final result = await guard(() async {
      await _notifier.init(_onTap);
      return _notifier.requestPermission();
    });
    final granted = switch (result) {
      Ok(:final value) => value,
      Err() => false,
    };
    await refreshPlan();
    return granted;
  }

  Future<bool> permissionGranted() async {
    final result = await guard(() async {
      await _notifier.init(_onTap);
      return _notifier.enabled();
    });
    return switch (result) {
      Ok(:final value) => value,
      Err() => false,
    };
  }

  /// Sends unsent settings; on a new phone (nothing saved) reads them.
  Future<void> syncWithServer() async {
    final api = ref.read(reminderApiProvider);
    if (api == null) {
      return;
    }
    final current = state;
    if (current != null && (_prefs.getBool(reminderPendingKey) ?? false)) {
      final r = await guard(
        () => api.set(
          enabled: current.enabled,
          time: current.studyTime,
          days: current.studyDays,
        ),
      );
      if (r case Ok(:final value)) {
        await _prefs.remove(reminderPendingKey);
        if (value.isNotEmpty) {
          await _save(ReminderState.fromJson(value));
        }
      }
    } else if (current == null) {
      final r = await guard(api.get);
      if (r case Ok(:final value) when value.isNotEmpty) {
        await _save(ReminderState.fromJson(value));
        appLog.info('reminders: settings restored from the server');
      }
    }
    await refreshPlan();
  }
}

final reminderControllerProvider =
    NotifierProvider<ReminderController, ReminderState?>(
      ReminderController.new,
    );
