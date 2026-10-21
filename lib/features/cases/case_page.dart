import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/result.dart';
import '../../data/cases/case_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/max_width.dart';
import '../../ui/states.dart';
import 'case_models.dart';
import 'case_set_view.dart';
import 'demo_cases.dart';

/// "Continue the case": one carousel set full screen, back where you were.
class CasePage extends ConsumerWidget {
  const CasePage({super.key, required this.setId});

  final String setId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    Map<String, Object?>? source;
    for (final s in demoCases) {
      if ('${s['id']}' == setId) source = s;
    }
    final found = source;
    if (found == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyView(icon: Icons.search_off, title: l10n.errorNotFound),
      );
    }
    final set = CaseSet.fromSource(found, lang);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.caseLabel)),
      body: switch (ref.watch(caseProgressProvider)) {
        AsyncData(:final value) => SafeArea(
          child: MaxWidth(
            child: CaseSetView(
              set: set,
              demo: kShowDemoCases,
              progress: value[set.id] ?? CaseProgress(setId: set.id),
              onProgress: (p) =>
                  guard(() => ref.read(caseRepositoryProvider).save(p)),
            ),
          ),
        ),
        _ => const LoadingView(),
      },
    );
  }
}
