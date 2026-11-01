import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../render/code_block.dart' show codeFontFamily, codeFontFallback;
import '../../render/math_audit.dart';

Object? _decode(String? s) {
  if (s == null || s.isEmpty) return null;
  final t = s.trimLeft();
  if (!t.startsWith('{') && !t.startsWith('[')) return s;
  try {
    return jsonDecode(s);
  } catch (_) {
    return s;
  }
}

/// Scans every downloaded module, lesson, card, question, glossary entry,
/// file title and stored set / practice / exam (key-values) for formulas
/// that cannot be drawn. [onProgress] gets the number of items checked.
Future<List<MathIssue>> runMathAudit(
  AppDatabase db, {
  void Function(int checked)? onProgress,
}) async {
  final out = <MathIssue>[];
  var checked = 0;
  Future<void> tick() async {
    checked++;
    if (checked % 25 == 0) {
      onProgress?.call(checked);
      await Future<void>.delayed(Duration.zero);
    }
  }

  for (final m in await db.select(db.modules).get()) {
    out.addAll(auditJson(m.name, where: 'module name', moduleId: m.id));
    await tick();
  }
  for (final l in await db.select(db.lessons).get()) {
    out.addAll(
      auditJson(
        {'i18n': _decode(l.i18nJson), 'unit': _decode(l.unitJson)},
        where: 'lesson ${l.id}',
        moduleId: l.moduleId,
      ),
    );
    await tick();
  }
  for (final c in await db.select(db.cards).get()) {
    out.addAll(
      auditJson(
        _decode(c.i18nJson),
        where: 'card ${c.id}',
        moduleId: c.moduleId,
      ),
    );
    await tick();
  }
  for (final q in await db.select(db.questions).get()) {
    out.addAll(
      auditJson(
        _decode(q.i18nJson),
        where: 'question ${q.id}',
        moduleId: q.moduleId,
      ),
    );
    await tick();
  }
  for (final g in await db.select(db.glossaryEntries).get()) {
    out.addAll(
      auditJson(
        {
          'fr': g.fr,
          'ar': g.ar,
          'en': g.en,
          'definition': _decode(g.definitionJson),
        },
        where: 'glossary ${g.id}',
        moduleId: g.moduleId,
      ),
    );
    await tick();
  }
  for (final r in await db.select(db.resources).get()) {
    out.addAll(auditJson(r.title, where: 'file ${r.id}', moduleId: r.moduleId));
    await tick();
  }
  for (final kv in await db.select(db.keyValues).get()) {
    final v = _decode(kv.value);
    if (v is Map || v is List) {
      out.addAll(auditJson(v, where: 'stored ${kv.name}'));
    }
    await tick();
  }
  onProgress?.call(checked);
  return out;
}

/// DEBUG: Profile > Math audit. Lists every formula that cannot be drawn
/// (module, item, path, formula, error) with Copy, for the content lead.
class MathAuditPage extends ConsumerStatefulWidget {
  const MathAuditPage({super.key});

  @override
  ConsumerState<MathAuditPage> createState() => _MathAuditPageState();
}

class _MathAuditPageState extends ConsumerState<MathAuditPage> {
  List<MathIssue>? _issues;
  Object? _error;
  int _checked = 0;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _issues = null;
      _error = null;
      _checked = 0;
    });
    try {
      final issues = await runMathAudit(
        ref.read(appDatabaseProvider),
        onProgress: (n) {
          if (mounted) setState(() => _checked = n);
        },
      );
      if (mounted) setState(() => _issues = issues);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Copied')));
  }

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final issues = _issues;
    final mono = TextStyle(
      fontFamily: codeFontFamily,
      fontFamilyFallback: codeFontFallback,
      fontSize: 13,
      color: kc.textPrimary,
    );
    final Widget body;
    if (_error != null) {
      body = Center(child: Text('Audit failed: $_error'));
    } else if (issues == null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: KSpace.md),
            Text('Checked $_checked items...'),
          ],
        ),
      );
    } else if (issues.isEmpty) {
      body = Center(
        child: Text('No broken formulas ($_checked items checked).'),
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.all(KSpace.md),
        itemCount: issues.length + 1,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: KSpace.sm),
              child: Text(
                '${issues.length} problems in $_checked items. '
                'Tap one to copy it, or Copy all above.',
                style: TextStyle(color: kc.textSecondary),
              ),
            );
          }
          final it = issues[i - 1];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Directionality(
              textDirection: TextDirection.ltr,
              child: Text(it.formula, style: mono),
            ),
            subtitle: Text(
              'module ${it.moduleId ?? '-'} - ${it.where} - ${it.path}\n'
              '${it.error}',
            ),
            onTap: () => _copy(it.toLine()),
          );
        },
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Math audit (debug)'),
        actions: [
          IconButton(
            tooltip: 'Run again',
            icon: const Icon(Icons.refresh),
            onPressed: issues == null ? null : _run,
          ),
          IconButton(
            tooltip: 'Copy all',
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: issues == null || issues.isEmpty
                ? null
                : () => _copy(issues.map((e) => e.toLine()).join('\n')),
          ),
        ],
      ),
      body: SafeArea(child: body),
    );
  }
}
