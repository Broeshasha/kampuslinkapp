import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/core/analytics/analytics.dart';

void main() {
  test('P1-ANALYTICS: no Firebase in tests -> log is a silent no-op', () async {
    await Analytics.log('lesson_complete');
    await Analytics.setUser(track: 'univ', year: 'L2', uiLang: 'ar');
  });

  test('only the allowed user properties exist', () {
    expect(Analytics.userProps, {'track', 'stream', 'year', 'ui_lang'});
  });

  test('scores are sent as buckets', () {
    expect(Analytics.scoreBucket(30), '0_49');
    expect(Analytics.scoreBucket(65), '50_79');
    expect(Analytics.scoreBucket(100), '80_100');
  });
}
