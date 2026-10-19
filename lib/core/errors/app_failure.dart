/// Every failure a screen can meet. Screens never see raw exceptions:
/// they get one of these and show a friendly, translated state.
sealed class AppFailure implements Exception {
  const AppFailure();

  @override
  String toString() => runtimeType.toString();
}

final class OfflineFailure extends AppFailure {
  const OfflineFailure();
}

final class UnauthenticatedFailure extends AppFailure {
  const UnauthenticatedFailure();
}

final class OnboardingRequiredFailure extends AppFailure {
  const OnboardingRequiredFailure();
}

final class ForbiddenFailure extends AppFailure {
  const ForbiddenFailure();
}

final class NotFoundFailure extends AppFailure {
  const NotFoundFailure([this.code]);
  final String? code;
}

final class ValidationFailure extends AppFailure {
  const ValidationFailure(this.code);
  final String code;
}

final class RateLimitedFailure extends AppFailure {
  const RateLimitedFailure();
}

final class ServerFailure extends AppFailure {
  const ServerFailure([this.detail]);
  final String? detail;
}

final class UnknownFailure extends AppFailure {
  const UnknownFailure([this.error]);
  final Object? error;
}
