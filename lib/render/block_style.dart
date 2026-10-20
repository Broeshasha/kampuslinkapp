import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../l10n/app_localizations.dart';

/// Everything a block needs to draw itself: lesson language (decides the
/// direction and the block labels), reader scale and theme colours.
class BlockStyle {
  const BlockStyle({
    required this.language,
    required this.scale,
    required this.kc,
    required this.labels,
    required this.base,
  });

  final String language;
  final double scale;
  final KampusColors kc;
  final AppLocalizations labels;
  final TextStyle base;

  bool get rtl => language == 'ar';

  TextDirection get direction => rtl ? TextDirection.rtl : TextDirection.ltr;

  /// CONTENT_FORMAT 5.8: line height 1.6 for Arabic, 1.5 for Latin.
  TextStyle get body => base.copyWith(
    fontSize: 16 * scale,
    height: rtl ? 1.6 : 1.5,
    color: kc.textPrimary,
  );

  /// Formulas, values and units stay left-to-right inside Arabic text.
  String ltr(String text) => rtl ? '\u2066$text\u2069' : text;
}
