import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../core/logging/logger.dart';
import 'lang_filter.dart';

/// Where the static content files live (Cloudflare R2, see cdn_publish.py).
const cdnBaseUrl = 'https://files.kampus-link.com/';

final _manifestPath = RegExp(
  r'^v1/m/[0-9]+/([0-9]+)-[0-9a-f]{16}/manifest\.json$',
);
final _blobPath = RegExp(r'^v1/b/([0-9a-f]{64})\.json$');

typedef CdnGet = Future<Uint8List> Function(Uri url);

class CdnError implements Exception {
  const CdnError(this.message);
  final String message;

  @override
  String toString() => 'CdnError($message)';
}

/// The manifest path of [moduleId] in the "cdn" object sent by app_open
/// (stored as JSON text), or null.
String? cdnPathFrom(String? json, int moduleId) {
  if (json == null || json.isEmpty) return null;
  try {
    final v = jsonDecode(json);
    final p = v is Map ? v['$moduleId'] : null;
    return p is String && _manifestPath.hasMatch(p) ? p : null;
  } on FormatException {
    return null;
  }
}

/// The content version a manifest path was published for.
int? cdnVersionOf(String path) {
  final m = _manifestPath.firstMatch(path);
  return m == null ? null : int.tryParse(m.group(1)!);
}

