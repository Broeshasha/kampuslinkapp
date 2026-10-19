import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/core/theme/app_theme.dart';
import 'package:kampuslink/core/theme/tokens.dart';

void main() {
  test('both themes use Cairo with the Noto fallbacks', () {
    for (final theme in [AppTheme.dark, AppTheme.light]) {
      final style = theme.textTheme.bodyMedium!;
      expect(style.fontFamily, KFonts.family);
      expect(style.fontFamilyFallback, KFonts.fallback);
    }
  });

  test('every bundled font and licence file is in the repo', () {
    const files = [
      'Cairo-Regular.ttf',
      'Cairo-SemiBold.ttf',
      'Cairo-Bold.ttf',
      'NotoSans-Regular.ttf',
      'NotoSans-Bold.ttf',
      'NotoSansMath-Regular.ttf',
      'NotoSansSymbols-Regular.ttf',
      'OFL-Cairo.txt',
      'OFL-Noto.txt',
    ];
    for (final name in files) {
      expect(File('assets/fonts/$name').existsSync(), isTrue, reason: name);
    }
  });
}
