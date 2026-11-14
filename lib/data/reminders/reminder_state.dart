import 'package:flutter/foundation.dart' show immutable, listEquals;

/// What the student did with a reminder (sync op 'reminder_response').
enum ReminderResponse {
  started('started'),
  notNow('not_now'),
  ignored('ignored');

  const ReminderResponse(this.wire);

  final String wire;
}

/// Two declines in a row (not now / ignored) pause reminders this long.
const reminderPause = Duration(days: 3);
const defaultStudyTime = '19:00';
const everyDay = [1, 2, 3, 4, 5, 6, 7];

/// config.reminder_second_chance defaults: after 7 days stopped, 2 days.
const defaultSecondChanceAfter = Duration(days: 7);
const defaultSecondChanceFor = Duration(days: 2);

/// get_reminder_settings() on the phone. The back-off is computed here
/// exactly like the server does, so it works offline:
/// started -> reset; 2 declines in a row -> pause 3 days; after the pause,
/// one more decline -> stopped. A decline whose time is before the end of
/// the pause (late answer) changes nothing. Stopped by the back-off for
/// 7 days + the app opened -> ONE second chance of 2 days; Start = back to
/// normal, 2 declines = stopped for good.
/// [enabled] is the student's own switch (server: not unsubscribed).
@immutable
class ReminderState {
  const ReminderState({
    this.enabled = false,
    this.stopped = false,
    this.studyTime = defaultStudyTime,
    this.studyDays = everyDay,
    this.declinesInRow = 0,
    this.pausedUntil,
    this.afterPause = false,
    this.stoppedAt,
    this.secondChanceUntil,
    this.secondChanceUsed = false,
  });

  factory ReminderState.fromJson(Map<String, dynamic> json) {
    final days = json['study_days'];
    DateTime? time(String key) =>
        DateTime.tryParse('${json[key] ?? ''}')?.toUtc();
    return ReminderState(
      // Server: enabled = not unsubscribed and not stopped. The switch is
      // "not unsubscribed"; stopped is kept apart.
      enabled: json.containsKey('unsubscribed')
          ? json['unsubscribed'] != true
          : json['enabled'] == true,
      stopped: json['stopped'] == true,
      studyTime: normalizeTime('${json['study_time'] ?? ''}'),
      studyDays: days is List
          ? normalizeDays([
              for (final d in days)
                if (d is num) d.toInt() else ?int.tryParse('$d'),
            ])
          : everyDay,
      declinesInRow: json['declines_in_row'] is num
          ? (json['declines_in_row'] as num).toInt()
          : 0,
      pausedUntil: time('paused_until'),
      afterPause: json['after_pause'] == true,
      stoppedAt: time('stopped_at'),
      secondChanceUntil: time('second_chance_until'),
      secondChanceUsed: json['second_chance_used'] == true,
    );
  }

  final bool enabled;
  final bool stopped;

  /// "HH:MM", Algiers time.
  final String studyTime;

  /// ISO days, 1 = Monday ... 7 = Sunday.
  final List<int> studyDays;
  final int declinesInRow;
  final DateTime? pausedUntil;
  final bool afterPause;
  final DateTime? stoppedAt;
  final DateTime? secondChanceUntil;
  final bool secondChanceUsed;

  bool get unsubscribed => !enabled;
  bool get active => enabled && !stopped;
  bool get inSecondChance => secondChanceUntil != null;
  int get hour => int.parse(studyTime.substring(0, 2));
  int get minute => int.parse(studyTime.substring(3, 5));

