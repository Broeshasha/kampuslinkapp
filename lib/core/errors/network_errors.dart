import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// true = the phone could not reach the server (no network, DNS, timeout,
/// TLS, Supabase "retryable" fetch). Never a reason to sign anyone out.
bool isNetworkError(Object error) {
  if (error is TimeoutException || error is http.ClientException) return true;
  if (error is AuthRetryableFetchException) return true;
  final text = error.toString();
  return text.startsWith('SocketException') ||
      text.startsWith('HandshakeException') ||
      text.startsWith('HttpException') ||
      text.contains('Failed host lookup') ||
      text.contains('Network is unreachable') ||
      text.contains('Connection refused') ||
      text.contains('Connection reset') ||
      text.contains('Connection closed');
}
