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

/// get_reminder_settings() on the phone. The back-off is computed here
/// exactly like the server does, so it works offline:
/// started -> reset; 2 declines in a row -> pause 3 days; after the pause,
/// one more decline -> stopped (until the student turns reminders on again).
@immutable
class ReminderState {
  const ReminderState({
    this.enabled = false,
    this.unsubscribed = false,
    this.stopped = false,
    this.studyTime = defaultStudyTime,
    this.studyDays = everyDay,
    this.declinesInRow = 0,
    this.pausedUntil,
    this.afterPause = false,
  });

  factory ReminderState.fromJson(Map<String, dynamic> json) {
    final days = json['study_days'];
    return ReminderState(
      enabled: json['enabled'] == true,
      unsubscribed: json['unsubscribed'] == true,
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
      pausedUntil: DateTime.tryParse('${json['paused_until'] ?? ''}')?.toUtc(),
      afterPause: json['after_pause'] == true,
    );
  }

  final bool enabled;
  final bool unsubscribed;
  final bool stopped;

  /// "HH:MM", Algiers time.
  final String studyTime;

  /// ISO days, 1 = Monday ... 7 = Sunday.
  final List<int> studyDays;
  final int declinesInRow;
  final DateTime? pausedUntil;
  final bool afterPause;

  bool get active => enabled && !unsubscribed && !stopped;
  int get hour => int.parse(studyTime.substring(0, 2));
  int get minute => int.parse(studyTime.substring(3, 5));

  /// May a reminder fire at [at]?
  bool allowsAt(DateTime at) {
    final until = pausedUntil;
    return active && (until == null || !at.isBefore(until));
  }

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'unsubscribed': unsubscribed,
    'stopped': stopped,
    'study_time': studyTime,
    'study_days': studyDays,
    'declines_in_row': declinesInRow,
    'paused_until': pausedUntil?.toUtc().toIso8601String(),
    'after_pause': afterPause,
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
  }) => ReminderState(
    enabled: enabled ?? this.enabled,
    unsubscribed: unsubscribed,
    stopped: stopped ?? this.stopped,
    studyTime: studyTime ?? this.studyTime,
    studyDays: studyDays ?? this.studyDays,
    declinesInRow: declinesInRow ?? this.declinesInRow,
    pausedUntil: clearPause ? null : (pausedUntil ?? this.pausedUntil),
    afterPause: afterPause ?? this.afterPause,
  );

  /// The back-off state machine (identical to the server).
  ReminderState respond(ReminderResponse response, DateTime at) {
    if (response == ReminderResponse.started) {
      return copyWith(declinesInRow: 0, clearPause: true, afterPause: false);
    }
    if (stopped) {
      return this;
    }
    if (afterPause) {
      return copyWith(
        stopped: true,
        declinesInRow: 0,
        clearPause: true,
        afterPause: false,
      );
    }
    final declines = declinesInRow + 1;
    if (declines >= 2) {
      return copyWith(
        declinesInRow: 0,
        pausedUntil: at.toUtc().add(reminderPause),
        afterPause: true,
      );
    }
    return copyWith(declinesInRow: declines);
  }

  /// Turning reminders ON clears the back-off (like the server).
  ReminderState turnedOn({String? time, List<int>? days}) => ReminderState(
    enabled: true,
    studyTime: time == null ? studyTime : normalizeTime(time),
    studyDays: days == null ? studyDays : normalizeDays(days),
  );

  @override
  bool operator ==(Object other) =>
      other is ReminderState &&
      other.enabled == enabled &&
      other.unsubscribed == unsubscribed &&
      other.stopped == stopped &&
      other.studyTime == studyTime &&
      listEquals(other.studyDays, studyDays) &&
      other.declinesInRow == declinesInRow &&
      other.pausedUntil == pausedUntil &&
      other.afterPause == afterPause;

  @override
  int get hashCode => Object.hash(
    enabled,
    unsubscribed,
    stopped,
    studyTime,
    Object.hashAll(studyDays),
    declinesInRow,
    pausedUntil,
    afterPause,
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
List<DateTime> planReminders(
  ReminderState state,
  DateTime now, {
  bool studiedToday = false,
  int max = 6,
}) {
  final out = <DateTime>[];
  var s = state;
  if (!s.active) {
    return out;
  }
  final today = algiersWall(now);
  for (var offset = 0; offset < 28 && out.length < max; offset++) {
    final at = algiersToUtc(
      today.year,
      today.month,
      today.day + offset,
      s.hour,
      s.minute,
    );
    if (!s.studyDays.contains(algiersWall(at).weekday)) {
      continue;
    }
    if (!at.isAfter(now)) {
      continue;
    }
    if (offset == 0 && studiedToday) {
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
