import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../render/block_style.dart';
import '../../render/figure_block.dart';

/// Every SVG placeholder, for the content team: {{fg}} {{muted}} {{bg}}
/// {{accent}} {{ok}} {{warn}} {{c1}}..{{c6}} and one unknown ({{zz}}).
const paletteSampleSvg =
    "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 320 210'>"
    "<rect width='320' height='210' rx='10' fill='{{bg}}'/>"
    "<text x='16' y='28' font-size='14' fill='{{fg}}'>fg: main text</text>"
    "<text x='16' y='48' font-size='12' fill='{{muted}}'>muted: labels</text>"
    "<rect x='16' y='62' width='60' height='22' rx='4' fill='{{accent}}'/>"
    "<text x='84' y='78' font-size='12' fill='{{fg}}'>accent</text>"
    "<rect x='150' y='62' width='60' height='22' rx='4' fill='{{ok}}'/>"
    "<text x='218' y='78' font-size='12' fill='{{fg}}'>ok</text>"
    "<rect x='16' y='94' width='60' height='22' rx='4' fill='{{warn}}'/>"
    "<text x='84' y='110' font-size='12' fill='{{fg}}'>warn</text>"
    "<rect x='150' y='94' width='60' height='22' rx='4' fill='{{zz}}'/>"
    "<text x='218' y='110' font-size='12' fill='{{fg}}'>unknown = fg</text>"
    "<rect x='16' y='130' width='40' height='60' rx='4' fill='{{c1}}'/>"
    "<rect x='66' y='145' width='40' height='45' rx='4' fill='{{c2}}'/>"
    "<rect x='116' y='120' width='40' height='70' rx='4' fill='{{c3}}'/>"
    "<rect x='166' y='155' width='40' height='35' rx='4' fill='{{c4}}'/>"
    "<rect x='216' y='138' width='40' height='52' rx='4' fill='{{c5}}'/>"
    "<rect x='266' y='126' width='40' height='64' rx='4' fill='{{c6}}'/>"
    '</svg>';

/// DEBUG: the sample figure in the light and the dark theme, side by side
/// (stacked on phones).
class SvgPalettePage extends StatelessWidget {
  const SvgPalettePage({super.key});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= KBreakpoints.medium;
    final panels = [
      _ThemedSample(theme: AppTheme.light, name: 'Light'),
      _ThemedSample(theme: AppTheme.dark, name: 'Dark'),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('SVG palette (debug)')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(KSpace.lg),
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final p in panels)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(KSpace.sm),
                        child: p,
                      ),
                    ),
                ],
              )
            : Column(
                children: [
                  for (final p in panels)
                    Padding(
                      padding: const EdgeInsets.only(bottom: KSpace.lg),
                      child: p,
                    ),
                ],
              ),
      ),
    );
  }
}

class _ThemedSample extends StatelessWidget {
  const _ThemedSample({required this.theme, required this.name});

  final ThemeData theme;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: theme,
      child: Builder(
        builder: (context) {
          final kc = context.kc;
          final style = BlockStyle(
            language: 'en',
            scale: 1,
            kc: kc,
            labels: lookupAppLocalizations(const Locale('en')),
            base: Theme.of(context).textTheme.bodyLarge ?? const TextStyle(),
          );
          return Container(
            padding: const EdgeInsets.all(KSpace.md),
            decoration: BoxDecoration(
              color: kc.background,
              borderRadius: BorderRadius.circular(KRadius.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: kc.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: KSpace.sm),
                FigureBlock(
                  block: const {
                    'id': 'palette',
                    'type': 'figure',
                    'figure_number': 1,
                    'caption': 'Every placeholder',
                    'asset': {'type': 'svg', 'svg': paletteSampleSvg},
                  },
                  style: style,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
