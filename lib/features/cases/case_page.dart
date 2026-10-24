import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/result.dart';
import '../../core/theme/tokens.dart';
import '../../data/cases/case_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/max_width.dart';
import '../../ui/states.dart';
import 'case_models.dart';
import 'case_set_view.dart';
import 'report_sheet.dart';

/// "Continue the case": one carousel set full screen, back where you were.
class CasePage extends ConsumerWidget {
  const CasePage({super.key, required this.setId});

  final String setId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final sources = switch (ref.watch(caseSourcesProvider)) {
      AsyncData(:final value) => value,
      AsyncError() => const <CaseSource>[],
      _ => null,
    };
    final progress = switch (ref.watch(caseProgressProvider)) {
      AsyncData(:final value) => value,
      _ => null,
    };
    if (sources == null || progress == null) {
      return const Scaffold(body: LoadingView());
    }
    CaseSource? found;
    for (final s in sources) {
      if (s.id == setId) found = s;
    }
    if (found == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyView(icon: Icons.search_off, title: l10n.errorNotFound),
      );
    }
    final set = CaseSet.fromSource(found.source, lang);
    return Scaffold(
      appBar: AppBar(title: Text(set.title)),
      body: SafeArea(
        child: MaxWidth(
          child: CaseSetView(
            set: set,
            demo: found.moduleId == null,
            accent: found.moduleId == null
                ? null
                : moduleAccent(found.moduleId!),
            progress: progress[set.id] ?? CaseProgress(setId: set.id),
            onProgress: (p) =>
                guard(() => ref.read(caseRepositoryProvider).save(p)),
            onNext: () => Navigator.of(context).maybePop(),
            onReport: (_) => showReportMistake(
              context,
              ref,
              targetType: 'set',
              targetId: set.id,
              lessonId: set.lessonId,
            ),
          ),
        ),
      ),
    );
  }
}
