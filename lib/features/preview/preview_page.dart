import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/failure_mapper.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/logging/logger.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/db/app_database.dart';
import '../../data/learning/learning_providers.dart';
import '../../data/lessons/lesson_content.dart';
import '../../data/profile/me_values.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../render/lesson_view.dart';
import '../../ui/max_width.dart';
import '../../ui/states.dart';
import '../cases/case_models.dart';
import '../cases/case_set_view.dart';

const _prefKey = 'preview_drafts';

/// Profile > "Preview drafts" (admins only, contract 11 B5).
class PreviewDrafts extends Notifier<bool> {
  @override
  bool build() {
    final admin = isAdmin(ref.watch(serverStatsProvider).value);
    return admin && (ref.watch(sharedPrefsProvider).getBool(_prefKey) ?? false);
  }

  Future<void> set({required bool on}) async {
    await ref.read(sharedPrefsProvider).setBool(_prefKey, on);
    state = on && isAdmin(ref.read(serverStatsProvider).value);
  }
}

final previewDraftsProvider = NotifierProvider<PreviewDrafts, bool>(
  PreviewDrafts.new,
);

List<Map<String, dynamic>> _maps(Object? v) => [
  if (v is List)
    for (final e in v)
      if (e is Map) e.cast<String, dynamic>(),
];

/// Ids in the preview bundle that the student copy does not have = drafts.
Set<String> draftIds(
  Iterable<Object?> previewIds,
  Iterable<Object?> studentIds,
) {
  final student = {for (final id in studentIds) '$id'};
  return {
    for (final id in previewIds)
      if (!student.contains('$id')) '$id',
  };
}

/// The preview bundle of one module, kept under its OWN key
/// (`preview_bundle:<id>`) so it never replaces the student copy.
final previewBundleProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, int>((ref, moduleId) async {
      final db = ref.watch(appDatabaseProvider);
      final key = 'preview_bundle:$moduleId';
      final api = ref.watch(kampusApiProvider);
      try {
        if (api == null) throw StateError('offline');
        final bundle = await api.getModuleBundlePreview(moduleId, const [
          'ar',
          'fr',
          'en',
        ]);
        await db
            .into(db.keyValues)
            .insertOnConflictUpdate(
              KeyValuesCompanion(
                name: Value(key),
                value: Value(jsonEncode(bundle)),
              ),
            );
        return bundle;
      } catch (error) {
        appLog.info('preview offline: $error');
        final row = await (db.select(
          db.keyValues,
        )..where((t) => t.name.equals(key))).getSingleOrNull();
        if (row == null) rethrow;
        final v = jsonDecode(row.value);
        return v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};
      }
    });

/// Draft preview of a module: every lesson and set, drafts marked DRAFT.
class PreviewModulePage extends ConsumerWidget {
  const PreviewModulePage({super.key, required this.moduleId});

