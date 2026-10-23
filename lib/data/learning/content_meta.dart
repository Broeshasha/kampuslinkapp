import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../providers.dart';
import 'learning_providers.dart';

/// Every key_values `meta:<lesson>` row, flattened: `c:<cardId>` and
/// `q:<questionId>` -> fields (concept, difficulty, card_kind, figure,
/// option_figures).
Future<Map<String, Map<String, dynamic>>> loadContentMeta(
  AppDatabase db,
) async {
  final rows = await (db.select(
    db.keyValues,
  )..where((t) => t.name.like('meta:%'))).get();
  final out = <String, Map<String, dynamic>>{};
  for (final r in rows) {
    try {
      final v = jsonDecode(r.value);
      if (v is! Map) continue;
      for (final part in const ['c', 'q']) {
        final m = v[part];
        if (m is! Map) continue;
        for (final e in m.entries) {
          if (e.value is Map) {
            out['$part:${e.key}'] = (e.value as Map).cast<String, dynamic>();
          }
        }
      }
    } on FormatException {
      continue;
    }
  }
  return out;
}

/// Reloaded only when downloaded content changes.
final contentMetaProvider = FutureProvider<Map<String, Map<String, dynamic>>>((
  ref,
) {
  ref.watch(downloadedKeyProvider);
  return loadContentMeta(ref.watch(appDatabaseProvider));
});
