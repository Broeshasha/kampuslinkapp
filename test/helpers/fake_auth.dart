import 'dart:async';

import 'package:kampuslink/core/auth/auth_controller.dart';

/// Stands in for Supabase auth: a session "saved on the phone", events,
/// refresh errors on demand, and counters.
class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway(this.current);

  @override
  AuthView current;

  final _events = StreamController<AuthView>.broadcast();
  Object? refreshError;
  int refreshCalls = 0;
  int signOutCalls = 0;

  @override
  Stream<AuthView> get changes => _events.stream;

  void emit(AuthView view) {
    current = view;
    _events.add(view);
  }

  /// What supabase_flutter does when its background refresh fails.
  void fail(Object error) => _events.addError(error);

  @override
  Future<void> refresh() async {
    refreshCalls++;
    final error = refreshError;
    if (error != null) throw error;
    emit(AuthView.user(current.userId!, email: current.email));
  }

  @override
  Future<void> signOutLocal() async {
    signOutCalls++;
    emit(AuthView.signedOut);
  }
}

const expiredUser = AuthView.user('u1', email: 'a@b.dz', expired: true);
