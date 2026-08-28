import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final _supabase = Supabase.instance.client;
  static bool _googleInitialized = false;

  // v7+ of google_sign_in uses a singleton, not a constructor.
  // Must call .initialize() once before .authenticate() will work.
  static Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: '649045631810-bajsvemrs6bcec2f4jtu3gfc3bb68her.apps.googleusercontent.com',
    );
    _googleInitialized = true;
  }

  static Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: Uri.base.origin,
      );
    } else {
      await _ensureGoogleInitialized();

      final googleUser = await GoogleSignIn.instance.authenticate();

      // authentication is now synchronous (no await) in v7+
      final idToken = googleUser.authentication.idToken;
      if (idToken == null) {
        throw Exception('No ID token received from Google');
      }

      // Access token comes from a separate authorization call in v7+
      final authorization =
          await googleUser.authorizationClient.authorizationForScopes([]);

      await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: authorization?.accessToken,
      );
    }
  }

  static Future<void> signOut() async {
    if (!kIsWeb && _googleInitialized) {
      await GoogleSignIn.instance.signOut();
    }
    await _supabase.auth.signOut();
  }

  static User? get currentUser => _supabase.auth.currentUser;

  static Stream<AuthState> get authStateChanges =>
      _supabase.auth.onAuthStateChange;
}
