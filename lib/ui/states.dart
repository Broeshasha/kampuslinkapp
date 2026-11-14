import 'dart:async';
import 'dart:math';

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

/// The spinner appears only if loading takes longer than a moment, so
/// screens drawn from the phone never flash a loading ring.
class LoadingView extends StatefulWidget {
  const LoadingView({super.key});

  @override
  State<LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<LoadingView> {
  Timer? _timer;
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() => _show = true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: _show
        ? CircularProgressIndicator(
            semanticsLabel: AppLocalizations.of(context).loading,
          )
        : const SizedBox.shrink(),
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

class ErrorView extends StatefulWidget {
  const ErrorView({super.key, required this.failure, this.onRetry});

  final AppFailure failure;
  final VoidCallback? onRetry;

  @override
  State<ErrorView> createState() => _ErrorViewState();
}

class _ErrorViewState extends State<ErrorView> {
  Timer? _timer;
  int _attempt = 0;

  /// A server problem on a screen that can retry: it retries by itself.
  bool get _busy => widget.failure is ServerFailure && widget.onRetry != null;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void didUpdateWidget(ErrorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _arm();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Waits a little longer each time (8 s up to 30 s) and a little differently
  /// on every phone, so a crowd of students never hits a recovering server
  /// at the same second.
  void _arm() {
    if (!_busy || (_timer?.isActive ?? false)) return;
    final seconds = min(8 + _attempt * 4, 30) + Random().nextInt(8);
    _timer = Timer(Duration(seconds: seconds), () {
      if (!mounted) return;
      _attempt++;
      widget.onRetry?.call();
      _arm();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final failure = widget.failure;
    final offline = failure is OfflineFailure;
    return _StateLayout(
      icon: offline
          ? Icons.cloud_off_outlined
          : _busy
          ? Icons.hourglass_top_rounded
          : Icons.error_outline,
      iconColor: offline
          ? kc.textSecondary
          : _busy
          ? kc.accentText
          : kc.warning,
      title: _busy ? l10n.errorServerBusyTitle : l10n.errorTitle,
      message: _busy ? l10n.errorServerBusyBody : failureMessage(l10n, failure),
      action: widget.onRetry == null
          ? null
          : FilledButton.icon(
              onPressed: widget.onRetry,
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
