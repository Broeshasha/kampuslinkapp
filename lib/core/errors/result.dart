import '../logging/logger.dart';
import 'app_failure.dart';
import 'failure_mapper.dart';

/// Typed outcome of any async work: Ok(value) or Err(failure).
sealed class Result<T> {
  const Result();
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final AppFailure failure;
}

/// Runs [run]; any throw becomes Err(mapped failure) AND is logged.
/// Offline is expected (info); everything else is a non-fatal error.
Future<Result<T>> guard<T>(Future<T> Function() run) async {
  try {
    return Ok(await run());
  } catch (error, stack) {
    final failure = mapError(error);
    if (failure is OfflineFailure) {
      appLog.info('offline: $error');
    } else {
      appLog.error(error, stack, reason: failure.toString());
    }
    return Err(failure);
  }
}
