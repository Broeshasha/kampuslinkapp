import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kampuslink/core/errors/app_failure.dart';
import 'package:kampuslink/core/errors/failure_mapper.dart';
import 'package:kampuslink/core/errors/result.dart';
import 'package:kampuslink/core/logging/logger.dart';
import 'package:kampuslink/ui/friendly_error.dart';
import 'package:kampuslink/ui/states.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/pump_in_app.dart';

PostgrestException pg(String message, [String code = 'P0001']) =>
    PostgrestException(message: message, code: code);

class _FakeSink implements CrashSink {
  final records = <Object>[];

  @override
  void record(
    Object error,
    StackTrace? stack, {
    required bool fatal,
    String? reason,
  }) => records.add(error);

  @override
  void log(String message) {}
}

class _Crash extends StatelessWidget {
  const _Crash();

  @override
  Widget build(BuildContext context) => throw StateError('boom');
}

void main() {
  test('our database codes become typed failures', () {
    expect(mapError(pg('not_authenticated')), isA<UnauthenticatedFailure>());
    expect(mapError(pg('rate_limited')), isA<RateLimitedFailure>());
    expect(mapError(pg('card_not_available')), isA<NotFoundFailure>());
    expect(mapError(pg('forbidden')), isA<ForbiddenFailure>());
    final v = mapError(pg('username_taken'));
    expect(v, isA<ValidationFailure>());
    expect((v as ValidationFailure).code, 'username_taken');
  });

  test('row security denial is Forbidden, other db errors are Server', () {
    expect(
      mapError(pg('permission denied for table profiles', '42501')),
      isA<ForbiddenFailure>(),
    );
    expect(mapError(pg('boom', 'XX000')), isA<ServerFailure>());
  });

  test('network problems are Offline; anything else is Unknown', () {
    expect(mapError(TimeoutException('slow')), isA<OfflineFailure>());
    expect(mapError(http.ClientException('no route')), isA<OfflineFailure>());
    expect(mapError(StateError('x')), isA<UnknownFailure>());
  });

  test('guard returns Ok or Err and logs real errors to the sink', () async {
    final sink = _FakeSink();
    appLog.sink = sink;
    addTearDown(() => appLog.sink = null);
    final ok = await guard(() async => 42);
    expect((ok as Ok<int>).value, 42);
    final err = await guard<int>(() async => throw pg('rate_limited'));
    expect((err as Err<int>).failure, isA<RateLimitedFailure>());
    expect(sink.records.single, isA<PostgrestException>());
    expect(appLog.recent.last, contains('RateLimitedFailure'));
  });

  testWidgets('ErrorView shows a friendly message and Retry works', (
    tester,
  ) async {
    var retries = 0;
    await pumpInApp(
      tester,
      ErrorView(failure: const OfflineFailure(), onRetry: () => retries++),
    );
    expect(
      find.text("You're offline. Connect to the internet and try again."),
      findsOneWidget,
    );
    await tester.tap(find.text('Try again'));
    expect(retries, 1);
  });

  testWidgets('a crash in build shows the friendly box, not red', (
    tester,
  ) async {
    final original = ErrorWidget.builder;
    ErrorWidget.builder = (details) => FriendlyBuildError(details: details);
    try {
      await pumpInApp(tester, const _Crash());
      expect(tester.takeException(), isA<StateError>());
      expect(find.byType(FriendlyBuildError), findsOneWidget);
      expect(find.text('Something went wrong'), findsOneWidget);
    } finally {
      ErrorWidget.builder = original;
    }
  });
}
