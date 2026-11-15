import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show PlatformDispatcher;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/errors/result.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/logging/logger.dart';
import '../catalog/catalog.dart';
import '../profile/waitlist_check.dart' show waitlistPayload;
import '../db/app_database.dart';
import '../learning/feed_repository.dart';
import '../profile/study_level.dart';
import '../providers.dart';
import 'notification_templates.dart';
import 'reminder_api.dart';
import 'reminder_notifier.dart';
import 'reminder_state.dart';
import 'reminder_texts.dart';
import '../../render/latex_plain.dart' show latexToPlain, mayContainMath;

/// Notifications cannot draw formulas: readable plain text instead.
String _plain(String s) => mayContainMath(s) ? latexToPlain(s) : s;

const reminderStateKey = 'reminder_state_v1';
const reminderPendingKey = 'reminder_settings_pending_v1';
const reminderPlanKey = 'reminder_plan_v1';
const reminderFiredKey = 'reminder_fired_v1';
const reminderAppOpenKey = 'reminder_app_open_day_v1';
const reminderTemplatesKey = 'notif_templates_v1';
const reminderPlanBodiesKey = 'reminder_plan_bodies_v1';

/// B12: signature of the plan on the phone (skip identical re-plans).
const reminderPlanSigKey = 'reminder_plan_sig_v1';

