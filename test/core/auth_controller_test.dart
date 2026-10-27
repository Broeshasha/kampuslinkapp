import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/core/auth/auth_controller.dart';
import 'package:kampuslink/core/connectivity/connectivity.dart';
import 'package:kampuslink/core/errors/app_failure.dart';
import 'package:kampuslink/core/l10n/locale_controller.dart';
import 'package:kampuslink/features/onboarding/onboarding_status.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../helpers/fake_auth.dart';

const _rejected = AuthException(
  'Invalid Refresh Token: Refresh Token Not Found',
  statusCode: '400',
  code: 'refresh_token_not_found',
);

Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

ProviderContainer _container(FakeAuthGateway gateway, Stream<bool> online) {
  final container = ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(gateway),
      connectivityProvider.overrideWith((ref) => online),
    ],
  );
  container.listen(authControllerProvider, (_, _) {});
  addTearDown(container.dispose);
  return container;
}

void main() {
  test(
    'offline cold start with an expired access token stays signed in',
    () async {
      final gw = FakeAuthGateway(expiredUser);
      final c = _container(gw, Stream.value(false));
      expect(c.read(isSignedInProvider), isTrue);
      await _settle();
      expect(c.read(isSignedInProvider), isTrue);
      expect(c.read(authControllerProvider).expired, isTrue);
      expect(gw.refreshCalls, 0);
      expect(gw.signOutCalls, 0);
    },
  );

  test(
    'refresh failing with network errors keeps the student signed in',
    () async {
      final gw = FakeAuthGateway(expiredUser);
      final c = _container(gw, Stream.value(false));
      for (final error in <Object>[
        const SocketException('Failed host lookup: x.supabase.co'),
        TimeoutException('refresh'),
        const AuthException('Bad gateway', statusCode: '502'),
        const AuthException('Failed host lookup'),
      ]) {
        gw.fail(error);
        await _settle();
        expect(c.read(isSignedInProvider), isTrue, reason: '$error');
      }
      expect(gw.signOutCalls, 0);
    },
  );

  test(
    'connection back -> quiet refresh; a failing refresh stays signed in',
    () async {
      final gw = FakeAuthGateway(expiredUser)
        ..refreshError = const SocketException('Network is unreachable');
      final online = StreamController<bool>();
      addTearDown(online.close);
      final c = _container(gw, online.stream);
      online.add(false);
      await _settle();
      online.add(true);
      await _settle();
      expect(gw.refreshCalls, 1);
      expect(c.read(isSignedInProvider), isTrue);
      gw.refreshError = null;
      online.add(false);
      await _settle();
      online.add(true);
      await _settle();
      expect(gw.refreshCalls, 2);
      expect(c.read(authControllerProvider).expired, isFalse);
      expect(gw.signOutCalls, 0);
    },
  );

  test('rejected refresh token signs out exactly once', () async {
    final gw = FakeAuthGateway(expiredUser);
    final c = _container(gw, Stream.value(true));
    gw.fail(_rejected);
    gw.fail(_rejected);
    await _settle();
    expect(c.read(isSignedInProvider), isFalse);
    expect(gw.signOutCalls, 1);
  });

  test('the student tapping Sign out signs out', () async {
    final gw = FakeAuthGateway(expiredUser);
    final c = _container(gw, Stream.value(true));
    gw.emit(AuthView.signedOut);
    await _settle();
    expect(c.read(isSignedInProvider), isFalse);
  });

  test('only an explicit refresh-token rejection counts', () {
    expect(isRefreshTokenRejected(_rejected), isTrue);
    expect(
      isRefreshTokenRejected(
        const AuthException(
          'Invalid Refresh Token: Already Used',
          statusCode: '400',
        ),
      ),
      isTrue,
    );
    expect(isRefreshTokenRejected(const SocketException('x')), isFalse);
    expect(isRefreshTokenRejected(TimeoutException('x')), isFalse);
    expect(
      isRefreshTokenRejected(
        const AuthException('Invalid Refresh Token', statusCode: '503'),
      ),
      isFalse,
    );
    expect(
      isRefreshTokenRejected(const AuthException('Something else')),
      isFalse,
    );
  });

  test('get_me failing offline never routes to onboarding', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        authGatewayProvider.overrideWithValue(FakeAuthGateway(expiredUser)),
        connectivityProvider.overrideWith((ref) => Stream.value(false)),
        sharedPrefsProvider.overrideWithValue(prefs),
        meProvider.overrideWith((ref) async => throw const OfflineFailure()),
      ],
    );
    addTearDown(c.dispose);
    c.listen(onboardingStatusProvider, (_, _) {});
    await _settle();
    expect(c.read(meProvider).hasError, isTrue);
    expect(c.read(onboardingStatusProvider), OnboardingStatus.done);
  });
}
