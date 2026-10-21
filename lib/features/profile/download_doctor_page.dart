import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/max_width.dart';

/// One line of the check: what was tried, how long it took, what came back.
class DoctorLine {
  DoctorLine(this.step);

  final String step;
  bool? ok;
  String result = '...';
  int ms = 0;

  @override
  String toString() =>
      '[${ok == null ? '..' : (ok! ? 'OK' : 'FAIL')}] $step (${ms}ms): $result';
}

/// Describes an error with every field we have (no secrets: no keys, no
/// tokens are ever printed).
String describeError(Object e) {
  if (e is PostgrestException) {
    return 'PostgrestException code=${e.code} message=${e.message}'
        '${e.details == null ? '' : ' details=${e.details}'}'
        '${e.hint == null ? '' : ' hint=${e.hint}'}';
  }
  if (e is AuthException) {
    return 'AuthException status=${e.statusCode} message=${e.message}';
  }
  if (e is TimeoutException) return 'Timeout after ${e.duration?.inSeconds}s';
  final text = e.toString();
  return '${e.runtimeType}: ${text.length > 400 ? text.substring(0, 400) : text}';
}

/// "Download check": runs every step of a module download one by one and
/// shows exactly which one fails, with a Copy button (lead brief 2, B7:
/// "do not guess, show the Details").
class DownloadDoctorPage extends ConsumerStatefulWidget {
  const DownloadDoctorPage({super.key});

  @override
  ConsumerState<DownloadDoctorPage> createState() => _DownloadDoctorState();
}

class _DownloadDoctorState extends ConsumerState<DownloadDoctorPage> {
  final _lines = <DoctorLine>[];
  bool _running = false;

  String get _report => [
    'KampusLink download check ${DateTime.now().toUtc().toIso8601String()}',
    'platform=${kIsWeb ? 'web' : defaultTargetPlatform.name}',
    for (final l in _lines) l.toString(),
  ].join('\n');

  Future<T?> _step<T>(
    String name,
    Future<T> Function() run,
    String Function(T value) describe, {
    Duration limit = const Duration(seconds: 30),
  }) async {
    final line = DoctorLine(name);
    setState(() => _lines.add(line));
    final watch = Stopwatch()..start();
    try {
      final value = await run().timeout(limit);
      line
        ..ok = true
        ..result = describe(value);
      return value;
    } catch (e) {
      line
        ..ok = false
        ..result = describeError(e);
      return null;
    } finally {
      line.ms = watch.elapsedMilliseconds;
      if (mounted) setState(() {});
    }
  }

  int _kb(Object? v) => (utf8.encode(jsonEncode(v)).length / 1024).ceil();

  Future<void> _run() async {
    setState(() {
      _running = true;
      _lines.clear();
    });
    final db = ref.read(appDatabaseProvider);
    final client = ref.read(supabaseClientProvider);
    final api = ref.read(kampusApiProvider);

    await _step('local database (write + read)', () async {
      const key = 'doctor:test';
      final stamp = DateTime.now().toIso8601String();
      await db
          .into(db.keyValues)
          .insertOnConflictUpdate(
            KeyValuesCompanion(name: const Value(key), value: Value(stamp)),
          );
      final back = await (db.select(
        db.keyValues,
      )..where((t) => t.name.equals(key))).getSingleOrNull();
      await (db.delete(db.keyValues)..where((t) => t.name.equals(key))).go();
      if (back?.value != stamp) throw StateError('read back ${back?.value}');
      final lessons = await db.select(db.lessons).get();
      return lessons.length;
    }, (n) => 'works; $n lessons stored on this device');

    if (client == null || api == null) {
      setState(
        () => _lines.add(
          DoctorLine('server config')
            ..ok = false
            ..result = 'no Supabase URL / key in this build',
        ),
      );
      setState(() => _running = false);
      return;
    }
    final host = Uri.tryParse(client.rest.url)?.host ?? '?';
    await _step('server address', () async => host, (h) => h);

    final session = client.auth.currentSession;
    setState(
      () => _lines.add(
        DoctorLine('signed in')
          ..ok = session != null
          ..result = session == null
              ? 'NO session'
              : 'user ${session.user.id.substring(0, 8)}..., expires '
                    '${session.expiresAt == null ? '?' : DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000).toUtc().toIso8601String()}',
      ),
    );

    await _step(
      'get_me',
      api.getMe,
      (m) => m == null ? 'no profile row' : 'profile ok (${m.length} fields)',
    );

    final modules = await _step(
      'get_my_modules',
      api.getMyModules,
      (rows) =>
          '${rows.length} modules: ${[for (final r in rows) '${r['module_id']}(v${r['version']})'].join(', ')}',
    );
    final withContent = [
      for (final r in modules ?? const <Map<String, dynamic>>[])
        if ((r['version'] as num? ?? 0) > 0) r,
    ];
    if (withContent.isEmpty) {
      setState(() => _running = false);
      return;
    }
    final moduleId = (withContent.first['module_id'] as num).toInt();

    final manifest = await _step(
      'get_module_manifest($moduleId, fr)',
      () => api.getModuleManifest(moduleId, const ['fr']),
      (m) =>
          'v${m['version']}, ${(m['lessons'] as List?)?.length ?? 0} lessons, ${_kb(m)} KB',
    );
    final lessons = (manifest?['lessons'] as List?) ?? const [];
    if (lessons.isNotEmpty) {
      final lessonId = ((lessons.first as Map)['id'] as num).toInt();
      await _step(
        'get_lesson_bundle($lessonId, fr)',
        () => api.getLessonBundle(lessonId, const ['fr']),
        (l) => '${_kb(l)} KB',
      );
      await _step(
        'get_lesson_bundle($lessonId, ar+fr+en)',
        () => api.getLessonBundle(lessonId, const ['ar', 'fr', 'en']),
        (l) => '${_kb(l)} KB',
      );
    }
    if (manifest != null) {
      await _step(
        'get_module_extras($moduleId, fr)',
        () => api.getModuleExtras(moduleId, const ['fr']),
        (e) => '${_kb(e)} KB',
      );
    }
    await _step(
      'old get_module_bundle($moduleId, fr)',
      () => api.getModuleBundle(moduleId, const ['fr']),
      (b) => '${(b['lessons'] as List?)?.length ?? 0} lessons, ${_kb(b)} KB',
      limit: const Duration(seconds: 95),
    );
    if (mounted) setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dlRunCheck),
        actions: [
          if (_lines.isNotEmpty && !_running)
            IconButton(
              tooltip: l10n.dlCopy,
              icon: const Icon(Icons.copy_rounded),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _report));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(l10n.dlCopied)));
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(KSpace.lg),
        children: [
          MaxWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: _running ? null : _run,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(l10n.dlRunCheck),
                ),
                const SizedBox(height: KSpace.lg),
                for (final line in _lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: KSpace.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (line.ok == null)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Icon(
                            line.ok! ? Icons.check_circle : Icons.cancel,
                            size: 20,
                            color: line.ok! ? kc.success : kc.warning,
                          ),
                        const SizedBox(width: KSpace.sm),
                        Expanded(
                          child: SelectableText(
                            '${line.step}  (${line.ms} ms)\n${line.result}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
