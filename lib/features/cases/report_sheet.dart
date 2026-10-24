import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/result.dart';
import '../../core/theme/tokens.dart';
import '../../data/providers.dart';
import '../../data/reports/content_reports.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/states.dart';

final contentReportsProvider = Provider<ContentReports>(
  (ref) => ContentReports(ref.watch(outboxRepositoryProvider)),
);

String reportReasonLabel(AppLocalizations l10n, String reason) =>
    switch (reason) {
      'wrong_answer' => l10n.reasonWrongAnswer,
      'typo' => l10n.reasonTypo,
      'unclear' => l10n.reasonUnclear,
      'translation' => l10n.reasonTranslation,
      _ => l10n.reportOther,
    };

/// "Report a mistake" on any content (contract 11, B4): 5 reasons + an
/// optional note, queued in the outbox (works offline), then a toast.
/// Never fails silently: a failure to queue shows its message.
Future<void> showReportMistake(
  BuildContext context,
  WidgetRef ref, {
  required String targetType,
  required String targetId,
  int? lessonId,
  String? notePrefix,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final answer = await showModalBottomSheet<(String, String)>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _ReportSheet(),
  );
  if (answer == null) return;
  final r = await guard(
    () => ref
        .read(contentReportsProvider)
        .report(
          targetType: targetType,
          targetId: targetId,
          lessonId: lessonId,
          reason: answer.$1,
          note: notePrefix == null
              ? answer.$2
              : [notePrefix, answer.$2].where((s) => s.isNotEmpty).join(': '),
        ),
  );
  messenger.showSnackBar(
    SnackBar(
      content: Text(switch (r) {
        Ok() => l10n.reportThanks,
        Err(:final failure) => failureMessage(l10n, failure),
      }),
    ),
  );
  if (r is Ok) {
    // Send it now when online; otherwise it leaves with the next sync.
    final sync = ref.read(outboxSyncProvider);
    if (sync != null) unawaited(guard(sync.flush));
  }
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet();

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _text = TextEditingController();
  String _reason = reportReasons.first;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        KSpace.lg,
        KSpace.lg,
        KSpace.lg,
        KSpace.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.reportMistake,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: KSpace.sm),
          RadioGroup<String>(
            groupValue: _reason,
            onChanged: (v) => setState(() => _reason = v ?? _reason),
            child: Column(
              children: [
                for (final r in reportReasons)
                  RadioListTile<String>(
                    value: r,
                    contentPadding: EdgeInsets.zero,
                    title: Text(reportReasonLabel(l10n, r)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: KSpace.sm),
          TextField(
            controller: _text,
            maxLines: 3,
            maxLength: ContentReports.maxNote,
            decoration: InputDecoration(
              labelText: l10n.reportDetails,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: KSpace.sm),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop((_reason, _text.text.trim())),
            child: Text(l10n.reportSend),
          ),
        ],
      ),
    );
  }
}
