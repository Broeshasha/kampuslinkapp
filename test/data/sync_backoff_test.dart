import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/core/errors/app_failure.dart';
import 'package:kampuslink/data/sync/outbox_sync.dart';
import 'package:kampuslink/data/sync/sync_controller.dart';

void main() {
  test('B03: content back-off ladder 2, 5, 15, 60 min, capped', () {
    expect(contentBackoffFor(0), const Duration(minutes: 2));
    expect(contentBackoffFor(1), const Duration(minutes: 5));
    expect(contentBackoffFor(2), const Duration(minutes: 15));
    expect(contentBackoffFor(3), const Duration(minutes: 60));
    expect(contentBackoffFor(9), const Duration(minutes: 60));
  });

  test('B03: jitter adds at most 20 %', () {
    expect(
      contentBackoffFor(0, jitter: 0.5),
      const Duration(minutes: 2, seconds: 24),
    );
  });

  test('B03: only network / server trouble backs off', () {
    expect(isTransientFailure(const OfflineFailure()), isTrue);
    expect(isTransientFailure(const ServerFailure('500')), isTrue);
    expect(isTransientFailure(UnknownFailure(TimeoutException('x'))), isTrue);
    expect(isTransientFailure(const ForbiddenFailure()), isFalse);
    expect(isTransientFailure(null), isFalse);
  });

  test('B03: outbox sends 25 ops per call', () {
    expect(OutboxSync.batchSize, 25);
  });

  group('B04 throttle', () {
    final t0 = DateTime(2026, 11, 14, 10);
    test('first automatic pass always runs', () {
      expect(autoPassDue(now: t0), isTrue);
    });
    test('resume within 5 min: no full pass, flush allowed', () {
      final now = t0.add(const Duration(minutes: 3));
      expect(autoPassDue(now: now, lastPass: t0), isFalse);
      expect(autoFlushDue(now: now, lastPass: t0), isTrue);
    });
    test('after 5 min a full pass runs again', () {
      expect(
        autoPassDue(now: t0.add(const Duration(minutes: 5)), lastPass: t0),
        isTrue,
      );
    });
    test('server trouble: flush waits 1, 2, 5, 15 min; pass waits 15', () {
      bool flush(int fails, int min) => autoFlushDue(
        now: t0.add(Duration(minutes: min)),
        lastPass: t0,
        serverFailures: fails,
      );
      expect(flush(1, 0), isFalse);
      expect(flush(1, 1), isTrue);
      expect(flush(2, 1), isFalse);
      expect(flush(3, 5), isTrue);
      expect(flush(9, 14), isFalse);
      expect(flush(9, 15), isTrue);
      expect(
        autoPassDue(
          now: t0.add(const Duration(minutes: 10)),
          lastPass: t0,
          serverFailures: 1,
        ),
        isFalse,
      );
    });
  });
}
