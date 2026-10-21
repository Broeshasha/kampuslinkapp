import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/features/profile/download_doctor_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PostgrestException pgError(String code, String message) =>
    PostgrestException(message: message, code: code);

void main() {
  test('the check names the server code, never a generic error', () {
    expect(
      describeError(pgError('57014', 'canceling statement due to timeout')),
      'PostgrestException code=57014 message=canceling statement due to timeout',
    );
    expect(
      describeError(TimeoutException('x', const Duration(seconds: 20))),
      'Timeout after 20s',
    );
    expect(describeError(StateError('boom')), startsWith('StateError: '));
  });

  test('a check line reads like the copied report', () {
    final line = DoctorLine('get_my_modules')
      ..ok = false
      ..ms = 120
      ..result = 'Timeout after 30s';
    expect(line.toString(), '[FAIL] get_my_modules (120ms): Timeout after 30s');
  });
}
