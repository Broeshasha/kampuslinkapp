import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/errors/result.dart';
import '../../core/logging/logger.dart';
import '../db/app_database.dart';
import '../providers.dart';

Map<String, dynamic> _map(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : const <String, dynamic>{};
List<Object?> _list(Object? v) => v is List ? v : const <Object?>[];
int? _int(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');
String _str(Object? v) => v == null ? '' : '$v';

/// Text in [lang] from a {en, fr, ar} map (then French, English, any).
String localized(Object? v, String lang) {
  if (v is String) return v;
  if (v is! Map || v.isEmpty) return '';
  final t = v[lang] ?? v['fr'] ?? v['en'] ?? v.values.first;
  return t == null ? '' : '$t';
}

/// One year of the speciality (e.g. L2 with semesters [3, 4]).
class CatalogLevel {
  const CatalogLevel({
    required this.year,
    required this.position,
    required this.semesters,
    required this.label,
  });

  factory CatalogLevel.fromMap(Map<String, dynamic> m) => CatalogLevel(
    year: _str(m['year']),
    position: _int(m['position']) ?? 0,
    semesters: [for (final s in _list(m['semesters'])) ?_int(s)],
    label: _map(m['label']),
  );

  final String year;
  final int position;
  final List<int> semesters;
  final Map<String, dynamic> label;

  String labelIn(String lang) {
    final t = localized(label, lang);
    return t.isEmpty ? year : t;
  }
}

class CatalogModule {
  const CatalogModule({
    required this.id,
    required this.name,
    this.icon,
    this.color,
    this.semester,
    this.counts = const {},
  });

  factory CatalogModule.fromMap(Map<String, dynamic> m) => CatalogModule(
    id: _int(m['id']) ?? 0,
    name: _str(m['name']),
    icon: m['icon'] == null ? null : _str(m['icon']),
    color: m['color'] == null ? null : _str(m['color']),
    semester: _int(m['semester']),
    counts: {for (final e in _map(m['counts']).entries) e.key: ?_int(e.value)},
  );

  final int id;
  final String name;
  final String? icon;
  final String? color;
  final int? semester;
  final Map<String, int> counts;

  int count(String key) => counts[key] ?? 0;
}

/// get_my_catalog(): the ONE source of truth for years, semesters, module
/// names / order / icons / colours and app settings (lead WP17/18-1).
class Catalog {
  const Catalog({
    this.config = const {},
    this.me = const {},
    this.speciality = const {},
    this.levels = const [],
    this.modules = const [],
  });

  factory Catalog.fromMap(Map<String, dynamic> m) => Catalog(
    config: _map(m['config']),
    me: _map(m['me']),
    speciality: _map(m['speciality']),
    levels: [
      for (final l in _list(m['levels']))
        if (l is Map) CatalogLevel.fromMap(l.cast<String, dynamic>()),
    ]..sort((a, b) => a.position.compareTo(b.position)),
    modules: [
      for (final x in _list(m['modules']))
        if (x is Map) CatalogModule.fromMap(x.cast<String, dynamic>()),
    ],
  );

  final Map<String, dynamic> config;
  final Map<String, dynamic> me;
  final Map<String, dynamic> speciality;
  final List<CatalogLevel> levels;
  final List<CatalogModule> modules;

  CatalogLevel? level(String? year) {
    for (final l in levels) {
      if (l.year == year) return l;
    }
    return null;
  }

  CatalogModule? module(int id) {
    for (final m in modules) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Position of a module in the catalog order (unknown ones last).
  int orderOf(int id) {
    final i = modules.indexWhere((m) => m.id == id);
    return i < 0 ? 1 << 20 : i;
  }

  bool get learnEnabled => speciality['learn_enabled'] != false;
}

const _catalogKey = 'catalog';

/// The catalog: last copy from the phone at once, then a fresh one when
/// online (after sign-in, at start, after set_study_level, pull to refresh).
class CatalogController extends AsyncNotifier<Catalog?> {
  @override
  Future<Catalog?> build() async {
    if (!ref.watch(isSignedInProvider)) return null;
    return _load();
  }

  Future<Catalog?> _load() async {
    final db = ref.read(appDatabaseProvider);
    final row = await (db.select(
      db.keyValues,
    )..where((t) => t.name.equals(_catalogKey))).getSingleOrNull();
    if (row == null) return null;
    try {
      final v = jsonDecode(row.value);
      return v is Map ? Catalog.fromMap(v.cast<String, dynamic>()) : null;
    } on FormatException {
      return null;
    }
  }

  /// Fetches get_my_catalog() and stores it; keeps the old copy offline.
  Future<Result<void>> refresh() async {
    final api = ref.read(kampusApiProvider);
    if (api == null || !ref.read(isSignedInProvider)) return const Ok(null);
    final r = await guard(() async {
      final raw = await api.getMyCatalog();
      final db = ref.read(appDatabaseProvider);
      await db
          .into(db.keyValues)
          .insertOnConflictUpdate(
            KeyValuesCompanion(
              name: const Value(_catalogKey),
              value: Value(jsonEncode(raw)),
            ),
          );
      return Catalog.fromMap(raw);
    });
    switch (r) {
      case Ok(:final value):
        state = AsyncData(value);
        return const Ok(null);
      case Err(:final failure):
        appLog.info('catalog offline: $failure');
        return Err(failure);
    }
  }
}

final catalogProvider = AsyncNotifierProvider<CatalogController, Catalog?>(
  CatalogController.new,
);

/// The catalog when known (null while loading or never fetched).
/// config.show_demo_cases (off unless the server says true).
bool showDemoCases(Catalog? catalog) =>
    catalog?.config['show_demo_cases'] == true;

final catalogValueProvider = Provider<Catalog?>(
  (ref) => ref.watch(catalogProvider).value,
);
