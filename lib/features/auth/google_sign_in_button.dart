import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/errors/failure_mapper.dart';
import '../../core/logging/logger.dart';
import '../../core/theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/states.dart';

/// Temporary sign-in button (the full onboarding comes in WP7).
/// Cancelling is not an error; any real failure shows a friendly message.
class GoogleSignInButton extends ConsumerStatefulWidget {
  const GoogleSignInButton({super.key});

  @override
  ConsumerState<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends ConsumerState<GoogleSignInButton> {
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } on GoogleSignInException catch (error, stack) {
      if (error.code != GoogleSignInExceptionCode.canceled) {
        _fail(error, stack);
      }
    } catch (error, stack) {
      _fail(error, stack);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fail(Object error, StackTrace stack) {
    appLog.error(error, stack, reason: 'google sign-in');
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(failureMessage(l10n, mapError(error)))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FilledButton(
      onPressed: _busy ? null : _signIn,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_busy)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            const Icon(Icons.login),
          const SizedBox(width: KSpace.sm),
          Flexible(
            child: Text(l10n.continueWithGoogle, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}
