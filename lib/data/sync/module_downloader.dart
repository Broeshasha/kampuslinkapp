import 'dart:async';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/logging/logger.dart';
import '../bundle/bundle_importer.dart';
import '../db/app_database.dart';
import 'download_failure.dart';

typedef FetchManifest = Future<Map<String, dynamic>> Function(
  int moduleId,
  List<String> langs,
);
typedef FetchLesson = Future<Map<String, dynamic>> Function(
  int lessonId,
  List<String> langs,
);
typedef FetchExtras = Future<Map<String, dynamic>> Function(
  int moduleId,
  List<String> langs,
);
typedef FetchBundle = Future<Map<String, dynamic>> Function(
  int moduleId,
  List<String> langs,
);

class ModuleDownloadResult {
  const ModuleDownloadResult({
    required this.moduleId,
    required this.total,
    required this.stored,
    this.failure,
    this.usedFallback = false,
  });

  final int moduleId;
  final int total;
  final int stored;
  final DownloadFailure? failure;
  final bool usedFallback;

  bool get complete => failure == null && stored >= total;
}

/// The server does not have the file-13 functions yet.
bool isMissingFunction(Object error) =>
    error is PostgrestException &&
    (error.code == 'PGRST202' ||
        error.code == '42883' ||
        error.message.contains('Could not find the function'));

class _Attempted implements Exception {
  _Attempted(this.error, this.stack, this.attempts, this.seconds);

  final Object error;
  final StackTrace stack;
  final int attempts;
  final int seconds;
}

class _Stored {
  const _Stored(this.rev, this.langs);

  final String rev;
  final Set<String> langs;
}

class _Task {
  const _Task(this.lessonId, this.rev, this.index, this.langs, this.merge);

  final int lessonId;
  final String rev;
  final int index;
  final List<String> langs;
  final bool merge;
}