/// Minutes promised in the reminder ({minutes}).
const reminderSessionMinutes = 10;

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
      if (payload != null && payload != waitlistPayload) {
        await respond(payload, ReminderResponse.started, plan: false);
        ref.read(reminderLaunchProvider.notifier).bump();
      }
    });
    await appOpened();
    await refreshPlan();
  }

  ({Duration after, Duration length}) _secondChanceConfig() {
    var after = defaultSecondChanceAfter;
    var length = defaultSecondChanceFor;
    try {
      final c = ref
          .read(catalogValueProvider)
          ?.config['reminder_second_chance'];
      if (c is Map) {
        final a = c['after_days'];
        final f = c['for_days'];
        if (a is num && a > 0) {
          after = Duration(days: a.toInt());
        }
        if (f is num && f > 0) {
          length = Duration(days: f.toInt());
        }
      }
    } catch (_) {
      // No catalog yet: the defaults (7 days, 2 days).
    }
    return (after: after, length: length);
  }

  /// Once per day: sync op 'app_open' (the server decides the second
  /// chance) and the same rule on the phone, so it also works offline.
  Future<void> appOpened() async {
    final now = _now();
    final today = dayKey(now);
    if (_prefs.getString(reminderAppOpenKey) == today) {
      return;
    }
    await _prefs.setString(reminderAppOpenKey, today);
    await guard(
      () => ref.read(outboxRepositoryProvider).enqueue('app_open', {
        'at': now.toUtc().toIso8601String(),
      }),
    );
    final current = state;
    if (current != null) {
      final config = _secondChanceConfig();
      final next = current.appOpened(
        now,
        after: config.after,
        length: config.length,
      );
      if (next != current) {
        await _save(next);
        appLog.info('reminders: second chance until ${next.secondChanceUntil}');
      }
    }
  }

  void _onTap(String? payload, String? action) {
    if (payload == waitlistPayload) {
      return; // not a study reminder
    }
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

  Map<String, dynamic> _stats() {
    try {
      final v = jsonDecode(_prefs.getString('server_stats') ?? '');
      return v is Map ? v.cast<String, dynamic>() : const {};
    } on FormatException {
      return const {};
    }
  }

  /// A lesson of a current-semester module never opened: its module name.
  Future<String?> _unreadLessonModule() async {
    final db = ref.read(appDatabaseProvider);
    final semester = _semester();
    final query =
        db.select(db.lessons).join([
            innerJoin(db.modules, db.modules.id.equalsExp(db.lessons.moduleId)),
            leftOuterJoin(
              db.readingPositions,
              db.readingPositions.lessonId.equalsExp(db.lessons.id),
            ),
            leftOuterJoin(
              db.lessonProgress,
              db.lessonProgress.lessonId.equalsExp(db.lessons.id),
            ),
          ])
          ..where(
            db.readingPositions.lessonId.isNull() &
                db.lessonProgress.lessonId.isNull(),
          )
          ..orderBy([
            OrderingTerm.asc(db.lessons.moduleId),
            OrderingTerm.asc(db.lessons.position),
          ]);
    for (final r in await query.get()) {
      final m = r.readTable(db.modules);
      if (inSemester(m, semester)) {
        return m.name;
      }
    }
    return null;
  }

  bool _examSeason(DateTime at) {
    try {
      final windows = ref
          .read(catalogValueProvider)
          ?.config['exam_season_windows'];
      return windows is List && semesterBannerDue(algiersWall(at), windows);
    } catch (_) {
      return false;
    }
  }

  /// The body of the newest reminder that already fired (never repeat it).
  String? _lastFiredBody(DateTime now) {
    String? body;
    DateTime? newest;
    for (final line
        in _prefs.getStringList(reminderPlanBodiesKey) ?? const <String>[]) {
      final cut = line.indexOf('|');
      final at = DateTime.tryParse(cut < 0 ? '' : line.substring(0, cut));
      if (at == null || at.isAfter(now)) {
        continue;
      }
      if (newest == null || at.isAfter(newest)) {
        newest = at;
        body = line.substring(cut + 1);
      }
    }
    return body;
  }

  /// Recomputes and reschedules the upcoming reminders (app start, app to
  /// background, settings change, a response). Never throws.
  Future<void> refreshPlan() async {
    await guard(() async {
      await _drainInbox();
      await _processFired();
      final current = state;
      if (current == null || !current.active || !await _notifier.enabled()) {
        await _notifier.cancelAll();
        await _prefs.setStringList(reminderPlanKey, const []);
        await _prefs.remove(reminderPlanSigKey);
        return;
      }
      final now = _now();
      // One reminder a day at most (2 allowed for bac); bac: quiet 22-07.
      final plan = planReminders(
        current,
        now,
        max: reminderMaxSlots,
        quietHours: ref.read(isBacProvider),
      );
      final studied = await _studiedToday();
      final today = algiersWall(now);
      // B12 (A-15): same times, language and situation as the plan already
      // on the phone -> nothing to cancel or schedule (refreshed at least
      // every 6 hours so the counts in the texts stay fresh).
      final signature = [
        for (final at in plan) at.toIso8601String(),
        _language(),
        '${current.inSecondChance}',
        '$studied',
        '${today.year}-${today.month}-${today.day}/${today.hour ~/ 6}',
      ].join('|');
      if (_prefs.getString(reminderPlanSigKey) == signature) return;
      await _notifier.cancelAll();
      bool keepGoing(int i) {
        final d = algiersWall(plan[i]);
        return studied &&
            d.year == today.year &&
            d.month == today.month &&
            d.day == today.day;
      }

      final language = _language();
      final texts = reminderTexts(language);
      final templates = decodeTemplates(_prefs.getString(reminderTemplatesKey));
      final stats = _stats();
      final name = '${stats['first_name'] ?? stats['username'] ?? ''}'.trim();
      final streakRaw = stats['current_streak'];
      final streak = streakRaw is num ? streakRaw.toInt() : 0;
      final unread = await _unreadLessonModule();
      final random = math.Random(now.microsecondsSinceEpoch);
      var lastBody = _lastFiredBody(now);
      final slots = <ReminderSlot>[];
      for (var i = 0; i < plan.length; i++) {
        final due = await _due(plan[i]);
        final values = TemplateValues(
          name: name.isEmpty ? null : name,
          count: due.count > 0 ? due.count : null,
          module: due.module,
          streak: streak >= 2 ? streak : null,
          minutes: reminderSessionMinutes,
        );
        final picked = pickTemplate(
          templates: templates,
          lang: language,
          kinds: fittingKinds(
            secondChance: current.inSecondChance,
            dueCount: due.count,
            unreadLesson: unread != null,
            streak: streak,
            examSeason: _examSeason(plan[i]),
            studiedToday: keepGoing(i),
          ),
          valuesFor: (kind) =>
              kind == 'new_lesson' ? values.withModule(unread) : values,
          random: random,
          lastBody: lastBody,
        );
        final body =
            picked?.body ??
            (current.inSecondChance
                ? texts.secondChance
                : keepGoing(i) && texts.keepGoing.isNotEmpty
                ? texts.keepGoing
                : texts.body(due.count, due.module));
        lastBody = body;
        slots.add(
          ReminderSlot(
            id: reminderFirstId + i,
            at: plan[i],
            title: _plain(picked?.title ?? reminderTitle),
            body: _plain(body),
            payload: plan[i].toIso8601String(),
          ),
        );
      }
      await _notifier.schedule(slots, texts);
      await _prefs.setStringList(reminderPlanKey, [
        for (final at in plan) at.toIso8601String(),
      ]);
      await _prefs.setStringList(reminderPlanBodiesKey, [
        for (final s in slots) '${s.at.toIso8601String()}|${s.body}',
      ]);
      await _prefs.setString(reminderPlanSigKey, signature);
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
    }
    // B04: templates + server settings at most once a day (sending unsent
    // settings above stays immediate).
    final readAt = DateTime.tryParse(_prefs.getString(_serverReadKey) ?? '');
    final daily =
        readAt == null ||
        DateTime.now().difference(readAt) >= const Duration(hours: 24);
    if (!daily) {
      await refreshPlan();
      return;
    }
    await _refreshTemplates(api);
    final stillPending =
        current != null && (_prefs.getBool(reminderPendingKey) ?? false);
    if (!stillPending && !await _unsentReminderOps()) {
      // The server applied every response we sent: its copy is the truth
      // (new phone, second chance decided by the server, other device).
      final r = await guard(api.get);
      if (r case Ok(:final value) when value.isNotEmpty) {
        final server = ReminderState.fromJson(value);
        if (server != current) {
          await _save(server);
          appLog.info('reminders: settings read from the server');
        }
      }
      if (r is Ok) {
        await _prefs.setString(
          _serverReadKey,
          DateTime.now().toIso8601String(),
        );
      }
    }
    await refreshPlan();
  }

  /// get_notification_templates(), cached on the phone (refreshed after
  /// each sync, with the catalog).
  Future<void> _refreshTemplates(ReminderApi api) async {
    final r = await guard(api.templates);
    if (r case Ok(:final value) when value.isNotEmpty) {
      await _prefs.setString(reminderTemplatesKey, jsonEncode(value));
    }
  }

  Future<bool> _unsentReminderOps() async {
    final db = ref.read(appDatabaseProvider);
    final rows =
        await (db.select(db.outbox)..where(
              (t) => t.kind.isIn(const ['reminder_response', 'app_open']),
            ))
            .get();
    return rows.isNotEmpty;
  }
}

const _serverReadKey = 'reminders_server_read_at';

final reminderControllerProvider =
    NotifierProvider<ReminderController, ReminderState?>(
      ReminderController.new,
    );
