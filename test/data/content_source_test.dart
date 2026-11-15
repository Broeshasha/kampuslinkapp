import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/data/content/content_source.dart';

const _manifest = 'v1/m/3001/7-0123456789abcdef/manifest.json';

/// A tiny copy of what tools/cdn_publish.py writes.
class _Cdn {
  final files = <String, Uint8List>{};
  final asked = <String>[];
  bool down = false;

  Map<String, dynamic> add(Object? json) {
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(json)));
    final hash = sha256.convert(bytes).toString();
    files['v1/b/$hash.json'] = bytes;
    return {'path': 'v1/b/$hash.json', 'sha256': hash, 'bytes': bytes.length};
  }

  void publish() {
    final lesson = {
      'id': 11,
      'position': 1,
      'unit': {
        'ref': 'ch1',
        'number': 1,
        'title': {'fr': 'U', 'ar': 'W'},
      },
      'i18n': {
        'fr': {'title': 'T'},
        'ar': {'title': 'A'},
      },
      'cards': const [],
      'questions': const [],
      'resources': const [],
    };
    final lessonRef = add(lesson);
    final extrasRef = add({
      'glossary': [
        {'id': 1, 'fr': 'mot', 'ar': 'k', 'en': 'word'},
      ],
      'sets': const [],
    });
    final practiceRef = add([
      {
        'id': 3,
        'title': {'fr': 't', 'ar': 'u'},
      },
    ]);
    final examRef = add({
      'id': 4,
      'title': {'fr': 't', 'ar': 'u'},
      'exercises': const [],
    });
    files[_manifest] = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'schema': 1,
          'module_id': 3001,
          'module': {'id': 3001, 'name': 'SVT'},
          'version': 7,
          'lessons': [
            {
              'id': 11,
              'position': 1,
              'titles': {'fr': 'T', 'ar': 'A'},
              'rev': lessonRef['sha256'],
              ...lessonRef,
            },
          ],
          'extras': {'rev': extrasRef['sha256'], ...extrasRef},
          'practice': [
            {
              'chapter_ref': 'ch1',
              'unit_number': 1,
              'count': 1,
              'rev': practiceRef['sha256'],
              ...practiceRef,
            },
          ],
          'exams': [
            {'id': 4, 'rev': examRef['sha256'], ...examRef},
          ],
        }),
      ),
    );
  }

  Future<Uint8List> get(Uri url) async {
    final path = url.toString().substring(cdnBaseUrl.length);
    asked.add(path);
    final bytes = files[path];
    if (down || bytes == null) throw const CdnError('HTTP 404');
    return bytes;
  }
}

class _Supabase {
  final calls = <String>[];
  bool down = false;

  void _check(String what) {
    calls.add(what);
    if (down) throw Exception('SocketException: offline');
  }

  Future<Map<String, dynamic>> manifest(int m, List<String> langs) async {
    _check('manifest');
    return {'version': 7, 'lessons': const [], 'extras_rev': 'supabase'};
  }

  Future<Map<String, dynamic>> lesson(int id, List<String> langs) async {
    _check('lesson');
    return {'id': id, 'i18n': const {}, 'from': 'supabase'};
  }

  Future<Map<String, dynamic>> extras(int m, List<String> langs) async {
    _check('extras');
    return {'glossary': const [], 'sets': const [], 'resources': const []};
  }

  Future<List<Object?>> practice(int m, String c, List<String> langs) async {
    _check('practice');
    return const [];
  }

  Future<Map<String, dynamic>> paper(int id, List<String> langs) async {
    _check('paper');
    return {'id': id, 'from': 'supabase'};
  }

  Future<List<Object?>> resources(int m) async {
    _check('resources');
    return [
      {'id': 1, 'title': 'cours'},
    ];
  }
}

