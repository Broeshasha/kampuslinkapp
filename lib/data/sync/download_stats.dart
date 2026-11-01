import '../db/app_database.dart';

/// Content stored on the phone per module (characters of the stored JSON,
/// close to bytes), for Profile > Downloads.
Future<Map<int, int>> storedBytesPerModule(AppDatabase db) async {
  final rows = await db
      .customSelect(
        'SELECT m, SUM(n) AS n FROM ('
        ' SELECT module_id AS m, LENGTH(i18n_json) + IFNULL(LENGTH(unit_json), 0) AS n FROM lessons'
        ' UNION ALL SELECT module_id, LENGTH(i18n_json) FROM cards'
        ' UNION ALL SELECT module_id, LENGTH(i18n_json) FROM questions'
        ' UNION ALL SELECT module_id, IFNULL(LENGTH(definition_json), 0)'
        ' + IFNULL(LENGTH(fr), 0) + IFNULL(LENGTH(ar), 0) + IFNULL(LENGTH(en), 0)'
        ' FROM glossary_entries'
        ') GROUP BY m',
      )
      .get();
  return {
    for (final r in rows)
      if (r.data['m'] is int) r.data['m'] as int: (r.data['n'] as int?) ?? 0,
  };
}

/// Everything else kept on the phone (sets, practice, exams, feed state).
Future<int> storedOtherBytes(AppDatabase db) async {
  final row = await db
      .customSelect('SELECT IFNULL(SUM(LENGTH(value)), 0) AS n FROM key_values')
      .getSingle();
  return (row.data['n'] as int?) ?? 0;
}

String formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).round()} KB';
  return '$bytes B';
}