  final int moduleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final lang = Localizations.localeOf(context).languageCode;
    final db = ref.watch(appDatabaseProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.previewTitle)),
      body: switch (ref.watch(previewBundleProvider(moduleId))) {
        AsyncData(:final value) => FutureBuilder<(Set<String>, Set<String>)>(
          future: () async {
            final lessons = await (db.select(
              db.lessons,
            )..where((t) => t.moduleId.equals(moduleId))).get();
            final sets = await (db.select(
              db.keyValues,
            )..where((t) => t.name.equals('sets:$moduleId'))).getSingleOrNull();
            final setIds = <Object?>[];
            if (sets != null) {
              final v = jsonDecode(sets.value);
              if (v is List) {
                for (final s in v) {
                  if (s is Map) setIds.add(s['id']);
                }
              }
            }
            return (
              draftIds(
                _maps(value['lessons']).map((l) => l['id']),
                lessons.map((l) => l.id),
              ),
              draftIds(_maps(value['sets']).map((s) => s['id']), setIds),
            );
          }(),
          builder: (context, snap) {
            final drafts = snap.data;
            if (drafts == null) return const LoadingView();
            final lessons = _maps(value['lessons'])
              ..sort(
                (a, b) => ((a['position'] as num?) ?? 0).compareTo(
                  (b['position'] as num?) ?? 0,
                ),
              );
            final sets = _maps(value['sets']);
            Widget badge() => Container(
              padding: const EdgeInsets.symmetric(
                horizontal: KSpace.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: kc.warning.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(KRadius.chip),
              ),
              child: Text(
                l10n.draftBadge,
                style: TextStyle(
                  color: kc.warning,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            );
            return ListView(
              padding: const EdgeInsets.all(KSpace.lg),
              children: [
                for (final l in lessons)
                  MaxWidth(
                    child: ListTile(
                      title: Text(
                        LessonContent.of(_row(moduleId, l), lang).title,
                      ),
                      trailing: drafts.$1.contains('${l['id']}')
                          ? badge()
                          : null,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _PreviewLessonPage(
                            row: _row(moduleId, l),
                            draft: drafts.$1.contains('${l['id']}'),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (sets.isNotEmpty) const Divider(),
                for (final s in sets)
                  MaxWidth(
                    child: ListTile(
                      leading: const Icon(Icons.view_carousel_outlined),
                      title: Text(CaseSet.fromSource(s, lang).title),
                      trailing: drafts.$2.contains('${s['id']}')
                          ? badge()
                          : null,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _PreviewSetPage(
                            set: CaseSet.fromSource(s, lang),
                            draft: drafts.$2.contains('${s['id']}'),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        AsyncError(:final error) => ErrorView(
          failure: mapError(error),
          onRetry: () => ref.invalidate(previewBundleProvider(moduleId)),
        ),
        _ => const LoadingView(),
      },
    );
  }
}

LessonRow _row(int moduleId, Map<String, dynamic> l) => LessonRow(
  id: (l['id'] as num?)?.toInt() ?? 0,
  moduleId: moduleId,
  position: (l['position'] as num?)?.toInt() ?? 0,
  sourceLang: l['source_lang'] as String?,
  unitJson: l['unit'] == null ? null : jsonEncode(l['unit']),
  i18nJson: jsonEncode(l['i18n'] ?? const {}),
  resourceLinksJson: '[]',
);

class _PreviewLessonPage extends StatelessWidget {
  const _PreviewLessonPage({required this.row, required this.draft});

  final LessonRow row;
  final bool draft;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final content = LessonContent.of(
      row,
      Localizations.localeOf(context).languageCode,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          draft ? '${l10n.draftBadge} \u00b7 ${content.title}' : content.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: LessonView(
        blocks: content.blocks,
        language: supportedLanguageCodes.contains(content.language)
            ? content.language
            : fallbackLanguageCode,
      ),
    );
  }
}

class _PreviewSetPage extends StatefulWidget {
  const _PreviewSetPage({required this.set, required this.draft});

  final CaseSet set;
  final bool draft;

  @override
  State<_PreviewSetPage> createState() => _PreviewSetPageState();
}

class _PreviewSetPageState extends State<_PreviewSetPage> {
  late CaseProgress _progress = CaseProgress(setId: widget.set.id);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.set.title)),
      body: SafeArea(
        child: MaxWidth(
          child: CaseSetView(
            set: widget.set,
            badge: widget.draft ? l10n.draftBadge : null,
            progress: _progress,
            // Preview only: nothing is saved or sent.
            onProgress: (p) => _progress = p,
          ),
        ),
      ),
    );
  }
}

/// Profile: the "Preview drafts" switch, shown to admins only.
class PreviewDraftsTile extends ConsumerWidget {
  const PreviewDraftsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isAdmin(ref.watch(serverStatsProvider).value)) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    return Padding(
      padding: const EdgeInsets.only(top: KSpace.md),
      child: Material(
        color: kc.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KRadius.card),
          side: BorderSide(color: kc.warning.withValues(alpha: 0.6)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SwitchListTile(
          secondary: Icon(Icons.drafts_outlined, color: kc.warning),
          title: Text(l10n.previewDrafts),
          subtitle: Text(l10n.previewDraftsHelp),
          value: ref.watch(previewDraftsProvider),
          onChanged: (on) =>
              ref.read(previewDraftsProvider.notifier).set(on: on),
        ),
      ),
    );
  }
}
