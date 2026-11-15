import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/push/push_registration.dart';
import '../errors/app_failure.dart';
import '../logging/logger.dart';
import '../supabase/supabase_bootstrap.dart';

export 'auth_controller.dart'
    show AuthView, authControllerProvider, isSignedInProvider;

/// Public OAuth web client id: Supabase checks Google ID tokens against it.
const _googleServerClientId =
    '649045631810-bajsvemrs6bcec2f4jtu3gfc3bb68her.apps.googleusercontent.com';

/// Google sign-in only (D-001). Same flow as the Play build that works today.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient? _client;
  static bool _googleReady = false;

  /// The session saved on the phone (may have an expired access token).
  Session? get session => _client?.auth.currentSession;

  /// Session changes; refresh errors are dropped here (AuthController
  /// decides what they mean).
  Stream<Session?> sessionChanges() =>
      _client?.auth.onAuthStateChange
          .map((s) => s.session)
          .handleError((Object _) {}) ??
      const Stream<Session?>.empty();

  Future<void> signInWithGoogle() async {
    final client = _client;
    if (client == null) throw const ServerFailure('supabase_not_ready');
    if (kIsWeb) {
      await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: '${Uri.base.origin}/',
      );
      return;
    }
    if (!_googleReady) {
      await GoogleSignIn.instance.initialize(
        serverClientId: _googleServerClientId,
      );
      _googleReady = true;
    }
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) throw const UnauthenticatedFailure();
    await client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
  }

  /// The student's own Sign out: works offline too (falls back to ending
  /// the session on this phone only).
  Future<void> signOut() async {
    if (!kIsWeb && _googleReady) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (error, stack) {
        appLog.error(error, stack, reason: 'google sign-out');
      }
    }
    final auth = _client?.auth;
    if (auth == null) return;
    // MOT-3: this phone stops getting pushes for the account that leaves.
    if (auth.currentSession != null) {
      await dropPushToken(
        (token) async {
          await _client!.rpc(
            'unregister_push_token',
            params: {'p_token': token},
          );
        },
      );
    }
    try {
      await auth.signOut();
    } catch (error) {
      appLog.warn('auth: global sign-out failed ($error), local only');
      await auth.signOut(scope: SignOutScope.local);
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);

/// Only for display (e-mail in Profile). Never errors.
final sessionProvider = StreamProvider<Session?>((ref) async* {
  final repo = ref.watch(authRepositoryProvider);
  yield repo.session;
  yield* repo.sessionChanges();
});
