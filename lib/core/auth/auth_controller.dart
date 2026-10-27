import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../connectivity/connectivity.dart';
import '../errors/network_errors.dart';
import '../logging/logger.dart';
import '../supabase/supabase_bootstrap.dart';

/// Who is signed in on THIS phone, decided from the session saved on the
/// phone, never from the network. [expired] = the access token is out of
/// date, which is normal offline: local screens keep working.
@immutable
class AuthView {
  const AuthView.user(String id, {this.email, this.expired = false})
    : userId = id;
  const AuthView._none() : userId = null, email = null, expired = false;

  static const signedOut = AuthView._none();

  factory AuthView.fromSession(Session? session) {
    if (session == null) return signedOut;
    final expiresAt = session.expiresAt;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return AuthView.user(
      session.user.id,
      email: session.user.email,
      expired: expiresAt != null && now >= expiresAt,
    );
  }

  final String? userId;
  final String? email;
  final bool expired;

  bool get signedIn => userId != null;

  @override
  bool operator ==(Object other) =>
      other is AuthView &&
      other.userId == userId &&
      other.email == email &&
      other.expired == expired;

  @override
  int get hashCode => Object.hash(userId, email, expired);

  @override
  String toString() =>
      signedIn ? 'AuthView($userId, expired: $expired)' : 'AuthView(signedOut)';
}

/// What the app needs from Supabase auth (a fake in tests).
/// [changes] may carry errors: a failed background token refresh.
abstract interface class AuthGateway {
  AuthView get current;
  Stream<AuthView> get changes;
  Future<void> refresh();
  Future<void> signOutLocal();
}

class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(this._auth);

  final GoTrueClient _auth;

  @override
  AuthView get current => AuthView.fromSession(_auth.currentSession);

  @override
  Stream<AuthView> get changes => _auth.onAuthStateChange.map(
    (s) => s.event == AuthChangeEvent.signedOut
        ? AuthView.signedOut
        : AuthView.fromSession(s.session ?? _auth.currentSession),
  );

  @override
  Future<void> refresh() async {
    await _auth.refreshSession();
  }

  @override
  Future<void> signOutLocal() => _auth.signOut(scope: SignOutScope.local);
}

const _rejectedCodes = {
  'refresh_token_not_found',
  'refresh_token_already_used',
  'session_not_found',
  'session_expired',
  'user_not_found',
  'user_banned',
};

/// true ONLY when Supabase explicitly refused the refresh token (revoked,
/// unknown, already used). Network errors, timeouts and 5xx are never this.
bool isRefreshTokenRejected(Object error) {
  if (error is! AuthException) return false;
  if (isNetworkError(error)) return false;
  final status = int.tryParse(error.statusCode ?? '') ?? 0;
  if (status >= 500 || status == 408 || status == 429) return false;
  if (_rejectedCodes.contains(error.code)) return true;
  final message = error.message.toLowerCase();
  return message.contains('refresh token') &&
      (message.contains('invalid') ||
          message.contains('not found') ||
          message.contains('revoked') ||
          message.contains('already used'));
}

final authGatewayProvider = Provider<AuthGateway?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabaseAuthGateway(client.auth);
});

/// Signs out only on (a) the student's own Sign out / delete account
/// (Supabase sends signedOut) or (b) a rejected refresh token. Any other
/// failure keeps the student in and retries quietly (backoff + when the
/// connection comes back).
class AuthController extends Notifier<AuthView> {
  static const _backoff = [
    Duration(seconds: 5),
    Duration(seconds: 20),
    Duration(minutes: 1),
    Duration(minutes: 5),
  ];

  AuthGateway? _gateway;
  Timer? _retryTimer;
  int _failures = 0;

  @override
  AuthView build() {
    final gateway = ref.watch(authGatewayProvider);
    _gateway = gateway;
    if (gateway == null) return AuthView.signedOut;
    final sub = gateway.changes.listen(_onView, onError: _handleError);
    ref.listen<bool>(isOnlineProvider, (previous, next) {
      if (previous == false && next && (state.expired || _failures > 0)) {
        unawaited(_retryNow());
      }
    });
    ref.onDispose(() {
      sub.cancel();
      _retryTimer?.cancel();
    });
    return gateway.current;
  }

  void _onView(AuthView next) {
    if (!ref.mounted) return;
    if (!next.expired) _failures = 0;
    state = next;
  }

  void _handleError(Object error, StackTrace stack) {
    if (!ref.mounted) return;
    if (isRefreshTokenRejected(error)) {
      unawaited(_forceSignOut());
      return;
    }
    _failures++;
    appLog.warn(
      'auth: refresh failed, staying signed in (${error.runtimeType})',
    );
    _retryTimer?.cancel();
    final delay = _backoff[math.min(_failures - 1, _backoff.length - 1)];
    _retryTimer = Timer(delay, () => unawaited(_retryNow()));
  }

  Future<void> _retryNow() async {
    _retryTimer?.cancel();
    final gateway = _gateway;
    if (gateway == null || !ref.mounted || !state.signedIn) return;
    if (!ref.read(isOnlineProvider))
      return; // the connectivity listener retries
    try {
      await gateway.refresh();
      _failures = 0;
      if (ref.mounted) state = gateway.current;
    } catch (error, stack) {
      _handleError(error, stack);
    }
  }

  Future<void> _forceSignOut() async {
    if (!state.signedIn) return; // exactly once
    appLog.warn('auth: refresh token rejected by Supabase, signing out');
    _retryTimer?.cancel();
    _failures = 0;
    state = AuthView.signedOut;
    try {
      await _gateway?.signOutLocal();
    } catch (error, stack) {
      appLog.error(error, stack, reason: 'auth sign-out');
    }
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthView>(
  AuthController.new,
);

/// Synchronous from the first frame: no loading state, no network.
final isSignedInProvider = Provider<bool>(
  (ref) => ref.watch(authControllerProvider.select((a) => a.signedIn)),
);
