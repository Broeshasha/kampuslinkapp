import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/connectivity/connectivity.dart';
import '../../core/errors/failure_mapper.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/db/app_database.dart';
import '../../data/profile/study_level.dart';
import '../../data/providers.dart';
import '../../data/sync/sync_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/max_width.dart';
import '../../ui/states.dart';
import '../../ui/sync_chip.dart';
import '../auth/google_sign_in_button.dart';
import '../profile/semester_sheet.dart';
import 'module_card.dart';

/// Modules tab: reads ONLY the local database; pull down = sync.
class ModulesPage extends ConsumerWidget {
  const ModulesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final signedIn = ref.watch(isSignedInProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabModules), actions: const [SyncChip()]),
      body: signedIn ? const _ModulesBody() : const _SignInPrompt(),
    );
  }
}

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(KSpace.xl),
      child: MaxWidth(
        child: Column(
          children: [
            const SizedBox(height: KSpace.lg),
            Icon(
              Icons.cloud_download_outlined,
              size: 56,
              color: context.kc.accentText,
            ),
            const SizedBox(height: KSpace.lg),
            Text(
              l10n.signInToSeeModules,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: KSpace.xl),
            const GoogleSignInButton(),
          ],
        ),
      ),
    );
  }
}

class _ModulesBody extends ConsumerWidget {
  const _ModulesBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final modules = ref.watch(visibleModulesProvider);
    final sync = ref.watch(syncControllerProvider);
    final online = ref.watch(isOnlineProvider);
    Future<void> refresh() =>
        ref.read(syncControllerProvider.notifier).syncNow();
    return modules.when(
      loading: () => const LoadingView(),
      error: (error, stack) => ErrorView(
        failure: mapError(error),
        onRetry: () => ref.invalidate(modulesStreamProvider),
      ),
      data: (list) {
        if (list.isEmpty) {
          if (sync.running) return const LoadingView();
          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: 420,
                  child: EmptyView(
                    icon: Icons.menu_book_outlined,
                    title: l10n.noModulesTitle,
                    message: online
                        ? l10n.noModulesOnline
                        : l10n.noModulesOffline,
                    actionLabel: l10n.retry,
                    onAction: refresh,
                  ),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: refresh,
          child: _ModuleList(modules: list, downloading: sync.downloading),
        );
      },
    );
  }
}

class _ModuleList extends ConsumerWidget {
  const _ModuleList({required this.modules, required this.downloading});

  final List<ModuleRow> modules;
  final Set<int> downloading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final headerStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
      color: context.kc.textSecondary,
      fontWeight: FontWeight.w700,
    );
    // WP17-A: only the current semester's modules reach this list.
    final semester = ref.watch(currentSemesterProvider);
    final children = <Widget>[
      Padding(
        padding: const EdgeInsetsDirectional.only(
          top: KSpace.lg,
          bottom: KSpace.sm,
          start: KSpace.xs,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                semester == null
                    ? l10n.tabModules
                    : l10n.semesterThis(semester),
                style: headerStyle,
              ),
            ),
            TextButton(
              onPressed: () => showStudyLevelSheet(context, ref),
              child: Text(l10n.studyLevelChange),
            ),
          ],
        ),
      ),
      for (final m in modules)
        Padding(
          padding: const EdgeInsets.only(bottom: KSpace.md),
          child: ModuleCard(module: m, downloading: downloading.contains(m.id)),
        ),
    ];
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(KSpace.lg, 0, KSpace.lg, KSpace.xxl),
      children: [for (final c in children) MaxWidth(child: c)],
    );
  }
}
