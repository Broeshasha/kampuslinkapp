import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';
import '../data/catalog/catalog.dart';
import '../render/figure_block.dart' show svgPalette;

/// Catalog icon keys -> icons; unknown or missing = a book.
const _icons = <String, IconData>{
  'math': Icons.functions_rounded,
  'wave': Icons.waves_rounded,
  'water': Icons.water_drop_outlined,
  'flask': Icons.science_outlined,
  'chart': Icons.bar_chart_rounded,
  'shield': Icons.shield_outlined,
  'law': Icons.gavel_rounded,
  'language': Icons.translate_rounded,
  'code': Icons.code_rounded,
  'ruler': Icons.straighten_rounded,
  'pickaxe': Icons.hardware_outlined,
  'gem': Icons.diamond_outlined,
  'gear': Icons.settings_outlined,
  'calculator': Icons.calculate_outlined,
  'truck': Icons.local_shipping_outlined,
  'tunnel': Icons.subway_outlined,
  'map': Icons.map_outlined,
  'lab': Icons.biotech_outlined,
  'layers': Icons.layers_outlined,
  'rock': Icons.landscape_outlined,
};

IconData moduleIcon(String? key) => _icons[key] ?? Icons.menu_book_rounded;

/// Catalog colour token c1..c6 (unknown = c1); no catalog = the old accent.
Color moduleColor(KampusColors kc, int moduleId, CatalogModule? module) {
  if (module == null) return moduleAccent(moduleId);
  final m = RegExp(r'^c([1-6])$').firstMatch(module.color ?? '');
  final palette = svgPalette(kc);
  return palette[m == null ? 0 : int.parse(m.group(1)!) - 1];
}

/// Module and speciality names are always the French name; inside an
/// Arabic UI they are an isolated left-to-right run.
String ltrName(BuildContext context, String name) =>
    Directionality.of(context) == TextDirection.rtl
    ? '\u2066$name\u2069'
    : name;
