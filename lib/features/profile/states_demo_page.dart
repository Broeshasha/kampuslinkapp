import 'package:flutter/material.dart';

import '../../core/errors/app_failure.dart';
import '../../core/theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/states.dart';

/// DEBUG ONLY (reached from Profile in debug runs): shows every UI state.
class StatesDemoPage extends StatefulWidget {
  const StatesDemoPage({super.key});

  @override
  State<StatesDemoPage> createState() => _StatesDemoPageState();
}

class _StatesDemoPageState extends State<StatesDemoPage> {
  bool _crash = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('UI states (debug)')),
      body: ListView(
        children: [
          const SizedBox(height: 160, child: LoadingView()),
          const Divider(),
          SizedBox(
            height: 320,
            child: EmptyView(
              icon: Icons.inbox_outlined,
              title: l10n.comingSoon,
              message: l10n.modulesPlaceholder,
            ),
          ),
          const Divider(),
          SizedBox(
            height: 380,
            child: ErrorView(
              failure: const OfflineFailure(),
              onRetry: () =>
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(l10n.retry))),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(KSpace.lg),
            child: OutlinedButton(
              onPressed: () => setState(() => _crash = !_crash),
              child: const Text('Toggle a crash in build'),
            ),
          ),
          if (_crash) const SizedBox(height: 160, child: _Crash()),
        ],
      ),
    );
  }
}

class _Crash extends StatelessWidget {
  const _Crash();

  @override
  Widget build(BuildContext context) =>
      throw StateError('Demo crash: this box must look friendly, not red');
}
