import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_failure.dart';
import '../../core/errors/result.dart';
import '../../core/theme/tokens.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/states.dart';

/// "Report a mistake" on learning content (a carousel slide, a card):
/// optional details, then one row in reports (reason wrong_information).
Future<void> showReportMistake(
  BuildContext context,
  WidgetRef ref, {
  required String targetType,
  required String targetId,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final details = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _ReportSheet(),
  );
  if (details == null) return;
  final api = ref.read(kampusApiProvider);
  final r = api == null
      ? const Err<void>(OfflineFailure())
      : await guard(
          () => api.report(
            targetType: targetType,
            targetId: targetId,
            reason: 'wrong_information',
            details: details,
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
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet();

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
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
          const SizedBox(height: KSpace.md),
          TextField(
            controller: _text,
            maxLines: 4,
            maxLength: 1000,
            decoration: InputDecoration(
              labelText: l10n.reportDetails,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: KSpace.sm),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_text.text.trim()),
            child: Text(l10n.reportSend),
          ),
        ],
      ),
    );
  }
}
