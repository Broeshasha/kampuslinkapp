import 'package:flutter/material.dart';

import '../core/errors/app_failure.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';
import '../l10n/app_localizations.dart';
import 'max_width.dart';

/// Translated, friendly text for any failure.
String failureMessage(AppLocalizations l10n, AppFailure failure) =>
    switch (failure) {
      OfflineFailure() => l10n.errorOffline,
      UnauthenticatedFailure() => l10n.errorSession,
      OnboardingRequiredFailure() => l10n.errorSession,
      ForbiddenFailure() => l10n.errorForbidden,
      NotFoundFailure() => l10n.errorNotFound,
      RateLimitedFailure() => l10n.errorRateLimited,
      ValidationFailure(:final code) => '${l10n.errorUnknown} ($code)',
      ServerFailure() => l10n.errorServer,
      UnknownFailure(:final error) =>
        '${l10n.errorUnknown} (${error.runtimeType})',
    };

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: CircularProgressIndicator(
      semanticsLabel: AppLocalizations.of(context).loading,
    ),
  );
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    return _StateLayout(
      icon: icon,
      iconColor: context.kc.accentText,
      title: title,
      message: message,
      action: label != null && onAction != null
          ? FilledButton(onPressed: onAction, child: Text(label))
          : null,
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.failure, this.onRetry});

  final AppFailure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final offline = failure is OfflineFailure;
    return _StateLayout(
      icon: offline ? Icons.cloud_off_outlined : Icons.error_outline,
      iconColor: offline ? kc.textSecondary : kc.warning,
      title: l10n.errorTitle,
      message: failureMessage(l10n, failure),
      action: onRetry == null
          ? null
          : FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
    );
  }
}

class _StateLayout extends StatelessWidget {
  const _StateLayout({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = message;
    final button = action;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(KSpace.xl),
      child: MaxWidth(
        child: Column(
          children: [
            const SizedBox(height: KSpace.lg),
            Icon(icon, size: 56, color: iconColor),
            const SizedBox(height: KSpace.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (text != null) ...[
              const SizedBox(height: KSpace.sm),
              Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.kc.textSecondary),
              ),
            ],
            if (button != null) ...[const SizedBox(height: KSpace.xl), button],
          ],
        ),
      ),
    );
  }
}