  /// May a reminder fire at [at]?
  bool allowsAt(DateTime at) {
    final until = pausedUntil;
    final window = secondChanceUntil;
    return active &&
        (until == null || !at.isBefore(until)) &&
        (window == null || at.isBefore(window));
  }

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'unsubscribed': !enabled,
    'stopped': stopped,
    'study_time': studyTime,
    'study_days': studyDays,
    'declines_in_row': declinesInRow,
    'paused_until': pausedUntil?.toUtc().toIso8601String(),
    'after_pause': afterPause,
    'stopped_at': stoppedAt?.toUtc().toIso8601String(),
    'second_chance_until': secondChanceUntil?.toUtc().toIso8601String(),
    'second_chance_used': secondChanceUsed,
  };

  ReminderState copyWith({
    bool? enabled,
    bool? stopped,
    String? studyTime,
    List<int>? studyDays,
    int? declinesInRow,
    DateTime? pausedUntil,
    bool clearPause = false,
    bool? afterPause,
    DateTime? stoppedAt,
    DateTime? secondChanceUntil,
    bool clearSecondChance = false,
    bool? secondChanceUsed,
  }) => ReminderState(
    enabled: enabled ?? this.enabled,
    stopped: stopped ?? this.stopped,
    studyTime: studyTime ?? this.studyTime,
    studyDays: studyDays ?? this.studyDays,
    declinesInRow: declinesInRow ?? this.declinesInRow,
    pausedUntil: clearPause ? null : (pausedUntil ?? this.pausedUntil),
    afterPause: afterPause ?? this.afterPause,
    stoppedAt: stoppedAt ?? this.stoppedAt,
    secondChanceUntil: clearSecondChance
        ? null
        : (secondChanceUntil ?? this.secondChanceUntil),
    secondChanceUsed: secondChanceUsed ?? this.secondChanceUsed,
  );

  /// The back-off state machine (identical to the server).
  ReminderState respond(ReminderResponse response, DateTime at) {
    final when = at.toUtc();
    if (response == ReminderResponse.started) {
      return copyWith(
        declinesInRow: 0,
        clearPause: true,
        afterPause: false,
        clearSecondChance: true,
      );
    }
    if (stopped) {
      return this;
    }
    final until = pausedUntil;
    if (until != null && when.isBefore(until)) {
      return this; // a late answer from before the pause ended
    }
    final declines = declinesInRow + 1;
    if (inSecondChance) {
      if (declines >= 2) {
        return copyWith(
          stopped: true,
          stoppedAt: when,
          declinesInRow: 0,
          clearSecondChance: true,
        );
      }
      return copyWith(declinesInRow: declines);
    }
    if (afterPause) {
      return copyWith(
        stopped: true,
        stoppedAt: when,
        declinesInRow: 0,
        clearPause: true,
        afterPause: false,
      );
    }
    if (declines >= 2) {
      return copyWith(
        declinesInRow: 0,
        pausedUntil: when.add(reminderPause),
        afterPause: true,
      );
    }
    return copyWith(declinesInRow: declines);
  }

  /// Sync op 'app_open' (once a day): the one second chance, if due.
  ReminderState appOpened(
    DateTime at, {
    Duration after = defaultSecondChanceAfter,
    Duration length = defaultSecondChanceFor,
  }) {
    final since = stoppedAt;
    final when = at.toUtc();
    if (!stopped ||
        !enabled ||
        secondChanceUsed ||
        since == null ||
        when.isBefore(since.add(after))) {
      return this;
    }
    return ReminderState(
      enabled: true,
      studyTime: studyTime,
      studyDays: studyDays,
      stoppedAt: stoppedAt,
      secondChanceUntil: when.add(length),
      secondChanceUsed: true,
    );
  }

  /// Turning reminders ON clears the back-off (like the server). The one
  /// second chance stays used.
  ReminderState turnedOn({String? time, List<int>? days}) => ReminderState(
    enabled: true,
    studyTime: time == null ? studyTime : normalizeTime(time),
    studyDays: days == null ? studyDays : normalizeDays(days),
    secondChanceUsed: secondChanceUsed,
  );

  @override
  bool operator ==(Object other) =>
      other is ReminderState &&
      other.enabled == enabled &&
      other.stopped == stopped &&
      other.studyTime == studyTime &&
      listEquals(other.studyDays, studyDays) &&
      other.declinesInRow == declinesInRow &&
      other.pausedUntil == pausedUntil &&
      other.afterPause == afterPause &&
      other.stoppedAt == stoppedAt &&
      other.secondChanceUntil == secondChanceUntil &&
      other.secondChanceUsed == secondChanceUsed;

  @override
  int get hashCode => Object.hash(
    enabled,
    stopped,
    studyTime,
    Object.hashAll(studyDays),
    declinesInRow,
    pausedUntil,
    afterPause,
    stoppedAt,
    secondChanceUntil,
    secondChanceUsed,
  );
}

/// "7:5", "07:05:00" -> "07:05"; anything unreadable -> 19:00.
String normalizeTime(String raw) {
  final parts = raw.split(':');
  if (parts.length < 2) {
    return defaultStudyTime;
  }
  final h = int.tryParse(parts[0].trim());
  final m = int.tryParse(parts[1].trim());
  if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
    return defaultStudyTime;
  }
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

List<int> normalizeDays(List<int> days) => ({
  for (final d in days)
    if (d >= 1 && d <= 7) d,
}.toList()..sort());

/// Algeria is UTC+1 all year (no summer time): wall clock <-> instant.
DateTime algiersToUtc(int year, int month, int day, int hour, int minute) =>
    DateTime.utc(
      year,
      month,
      day,
      hour,
      minute,
    ).subtract(const Duration(hours: 1));

/// The Algiers wall clock of [t] (read the fields, ignore isUtc).
DateTime algiersWall(DateTime t) => t.toUtc().add(const Duration(hours: 1));

/// The next reminder times (UTC), assuming each one is IGNORED, so the
/// phone stops by itself (pause, then stopped) even if the app is never
/// opened. Not now = ignored for the back-off, so the plan stays right
/// after a Not now; only Start (which opens the app) changes it.
///
/// Reminders fire on the chosen days at the chosen time even when the
/// student already studied that day (founder decision, Nov 2026); only
/// off, paused, stopped, the second-chance window and the Android
/// permission stop them.
/// B16 / BAC-2: bac students (minors) get no reminder between 22:00 and
/// 07:00 Algiers time: a later time moves to 21:30, an earlier one to 07:00.
({int hour, int minute}) quietSafeTime(int hour, int minute) {
  if (hour >= 22) return (hour: 21, minute: 30);
  if (hour < 7) return (hour: 7, minute: 0);
  return (hour: hour, minute: minute);
}

List<DateTime> planReminders(
  ReminderState state,
  DateTime now, {
  int max = 6,
  bool quietHours = false,
}) {
  final out = <DateTime>[];
  var s = state;
  if (!s.active) {
    return out;
  }
  final today = algiersWall(now);
  final time = quietHours
      ? quietSafeTime(s.hour, s.minute)
      : (hour: s.hour, minute: s.minute);
  for (var offset = 0; offset < 28 && out.length < max; offset++) {
    final at = algiersToUtc(
      today.year,
      today.month,
      today.day + offset,
      time.hour,
      time.minute,
    );
    final window = s.secondChanceUntil;
    if (window != null && !at.isBefore(window)) {
      break;
    }
    if (!s.studyDays.contains(algiersWall(at).weekday)) {
      continue;
    }
    if (!at.isAfter(now)) {
      continue;
    }
    if (!s.allowsAt(at)) {
      continue;
    }
    out.add(at);
    s = s.respond(ReminderResponse.ignored, at);
    if (!s.active) {
      break;
    }
  }
  return out;
}
