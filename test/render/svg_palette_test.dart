import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/core/theme/app_theme.dart';
import 'package:kampuslink/render/figure_block.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

void main() {
  test('c1..c6 reach 3:1 on the figure background in both themes', () {
    for (final kc in [KampusColors.light, KampusColors.dark]) {
      final palette = svgPalette(kc);
      expect(palette.length, 6);
      for (final c in palette) {
        expect(_contrast(c, kc.surfaceRaised), greaterThanOrEqualTo(3));
        expect(_contrast(c, kc.background), greaterThanOrEqualTo(3));
      }
    }
  });

  test('placeholders become theme colours; unknown ones become fg', () {
    const svg = "<rect fill='{{c1}}'/><rect fill='{{zz}}'/><t fill='{{fg}}'/>";
    final light = themeSvg(svg, KampusColors.light);
    final dark = themeSvg(svg, KampusColors.dark);
    expect(light, contains(_hex(svgPaletteLight.first)));
    expect(dark, contains(_hex(svgPaletteDark.first)));
    expect(light, isNot(contains('{{')));
    final fg = _hex(KampusColors.dark.textPrimary);
    expect(RegExp(fg).allMatches(dark).length, 2);
  });
}