void main() {
  late _Cdn cdn;
  late _Supabase supabase;
  late DateTime now;
  String? breakerUntil;
  String? path;
  int? serverVersion;

  ContentSource source({bool enabled = true}) => ContentSource(
    remoteManifest: supabase.manifest,
    remoteLesson: supabase.lesson,
    remoteExtras: supabase.extras,
    remotePractice: supabase.practice,
    remotePaper: supabase.paper,
    remoteResources: supabase.resources,
    cdnGet: cdn.get,
    cdnPath: (id) => path,
    serverVersion: (id) async => serverVersion,
    breaker: CdnBreaker(
      read: () => breakerUntil,
      write: (v) => breakerUntil = v,
      now: () => now,
    ),
    enabled: enabled,
  );

  setUp(() {
    cdn = _Cdn()..publish();
    supabase = _Supabase();
    now = DateTime(2026, 11, 15, 10);
    breakerUntil = null;
    path = _manifest;
    serverVersion = 7;
  });

  test('path helpers', () {
    expect(cdnPathFrom('{"3001":"$_manifest"}', 3001), _manifest);
    expect(cdnPathFrom('{"3001":"$_manifest"}', 3002), isNull);
    expect(cdnPathFrom('{"3001":"https://evil.example/x"}', 3001), isNull);
    expect(cdnPathFrom('not json', 3001), isNull);
    expect(cdnPathFrom(null, 3001), isNull);
    expect(cdnVersionOf(_manifest), 7);
  });

  test('everything comes from Cloudflare, in the Supabase shape', () async {
    final s = source();
    final manifest = await s.fetchManifest(3001, const ['fr']);
    expect(manifest['source'], 'cdn');
    expect(manifest['version'], 7);
    expect(manifest['extras_rev'], isNotEmpty);
    final entry = (manifest['lessons'] as List).single as Map;
    expect(entry['id'], 11);
    expect(entry['rev'], hasLength(64));
    final practiceRev = ((manifest['practice'] as List).single as Map)['rev'];
    expect(practiceRev, endsWith(':fr'));
    // Another language list = another practice / exam rev (stored per rev).
    final again = await s.fetchManifest(3001, const ['ar', 'fr']);
    expect(
      ((again['practice'] as List).single as Map)['rev'],
      endsWith(':ar,fr'),
    );
    expect(((again['exams'] as List).single as Map)['rev'], endsWith(':ar,fr'));

    final lesson = await s.fetchLesson(11, const ['fr']);
    expect((lesson['i18n'] as Map).keys, ['fr']);
    expect((lesson['unit'] as Map)['title'], {'fr': 'U'});

    final extras = await s.fetchExtras(3001, const ['fr']);
    final word = (extras['glossary'] as List).single as Map;
    expect(word['fr'], 'mot');
    expect(word['ar'], isNull);
    expect(extras['resources'], hasLength(1));

    final practice = await s.fetchPractice(3001, 'ch1', const ['ar']);
    expect((practice.single as Map)['title'], {'ar': 'u'});
    final paper = await s.fetchPaper(4, const ['fr']);
    expect(paper['title'], {'fr': 't'});

    expect(supabase.calls, ['resources']);
    expect(breakerUntil, isNull);
  });

  test('no path, web, or content newer than the publish = Supabase', () async {
    path = null;
    expect((await source().fetchManifest(3001, const ['fr']))['source'], isNull);
    path = _manifest;
    expect(
      (await source(enabled: false).fetchManifest(3001, const ['fr']))['source'],
      isNull,
    );
    serverVersion = 8;
    final s = source();
    expect((await s.fetchManifest(3001, const ['fr']))['source'], isNull);
    // The lessons of a Supabase manifest are Supabase lessons.
    expect((await s.fetchLesson(11, const ['fr']))['from'], 'supabase');
    expect(cdn.asked, isEmpty);
    expect(breakerUntil, isNull);
  });

  test('a module that went back to Supabase forgets its files', () async {
    final s = source();
    await s.fetchManifest(3001, const ['fr']);
    expect(s.usesCdn(3001), isTrue);
    serverVersion = 8;
    await s.fetchManifest(3001, const ['fr']);
    expect(s.usesCdn(3001), isFalse);
    expect((await s.fetchLesson(11, const ['fr']))['from'], 'supabase');
    expect((await s.fetchPaper(4, const ['fr']))['from'], 'supabase');
  });

  test('a broken file falls back to Supabase for that request', () async {
    final s = source();
    final manifest = await s.fetchManifest(3001, const ['fr']);
    final lessonPath = ((manifest['lessons'] as List).single as Map)['path'];
    cdn.files['$lessonPath'] = Uint8List.fromList(utf8.encode('{"id":11}'));
    final lesson = await s.fetchLesson(11, const ['fr']);
    expect(lesson['from'], 'supabase');
    expect(breakerUntil, isNull, reason: 'one failure does not open it');
    // The other files still come from Cloudflare.
    expect((await s.fetchPaper(4, const ['fr']))['from'], isNull);
  });

  test('3 Cloudflare failures in a row pause it for 30 minutes', () async {
    final s = source();
    await s.fetchManifest(3001, const ['fr']);
    cdn.down = true;
    for (var i = 0; i < 3; i++) {
      expect((await s.fetchLesson(11, const ['fr']))['from'], 'supabase');
    }
    expect(breakerUntil, isNotNull);
    final asked = cdn.asked.length;
    cdn.down = false;
    await s.fetchLesson(11, const ['fr']);
    expect((await s.fetchManifest(3001, const ['fr']))['source'], isNull);
    expect(cdn.asked.length, asked, reason: 'not tried while paused');

    now = now.add(const Duration(minutes: 31));
    expect((await s.fetchManifest(3001, const ['fr']))['source'], 'cdn');
  });

  test('an offline phone does not count against Cloudflare', () async {
    final s = source();
    await s.fetchManifest(3001, const ['fr']);
    cdn.down = true;
    supabase.down = true;
    for (var i = 0; i < 5; i++) {
      await expectLater(s.fetchLesson(11, const ['fr']), throwsException);
    }
    await expectLater(s.fetchManifest(3001, const ['fr']), throwsException);
    expect(breakerUntil, isNull);
  });

  test('a missing manifest falls back and is counted', () async {
    cdn.files.remove(_manifest);
    final s = source();
    final manifest = await s.fetchManifest(3001, const ['fr']);
    expect(manifest['extras_rev'], 'supabase');
    expect(supabase.calls, ['manifest']);
    // Extras of a Supabase manifest carry their own resources.
    expect((await s.fetchExtras(3001, const ['fr']))['resources'], isEmpty);
  });

  test('library list down: the extras come without "resources"', () async {
    final s = source();
    await s.fetchManifest(3001, const ['fr']);
    supabase.down = true;
    final extras = await s.fetchExtras(3001, const ['fr']);
    expect(extras.containsKey('resources'), isFalse);
    expect(extras['glossary'], hasLength(1));
  });
}
