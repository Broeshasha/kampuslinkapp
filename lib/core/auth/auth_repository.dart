import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_failure.dart';
import '../supabase/supabase_bootstrap.dart';

/// Public OAuth web client id: Supabase checks Google ID tokens against it.
const _googleServerClientId =
    '649045631810-bajsvemrs6bcec2f4jtu3gfc3bb68her.apps.googleusercontent.com';

/// Google sign-in only (D-001). Same flow as the Play build that works today.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient? _client;
  static bool _googleReady = false;

  Session? get session => _client?.auth.currentSession;

  Stream<Session?> sessionChanges() =>
      _client?.auth.onAuthStateChange.map((s) => s.session) ??
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

  Future<void> signOut() async {
    if (!kIsWeb && _googleReady) await GoogleSignIn.instance.signOut();
    await _client?.auth.signOut();
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);

final sessionProvider = StreamProvider<Session?>((ref) async* {
  final repo = ref.watch(authRepositoryProvider);
  yield repo.session;
  yield* repo.sessionChanges();
});

final isSignedInProvider = Provider<bool>(
  (ref) => switch (ref.watch(sessionProvider)) {
    AsyncData(:final value) => value != null,
    _ => false,
  },
);
