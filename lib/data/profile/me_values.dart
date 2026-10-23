/// Typed reads of the cached get_me() map (contract 11 fields).
int? currentSemesterOf(Map<String, dynamic>? me) {
  final v = me?['current_semester'];
  return v is num ? v.toInt() : null;
}

List<int> pinnedSemestersOf(Map<String, dynamic>? me) {
  final v = me?['pinned_semesters'];
  if (v is! List) return const [];
  return [
    for (final e in v)
      if (e is num) e.toInt(),
  ]..sort();
}

bool yearQuestionDue(Map<String, dynamic>? me) =>
    me?['year_question_due'] == true;

String yearQuestionKey(Map<String, dynamic>? me) =>
    '${me?['year_question_key'] ?? ''}';

bool isAdmin(Map<String, dynamic>? me) => me?['is_admin'] == true;

/// Months when a new semester starts: the semester reminder is louder
/// (contract 11: client constants for now).
const semesterChangeMonths = {1, 2, 6, 7};
