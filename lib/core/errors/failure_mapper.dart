import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_failure.dart';

/// Codes raised by our database functions (BACKEND_CONTRACT "ERROR CODES").
const _notFoundCodes = {
  'not_available',
  'card_not_available',
  'question_not_found',
  'not_in_module',
};

/// The ONE place that turns any thrown object into an [AppFailure].
AppFailure mapError(Object error) {
  if (error is AppFailure) return error;
  if (error is TimeoutException || error is http.ClientException) {
    return const OfflineFailure();
  }
  if (error is AuthException) return const UnauthenticatedFailure();
  if (error is PostgrestException) return _mapPostgrest(error);
  return UnknownFailure(error);
}

AppFailure _mapPostgrest(PostgrestException e) {
  final code = e.message.trim();
  if (e.code == '42501' || code.contains('permission denied')) {
    return const ForbiddenFailure();
  }
  if (e.code == 'PGRST301' || e.code == '401') {
    return const UnauthenticatedFailure();
  }
  switch (code) {
    case 'not_authenticated':
      return const UnauthenticatedFailure();
    case 'onboarding_required':
      return const OnboardingRequiredFailure();
    case 'forbidden':
      return const ForbiddenFailure();
    case 'rate_limited':
      return const RateLimitedFailure();
  }
  if (_notFoundCodes.contains(code)) return NotFoundFailure(code);
  if (e.code == 'P0001') return ValidationFailure(code);
  return ServerFailure(e.code ?? code);
}
