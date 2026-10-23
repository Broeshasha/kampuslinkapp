/// Typed reads of the cached get_me() map.
int? currentSemesterOf(Map<String, dynamic>? me) {
  final v = me?['current_semester'];
  return v is num ? v.toInt() : null;
}

bool isAdmin(Map<String, dynamic>? me) => me?['is_admin'] == true;
