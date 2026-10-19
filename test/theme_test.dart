import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/core/theme/app_theme.dart';
import 'package:kampuslink/core/theme/tokens.dart';

import 'helpers/pump_app.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('theme follows the phone: ${brightness.name}', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await pumpApp(tester);
      final theme = Theme.of(tester.element(find.text('KampusLink')));
      final expected = brightness == Brightness.dark
          ? KampusColors.dark
          : KampusColors.light;
      expect(theme.brightness, brightness);
      expect(theme.scaffoldBackgroundColor, expected.background);
    });
  }

  test('text colours pass WCAG contrast 4.5 in both themes', () {
    for (final c in [KampusColors.dark, KampusColors.light]) {
      for (final bg in [c.background, c.surface, c.surfaceRaised]) {
        for (final fg in [c.textPrimary, c.textSecondary, c.accentText]) {
          expect(
            contrast(fg, bg),
            greaterThanOrEqualTo(4.5),
            reason: '$fg on $bg',
          );
        }
      }
    }
  });

  test('12 module accents, chosen by module id', () {
    expect(moduleAccents.length, 12);
    expect(moduleAccent(14), moduleAccent(2));
  });
}
