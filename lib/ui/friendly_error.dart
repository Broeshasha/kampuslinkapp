import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';
import '../l10n/app_localizations.dart';

/// Replaces Flutter's red error screen when a widget crashes while building.
/// Works even if translations or theme are missing at that point.
class FriendlyBuildError extends StatelessWidget {
  const FriendlyBuildError({super.key, this.details});

  final FlutterErrorDetails? details;

  @override
  Widget build(BuildContext context) {
    final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
    final kc = context.kc;
    return Directionality(
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
      child: ColoredBox(
        color: kc.surface,
        child: ClipRect(
          child: Padding(
            padding: const EdgeInsets.all(KSpace.lg),
            child: DefaultTextStyle(
              textAlign: TextAlign.center,
              style: TextStyle(
                color: kc.textSecondary,
                fontSize: 14,
                fontFamily: KFonts.family,
                decoration: TextDecoration.none,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sentiment_dissatisfied_outlined,
                    color: kc.warning,
                    size: 32,
                  ),
                  const SizedBox(height: KSpace.sm),
                  Text(
                    l10n?.errorTitle ?? 'Something went wrong',
                    style: TextStyle(
                      color: kc.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: KSpace.xs),
                  Text(
                    l10n?.errorUnknown ??
                        'Something unexpected happened. Try again.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
