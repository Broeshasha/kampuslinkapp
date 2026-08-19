import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final _supabase = Supabase.instance.client;

  static Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        // Auto-detects whatever origin is currently running —
        // localhost:XXXX in dev, kampus-link.com in production.
        // Never needs manual swapping again.
        redirectTo: Uri.base.origin,
      );
    } else {
      throw UnimplementedError('Native Google Sign-In not yet configured');
    }
  }

  static Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  static User? get currentUser => _supabase.auth.currentUser;

  static Stream<AuthState> get authStateChanges =>
      _supabase.auth.onAuthStateChange;
}