int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
List<Object?> _list(Object? v) => v is List ? v : const <Object?>[];
Map<String, dynamic> _map(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : const <String, dynamic>{};

/// Lead brief 2, section B: manifest -> only missing / changed lessons, one
/// lesson per request (2 at a time, 20 s timeout, 3 retries 1 s / 4 s /
/// 10 s), each lesson stored in its OWN transaction as it arrives, then
/// the extras. Resumable: the next run continues from the manifest diff.
/// Falls back to get_module_bundle when the new functions do not exist.
class ModuleDownloader {
  ModuleDownloader(
    this._db,
    this._importer, {
    required this.fetchManifest,
    required this.fetchLesson,
    required this.fetchExtras,
    required this.fetchBundle,
    this.delays = const [
      Duration(seconds: 1),
      Duration(seconds: 4),
      Duration(seconds: 10),
    ],
    this.timeout = const Duration(seconds: 20),
    this.concurrency = 2,
    Future<void> Function(Duration)? sleep,
  }) : _sleep = sleep ?? ((d) => Future<void>.delayed(d));

  final AppDatabase _db;
  final BundleImporter _importer;
  final FetchManifest fetchManifest;
  final FetchLesson fetchLesson;
  final FetchExtras fetchExtras;
  final FetchBundle fetchBundle;
  final List<Duration> delays;
  final Duration timeout;
  final int concurrency;
  final Future<void> Function(Duration) _sleep;

  String _revKey(int lessonId) => 'lesson_rev:$lessonId';
  String _extrasKey(int moduleId) => 'extras_rev:$moduleId';

  Future<String?> _get(String key) async => (await (_db.select(
    _db.keyValues,
  )..where((t) => t.name.equals(key))).getSingleOrNull())?.value;

  Future<void> _set(String key, String value) => _db
      .into(_db.keyValues)
      .insertOnConflictUpdate(
        KeyValuesCompanion(name: Value(key), value: Value(value)),
      );

  _Stored? _parse(String? raw) {
    if (raw == null) return null;
    final parts = raw.split('\n');
    return _Stored(
      parts.first,
      parts.length > 1
          ? parts[1].split(',').where((s) => s.isNotEmpty).toSet()
          : <String>{},
    );
  }

  String _encode(String rev, Iterable<String> langs) =>
      '$rev\n${(langs.toSet().toList()..sort()).join(',')}';

  /// Runs [run] with the timeout and the retry ladder.
  Future<T> _retry<T>(Future<T> Function() run, {Duration? limit}) async {
    final watch = Stopwatch()..start();
    var attempt = 0;
    while (true) {
      attempt++;
      try {
        return await run().timeout(limit ?? timeout);
      } catch (error, stack) {
        final kind = DownloadFailure.classify(error);
        final transient =
            kind == DownloadErrorKind.offline ||
            kind == DownloadErrorKind.timeout ||
            kind == DownloadErrorKind.server;
        if (isMissingFunction(error) || !transient || attempt > delays.length) {
          throw _Attempted(error, stack, attempt, watch.elapsed.inSeconds);
        }
        await _sleep(delays[attempt - 1]);
      }
    }
  }

  DownloadFailure _fail(
    Object e,
    StackTrace s, {
    required int moduleId,
    required String step,
  }) {
    final a = e is _Attempted ? e : _Attempted(e, s, 1, 0);
    final failure = DownloadFailure.from(
      a.error,
      moduleId: moduleId,
      step: step,
      attempts: a.attempts,
      seconds: a.seconds,
    );
    appLog.error(a.error, a.stack, reason: 'download ${failure.details}');
    return failure;
  }

  Future<ModuleDownloadResult> download(
    int moduleId,
    List<String> langs, {
    void Function(int done, int total)? onProgress,
  }) async {
    Map<String, dynamic> manifest;
    try {
      manifest = await _retry(() => fetchManifest(moduleId, langs));
    } catch (e, s) {
      final inner = e is _Attempted ? e.error : e;
      if (isMissingFunction(inner)) return _fallback(moduleId, langs);
      return ModuleDownloadResult(
        moduleId: moduleId,
        total: 0,
        stored: 0,
        failure: _fail(e, s, moduleId: moduleId, step: 'manifest'),
      );
    }

    final version = _int(manifest['version']);
    final lessons = _list(manifest['lessons']).map(_map).toList()
      ..sort((a, b) => _int(a['position']).compareTo(_int(b['position'])));
    final total = lessons.length;
    final ids = {for (final l in lessons) _int(l['id'])};

    try {
      await (_db.update(
        _db.modules,
      )..where((t) => t.id.equals(moduleId))).write(
        ModulesCompanion(
          serverVersion: Value(version),
          lessonCount: Value(total),
        ),
      );
      final local = await (_db.select(
        _db.lessons,
      )..where((t) => t.moduleId.equals(moduleId))).get();
      final gone = [
        for (final l in local)
          if (!ids.contains(l.id)) l.id,
      ];
      await _importer.deleteLessons(gone);
      for (final id in gone) {
        await (_db.delete(
          _db.keyValues,
        )..where((t) => t.name.equals(_revKey(id)))).go();
      }
    } catch (e, s) {
      return ModuleDownloadResult(
        moduleId: moduleId,
        total: total,
        stored: 0,
        failure: _fail(e, s, moduleId: moduleId, step: 'store manifest'),
      );
    }

    final tasks = <_Task>[];
    var done = 0;
    for (var i = 0; i < lessons.length; i++) {
      final l = lessons[i];
      final id = _int(l['id']);
      final rev = '${l['rev'] ?? ''}';
      final stored = _parse(await _get(_revKey(id)));
      if (stored == null || stored.rev != rev) {
        tasks.add(_Task(id, rev, i + 1, langs, false));
      } else {
        final missing = [
          for (final lang in langs)
            if (!stored.langs.contains(lang)) lang,
        ];
        if (missing.isEmpty) {
          done++;
        } else {
          tasks.add(_Task(id, rev, i + 1, missing, true));
        }
      }
    }
    onProgress?.call(done, total);

    DownloadFailure? firstFailure;
    final queue = [...tasks];
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final task = queue.removeAt(0);
        final step = 'lesson ${task.index}/$total (id ${task.lessonId})';
        try {
          final lesson = await _retry(
            () => fetchLesson(task.lessonId, task.langs),
          );
          await _importer.importLesson(moduleId, lesson, merge: task.merge);
          final before = _parse(await _get(_revKey(task.lessonId)));
          await _set(
            _revKey(task.lessonId),
            _encode(task.rev, {
              if (task.merge) ...?before?.langs,
              ...task.langs,
            }),
          );
          done++;
          onProgress?.call(done, total);
        } catch (e, s) {
          firstFailure ??= _fail(e, s, moduleId: moduleId, step: step);
        }
      }
    }

    await Future.wait([for (var i = 0; i < concurrency; i++) worker()]);

    final extrasRev = '${manifest['extras_rev'] ?? ''}';
    final storedExtras = _parse(await _get(_extrasKey(moduleId)));
    final extrasMissing =
        storedExtras == null ||
        storedExtras.rev != extrasRev ||
        !langs.every(storedExtras.langs.contains);
    if (extrasMissing) {
      try {
        final extras = await _retry(() => fetchExtras(moduleId, langs));
        await _importer.importExtras(moduleId, extras);
        await _set(
          _extrasKey(moduleId),
          _encode(extrasRev, {...?storedExtras?.langs, ...langs}),
        );
      } catch (e, s) {
        firstFailure ??= _fail(e, s, moduleId: moduleId, step: 'extras');
      }
    }

    final failure = firstFailure;
    if (failure == null && done >= total) {
      final row = await (_db.select(
        _db.modules,
      )..where((t) => t.id.equals(moduleId))).getSingleOrNull();
      final had = (row?.languages ?? '').split(',').where((s) => s.isNotEmpty);
      await (_db.update(
        _db.modules,
      )..where((t) => t.id.equals(moduleId))).write(
        ModulesCompanion(
          localVersion: Value(version),
          languages: Value(({...had, ...langs}.toList()..sort()).join(',')),
          downloadedAt: Value(DateTime.now()),
        ),
      );
    }
    return ModuleDownloadResult(
      moduleId: moduleId,
      total: total,
      stored: done,
      failure: failure,
    );
  }

  Future<ModuleDownloadResult> _fallback(
    int moduleId,
    List<String> langs,
  ) async {
    appLog.warn('download: file-13 functions missing, using get_module_bundle');
    try {
      final bundle = await _retry(
        () => fetchBundle(moduleId, langs),
        limit: const Duration(seconds: 90),
      );
      await _importer.importBundle(bundle);
      final n = _list(bundle['lessons']).length;
      return ModuleDownloadResult(
        moduleId: moduleId,
        total: n,
        stored: n,
        usedFallback: true,
      );
    } catch (e, s) {
      return ModuleDownloadResult(
        moduleId: moduleId,
        total: 0,
        stored: 0,
        usedFallback: true,
        failure: _fail(e, s, moduleId: moduleId, step: 'bundle (fallback)'),
      );
    }
  }

  /// The reader asked for a language this lesson does not have yet.
  Future<DownloadFailure?> topUpLesson(int lessonId, String lang) async {
    final row = await (_db.select(
      _db.lessons,
    )..where((t) => t.id.equals(lessonId))).getSingleOrNull();
    if (row == null) return null;
    try {
      final lesson = await _retry(() => fetchLesson(lessonId, [lang]));
      await _importer.importLesson(row.moduleId, lesson, merge: true);
      final before = _parse(await _get(_revKey(lessonId)));
      if (before != null) {
        await _set(
          _revKey(lessonId),
          _encode(before.rev, {...before.langs, lang}),
        );
      }
      return null;
    } catch (e, s) {
      return _fail(
        e,
        s,
        moduleId: row.moduleId,
        step: 'language $lang for lesson $lessonId',
      );
    }
  }
}