/// After [threshold] Cloudflare failures in a row (while Supabase answered),
/// Cloudflare is not tried for [pause]. The end time is kept on the phone.
class CdnBreaker {
  CdnBreaker({
    required this.read,
    required this.write,
    this.threshold = 3,
    this.pause = const Duration(minutes: 30),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final String? Function() read;
  final void Function(String value) write;
  final int threshold;
  final Duration pause;
  final DateTime Function() _now;
  int _failures = 0;

  bool get open {
    final raw = read();
    final until = raw == null ? null : DateTime.tryParse(raw);
    return until != null && _now().isBefore(until);
  }

  void success() => _failures = 0;

  void failure() {
    _failures++;
    if (_failures < threshold) return;
    _failures = 0;
    write(_now().add(pause).toIso8601String());
  }
}

class _Ref {
  const _Ref(this.path, this.sha);
  final String path;
  final String sha;

  static _Ref? from(Object? entry) {
    if (entry is! Map) return null;
    final path = entry['path'];
    final sha = entry['sha256'];
    if (path is! String || sha is! String) return null;
    final m = _blobPath.firstMatch(path);
    return m != null && m.group(1) == sha ? _Ref(path, sha) : null;
  }
}

int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
List<Object?> _list(Object? v) => v is List ? v : const <Object?>[];
Map<String, dynamic> _map(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : const <String, dynamic>{};

/// CDN-2: every content download asks Cloudflare first and Supabase second.
/// - A module uses Cloudflare only when app_open sent a path for it and that
///   path is not older than the module's server version.
/// - Any Cloudflare problem (network, 404, wrong hash, bad JSON) falls back
///   to the old Supabase call for that request. It counts against the
///   breaker only when Supabase then answers (= the phone is online).
/// - Files hold every language; the phone keeps the requested ones.
/// The answers have the shape of the Supabase functions, so the downloader,
/// the importer and the practice / exam store do not know the source.
class ContentSource {
  ContentSource({
    required this.remoteManifest,
    required this.remoteLesson,
    required this.remoteExtras,
    required this.remotePractice,
    required this.remotePaper,
    required this.cdnGet,
    required this.cdnPath,
    required this.breaker,
    this.remoteResources,
    this.serverVersion,
    this.enabled = true,
    this.cdnTimeout = const Duration(seconds: 12),
  });

  final Future<Map<String, dynamic>> Function(int moduleId, List<String> langs)
  remoteManifest;
  final Future<Map<String, dynamic>> Function(int lessonId, List<String> langs)
  remoteLesson;
  final Future<Map<String, dynamic>> Function(int moduleId, List<String> langs)
  remoteExtras;
  final Future<List<Object?>> Function(
    int moduleId,
    String chapterRef,
    List<String> langs,
  )
  remotePractice;
  final Future<Map<String, dynamic>> Function(int paperId, List<String> langs)
  remotePaper;

  /// The library list of a module (not on the CDN); null = leave it as is.
  final Future<List<Object?>> Function(int moduleId)? remoteResources;
  final CdnGet cdnGet;
  final String? Function(int moduleId) cdnPath;
  final Future<int?> Function(int moduleId)? serverVersion;
  final CdnBreaker breaker;
  final bool enabled;
  final Duration cdnTimeout;

  // What the last Cloudflare manifest of each module said (memory only).
  final Map<int, _Ref> _extras = {};
  final Map<int, Map<String, _Ref>> _practice = {};
  final Map<int, Set<int>> _lessonsOf = {};
  final Map<int, Set<int>> _examsOf = {};
  final Map<int, _Ref> _lessons = {};
  final Map<int, _Ref> _exams = {};

  bool get _on => enabled && !breaker.open;

  /// true when the last manifest of [moduleId] came from Cloudflare.
  bool usesCdn(int moduleId) => _extras.containsKey(moduleId);

  void _forget(int moduleId) {
    _extras.remove(moduleId);
    _practice.remove(moduleId);
    for (final id in _lessonsOf.remove(moduleId) ?? const <int>{}) {
      _lessons.remove(id);
    }
    for (final id in _examsOf.remove(moduleId) ?? const <int>{}) {
      _exams.remove(id);
    }
  }

  void _blame(Object error, String what) {
    appLog.warn('cdn: $what failed ($error) - Supabase used');
    breaker.failure();
  }

  Future<Object?> _get(String path, {String? sha}) async {
    final bytes = await cdnGet(Uri.parse('$cdnBaseUrl$path')).timeout(cdnTimeout);
    if (sha != null && sha256.convert(bytes).toString() != sha) {
      throw CdnError('hash mismatch $path');
    }
    return jsonDecode(utf8.decode(bytes));
  }

  Future<String?> _usablePath(int moduleId) async {
    if (!_on) return null;
    final path = cdnPath(moduleId);
    if (path == null) return null;
    final published = cdnVersionOf(path);
    if (published == null) return null;
    final server = await serverVersion?.call(moduleId);
    // The content changed after the publish: Supabase until the next publish.
    if (server != null && published < server) return null;
    return path;
  }

  String _langRev(Object? rev, List<String> langs) =>
      '$rev:${(langs.toSet().toList()..sort()).join(',')}';

  /// Same keys as get_module_manifest.
  Map<String, dynamic> _adopt(
    int moduleId,
    Map<String, dynamic> raw,
    List<String> langs,
  ) {
    if (_int(raw['schema']) != 1) {
      throw CdnError('manifest schema ${raw['schema']}');
    }
    if (_int(raw['module_id']) != moduleId) {
      throw const CdnError('manifest of another module');
    }
    final extras = _Ref.from(raw['extras']);
    if (extras == null) throw const CdnError('manifest without extras');
    final lessons = <int, _Ref>{};
    final outLessons = <Object?>[];
    for (final l in _list(raw['lessons']).map(_map)) {
      final ref = _Ref.from(l);
      if (ref == null) throw const CdnError('lesson without file');
      lessons[_int(l['id'])] = ref;
      outLessons.add(<String, dynamic>{
        ...l,
        'kb': (_int(l['bytes']) / 1024).round(),
      });
    }
    final practice = <String, _Ref>{};
    final outPractice = <Object?>[];
    for (final p in _list(raw['practice']).map(_map)) {
      final ref = _Ref.from(p);
      if (ref == null) throw const CdnError('practice without file');
      practice['${p['chapter_ref']}'] = ref;
      // Practice and exams are stored per rev only: the rev must change
      // when the languages do (as it does on Supabase).
      outPractice.add(<String, dynamic>{
        ...p,
        'rev': _langRev(p['rev'], langs),
      });
    }
    final exams = <int, _Ref>{};
    final outExams = <Object?>[];
    for (final e in _list(raw['exams']).map(_map)) {
      final ref = _Ref.from(e);
      if (ref == null) throw const CdnError('exam without file');
      exams[_int(e['id'])] = ref;
      outExams.add(<String, dynamic>{
        ...e,
        'kb': (_int(e['bytes']) / 1024).round(),
        'rev': _langRev(e['rev'], langs),
      });
    }
    _extras[moduleId] = extras;
    _practice[moduleId] = practice;
    _lessonsOf[moduleId] = lessons.keys.toSet();
    _examsOf[moduleId] = exams.keys.toSet();
    _lessons.addAll(lessons);
    _exams.addAll(exams);
    return <String, dynamic>{
      'schema_version': 3,
      'source': 'cdn',
      'module': raw['module'],
      'version': raw['version'],
      'generated_at': raw['generated_at'],
      'lessons': outLessons,
      'extras_rev': extras.sha,
      'practice': outPractice,
      'exams': outExams,
    };
  }

  Future<Map<String, dynamic>> fetchManifest(
    int moduleId,
    List<String> langs,
  ) async {
    _forget(moduleId);
    Object? cdnError;
    final path = await _usablePath(moduleId);
    if (path != null) {
      try {
        final manifest = _adopt(moduleId, _map(await _get(path)), langs);
        breaker.success();
        return manifest;
      } catch (e) {
        _forget(moduleId);
        cdnError = e;
      }
    }
    final manifest = await remoteManifest(moduleId, langs);
    if (cdnError != null) _blame(cdnError, 'manifest of module $moduleId');
    return manifest;
  }

  Future<Map<String, dynamic>> fetchLesson(
    int lessonId,
    List<String> langs,
  ) async {
    Object? cdnError;
    final ref = _lessons[lessonId];
    if (ref != null && _on) {
      try {
        final lesson = _map(await _get(ref.path, sha: ref.sha));
        if (_int(lesson['id']) != lessonId) {
          throw const CdnError('file of another lesson');
        }
        breaker.success();
        return filterLesson(lesson, langs);
      } catch (e) {
        cdnError = e;
      }
    }
    final lesson = await remoteLesson(lessonId, langs);
    if (cdnError != null) _blame(cdnError, 'lesson $lessonId');
    return lesson;
  }

  Future<Map<String, dynamic>> fetchExtras(
    int moduleId,
    List<String> langs,
  ) async {
    Object? cdnError;
    final ref = _extras[moduleId];
    if (ref != null && _on) {
      Map<String, dynamic>? extras;
      try {
        extras = filterExtras(_map(await _get(ref.path, sha: ref.sha)), langs);
        breaker.success();
      } catch (e) {
        cdnError = e;
      }
      if (extras != null) {
        final resources = remoteResources;
        if (resources != null) {
          try {
            extras['resources'] = await resources(moduleId);
          } catch (e) {
            // No "resources" key = the importer keeps the library it has.
            appLog.info('library list of module $moduleId not refreshed: $e');
          }
        }
        return extras;
      }
    }
    final extras = await remoteExtras(moduleId, langs);
    if (cdnError != null) _blame(cdnError, 'extras of module $moduleId');
    return extras;
  }

  Future<List<Object?>> fetchPractice(
    int moduleId,
    String chapterRef,
    List<String> langs,
  ) async {
    Object? cdnError;
    final ref = _practice[moduleId]?[chapterRef];
    if (ref != null && _on) {
      try {
        final items = await _get(ref.path, sha: ref.sha);
        if (items is! List) throw const CdnError('practice file is not a list');
        breaker.success();
        return filterPractice(items, langs);
      } catch (e) {
        cdnError = e;
      }
    }
    final items = await remotePractice(moduleId, chapterRef, langs);
    if (cdnError != null) _blame(cdnError, 'practice $moduleId/$chapterRef');
    return items;
  }

  Future<Map<String, dynamic>> fetchPaper(
    int paperId,
    List<String> langs,
  ) async {
    Object? cdnError;
    final ref = _exams[paperId];
    if (ref != null && _on) {
      try {
        final paper = _map(await _get(ref.path, sha: ref.sha));
        if (_int(paper['id']) != paperId) {
          throw const CdnError('file of another exam');
        }
        breaker.success();
        return filterExam(paper, langs);
      } catch (e) {
        cdnError = e;
      }
    }
    final paper = await remotePaper(paperId, langs);
    if (cdnError != null) _blame(cdnError, 'exam $paperId');
    return paper;
  }
}
