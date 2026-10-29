import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../providers.dart';
import 'learning_providers.dart';

/// Every key_values `meta:<lesson>` value, flattened: `c:<cardId>` and
/// `q:<questionId>` -> fields (concept, difficulty, card_kind, figure,
/// option_figures). Pure, so it can run in a background isolate.
Map<String, Map<String, dynamic>> flattenMeta(List<String> values) {
  final out = <String, Map<String, dynamic>>{};
  for (final value in values) {
    try {
      final v = jsonDecode(value);
      if (v is! Map) {
        continue;
      }
      for (final part in const ['c', 'q']) {
        final m = v[part];
        if (m is! Map) {
          continue;
        }
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

/// Meta above this size is decoded off the UI thread.
const metaDecodeIsolateBytes = 20000;

/// Every key_values `meta:<lesson>` row, flattened (see [flattenMeta]).
/// Big modules are decoded in a background isolate: no frozen frames.
Future<Map<String, Map<String, dynamic>>> loadContentMeta(
  AppDatabase db,
) async {
  final rows = await (db.select(
    db.keyValues,
  )..where((t) => t.name.like('meta:%'))).get();
  final values = [for (final r in rows) r.value];
  final size = values.fold<int>(0, (n, v) => n + v.length);
  if (size < metaDecodeIsolateBytes) {
    return flattenMeta(values);
  }
  try {
    return await compute(flattenMeta, values);
  } catch (_) {
    return flattenMeta(values);
  }
}

/// Reloaded only when downloaded content changes.
final contentMetaProvider = FutureProvider<Map<String, Map<String, dynamic>>>((
  ref,
) {
  ref.watch(downloadedKeyProvider);
  return loadContentMeta(ref.watch(appDatabaseProvider));
});
