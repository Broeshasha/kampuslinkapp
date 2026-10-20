// DEBUG demo lesson for the renderer preview (source-chapter format, 3 languages).
// Generated: covers every block type, highlights, inline + block LaTeX,
// a broken formula (fallback), a table, figures (no asset + themed SVG)
// and an unknown block type.
const Map<String, Object?> demoChapter = {
  'chapter': {
    'sections': [
      {
        'id': 'demo_sec_1',
        'level': 1,
        'title': {
          'en': 'Oxygen and oxides',
          'fr': "L'oxyg\u00E8ne et les oxydes",
          'ar': '\u0627\u0644\u0623\u0643\u0633\u062C\u064A\u0646 \u0648\u0627\u0644\u0623\u0643\u0627\u0633\u064A\u062F',
        },
        'blocks': [
          {
            'id': 'demo_p1',
            'type': 'paragraph',
            'content': {
              'en': "Oxygen is the most abundant element in the Earth's crust. Its usual oxidation state is \u2212II, as in water H\u2082O. We write \\(n = \\frac{m}{M}\\) for the amount of substance.",
              'fr': "L'oxyg\u00E8ne est l'\u00E9l\u00E9ment le plus abondant de l'\u00E9corce terrestre. Son degr\u00E9 d'oxydation habituel est \u2212II, comme dans l'eau H\u2082O. On note \\(n = \\frac{m}{M}\\) la quantit\u00E9 de mati\u00E8re.",
              'ar': '\u0627\u0644\u0623\u0643\u0633\u062C\u064A\u0646 \u0647\u0648 \u0627\u0644\u0639\u0646\u0635\u0631 \u0627\u0644\u0623\u0643\u062B\u0631 \u0648\u0641\u0631\u0629 \u0641\u064A \u0627\u0644\u0642\u0634\u0631\u0629 \u0627\u0644\u0623\u0631\u0636\u064A\u0629. \u062F\u0631\u062C\u0629 \u0623\u0643\u0633\u062F\u062A\u0647 \u0627\u0644\u0645\u0639\u062A\u0627\u062F\u0629 \u0647\u064A \u2212II\u060C \u0643\u0645\u0627 \u0641\u064A \u0627\u0644\u0645\u0627\u0621 H\u2082O. \u0646\u0643\u062A\u0628 \\(n = \\frac{m}{M}\\) \u0644\u0643\u0645\u064A\u0629 \u0627\u0644\u0645\u0627\u062F\u0629.',
            },
            'highlights': {
              'en': [
                {'text': 'Oxygen', 'kind': 'term'},
                {'text': '\u2212II', 'kind': 'value'},
                {'text': 'H\u2082O', 'kind': 'formula'},
              ],
              'fr': [
                {'text': 'oxyg\u00E8ne', 'kind': 'term'},
                {'text': '\u2212II', 'kind': 'value'},
                {'text': 'H\u2082O', 'kind': 'formula'},
              ],
              'ar': [
                {
                  'text': '\u0627\u0644\u0623\u0643\u0633\u062C\u064A\u0646',
                  'kind': 'term',
                },
                {'text': '\u2212II', 'kind': 'value'},
                {'text': 'H\u2082O', 'kind': 'formula'},
              ],
            },
          },
          {
            'id': 'demo_d1',
            'type': 'definition',
            'content': {
              'en': 'An oxide is a compound of oxygen with another element.',
              'fr': "Un oxyde est un compos\u00E9 de l'oxyg\u00E8ne avec un autre \u00E9l\u00E9ment.",
              'ar': '\u0627\u0644\u0623\u0643\u0633\u064A\u062F \u0645\u0631\u0643\u0651\u0628 \u0645\u0646 \u0627\u0644\u0623\u0643\u0633\u062C\u064A\u0646 \u0648\u0639\u0646\u0635\u0631 \u0622\u062E\u0631.',
            },
            'highlights': {
              'en': [
                {'text': 'oxide', 'kind': 'term'},
              ],
              'fr': [
                {'text': 'oxyde', 'kind': 'term'},
              ],
              'ar': [
                {
                  'text': '\u0627\u0644\u0623\u0643\u0633\u064A\u062F',
                  'kind': 'term',
                },
              ],
            },
          },
          {
            'id': 'demo_e1',
            'type': 'example',
            'content': {
              'en': 'Sodium oxide Na\u2082\u1D35O is a basic oxide.',
              'fr': "L'oxyde de sodium Na\u2082\u1D35O est un oxyde basique.",
              'ar': '\u0623\u0643\u0633\u064A\u062F \u0627\u0644\u0635\u0648\u062F\u064A\u0648\u0645 Na\u2082\u1D35O \u0623\u0643\u0633\u064A\u062F \u0642\u0627\u0639\u062F\u064A.',
            },
            'highlights': {
              'en': [
                {'text': 'Na\u2082\u1D35O', 'kind': 'formula'},
              ],
              'fr': [
                {'text': 'Na\u2082\u1D35O', 'kind': 'formula'},
              ],
              'ar': [
                {'text': 'Na\u2082\u1D35O', 'kind': 'formula'},
              ],
            },
          },
          {
            'id': 'demo_n1',
            'type': 'note',
            'content': {
              'en': 'Exceptions: in OF\u2082 oxygen has the state +II.',
              'fr': "Exceptions : dans OF\u2082 l'oxyg\u00E8ne a le degr\u00E9 +II.",
              'ar': '\u0627\u0633\u062A\u062B\u0646\u0627\u0621\u0627\u062A: \u0641\u064A OF\u2082 \u0644\u0644\u0623\u0643\u0633\u062C\u064A\u0646 \u062F\u0631\u062C\u0629 +II.',
            },
            'highlights': {
              'en': [
                {'text': 'Exceptions', 'kind': 'warning'},
                {'text': '+II', 'kind': 'value'},
              ],
              'fr': [
                {'text': 'Exceptions', 'kind': 'warning'},
                {'text': '+II', 'kind': 'value'},
              ],
              'ar': [
                {
                  'text':
                      '\u0627\u0633\u062A\u062B\u0646\u0627\u0621\u0627\u062A',
                  'kind': 'warning',
                },
                {'text': '+II', 'kind': 'value'},
              ],
            },
          },
          {
            'id': 'demo_b1',
            'type': 'bullet_list',
            'items': [
              {
                'content': {
                  'en': 'Basic oxides: Na\u2082O, CaO',
                  'fr': 'Oxydes basiques : Na\u2082O, CaO',
                  'ar': '\u0623\u0643\u0627\u0633\u064A\u062F \u0642\u0627\u0639\u062F\u064A\u0629: Na\u2082O\u060C CaO',
                },
              },
              {
                'content': {
                  'en': 'Acidic oxides: CO\u2082, SO\u2083',
                  'fr': 'Oxydes acides : CO\u2082, SO\u2083',
                  'ar': '\u0623\u0643\u0627\u0633\u064A\u062F \u062D\u0645\u0636\u064A\u0629: CO\u2082\u060C SO\u2083',
                },
              },
              {
                'content': {
                  'en': 'Amphoteric oxides: Al\u2082O\u2083',
                  'fr': 'Oxydes amphot\u00E8res : Al\u2082O\u2083',
                  'ar': '\u0623\u0643\u0627\u0633\u064A\u062F \u0645\u0630\u0628\u0630\u0628\u0629: Al\u2082O\u2083',
                },
              },
            ],
          },
          {
            'id': 'demo_r1',
            'type': 'chemical_reaction',
            'formula': {
              'latex': '4\\,\\mathrm{Na} + \\mathrm{O}_2 \\longrightarrow 2\\,\\mathrm{Na}_2\\mathrm{O}',
              'plain_text': '4Na + O\u2082 \u27F6 2Na\u2082O',
            },
          },
          {
            'id': 'demo_r2',
            'type': 'chemical_reaction',
            'formula': {
              'latex': '\\mathrm{CO}_2 + \\mathrm{H}_2\\mathrm{O} \\rightleftharpoons \\mathrm{H}_2\\mathrm{CO}_3',
              'plain_text': 'CO\u2082 + H\u2082O \u21CC H\u2082CO\u2083',
            },
          },
          {
            'id': 'demo_eq1',
            'type': 'equation',
            'latex': '\\Delta H = \\int_{T_1}^{T_2} C_p\\,dT',
            'plain_text': '\u0394H = \u222B Cp dT',
            'display': true,
            'number': 1,
          },
          {
            'id': 'demo_bad1',
            'type': 'chemical_reaction',
            'formula': {
              'latex': '\\mathrm{O}_{2',
              'plain_text': 'O\u2082 (broken LaTeX: shown as plain text)',
            },
          },
          {
            'id': 'demo_t1',
            'type': 'table',
            'table_number': 1,
            'table_label': {
              'en': 'Table 1',
              'fr': 'Tableau 1',
              'ar': '\u0627\u0644\u062C\u062F\u0648\u0644 1',
            },
            'caption': {
              'en': 'Some oxides',
              'fr': 'Quelques oxydes',
              'ar': '\u0628\u0639\u0636 \u0627\u0644\u0623\u0643\u0627\u0633\u064A\u062F',
            },
            'columns': [
              {
                'id': 'c0',
                'label': {
                  'en': 'Element',
                  'fr': '\u00C9l\u00E9ment',
                  'ar': '\u0627\u0644\u0639\u0646\u0635\u0631',
                },
              },
              {
                'id': 'c1',
                'label': {
                  'en': 'Oxide',
                  'fr': 'Oxyde',
                  'ar': '\u0627\u0644\u0623\u0643\u0633\u064A\u062F',
                },
              },
              {
                'id': 'c2',
                'label': {
                  'en': 'Melting point',
                  'fr': 'Point de fusion',
                  'ar': '\u0646\u0642\u0637\u0629 \u0627\u0644\u0627\u0646\u0635\u0647\u0627\u0631',
                },
              },
            ],
            'rows': [
              {
                'id': 'r1',
                'label': {'en': 'Na', 'fr': 'Na', 'ar': 'Na'},
                'cells': [
                  {'value': 'Na\u2082O'},
                  {'value': '1132', 'unit': '\u00B0C'},
                ],
              },
              {
                'id': 'r2',
                'label': {'en': 'Ca', 'fr': 'Ca', 'ar': 'Ca'},
                'cells': [
                  {'value': 'CaO'},
                  {'value': '2613', 'unit': '\u00B0C'},
                ],
              },
              {
                'id': 'r3',
                'label': {'en': 'Si', 'fr': 'Si', 'ar': 'Si'},
                'cells': [
                  {
                    'value': 'SiO\u2082',
                    'note': {
                      'en': 'quartz',
                      'fr': 'quartz',
                      'ar': '\u0627\u0644\u0643\u0648\u0627\u0631\u062A\u0632',
                    },
                  },
                  {'value': '1710', 'unit': '\u00B0C'},
                ],
              },
            ],
            'footnotes': {
              'en': 'Values at 1 atm.',
              'fr': 'Valeurs \u00E0 1 atm.',
              'ar': '\u0642\u064A\u0645 \u0639\u0646\u062F 1 atm.',
            },
          },
          {
            'id': 'demo_f1',
            'type': 'figure',
            'figure_number': 1,
            'caption': {
              'en': 'Structure of silica',
              'fr': 'Structure de la silice',
              'ar': '\u0628\u0646\u064A\u0629 \u0627\u0644\u0633\u064A\u0644\u064A\u0643\u0627',
            },
            'labels': [
              {'text': 'SiO\u2082'},
              {
                'text': 'O',
                'translation': {
                  'en': 'oxygen',
                  'fr': 'oxyg\u00E8ne',
                  'ar': '\u0623\u0643\u0633\u062C\u064A\u0646',
                },
              },
            ],
            'description': {
              'en': 'Each silicon atom is bonded to four oxygen atoms.',
              'fr': "Chaque atome de silicium est li\u00E9 \u00E0 quatre atomes d'oxyg\u00E8ne.",
              'ar': '\u0643\u0644 \u0630\u0631\u0629 \u0633\u064A\u0644\u064A\u0633\u064A\u0648\u0645 \u0645\u0631\u062A\u0628\u0637\u0629 \u0628\u0623\u0631\u0628\u0639 \u0630\u0631\u0627\u062A \u0623\u0643\u0633\u062C\u064A\u0646.',
            },
            'asset': {'type': 'none'},
          },
          {
            'id': 'demo_f2',
            'type': 'figure',
            'figure_number': 2,
            'caption': {
              'en': 'Two energy levels',
              'fr': "Deux niveaux d'\u00E9nergie",
              'ar': '\u0645\u0633\u062A\u0648\u064A\u0627\u0646 \u0644\u0644\u0637\u0627\u0642\u0629',
            },
            'description': {
              'en': 'The upper line is E2, the lower line is E1.',
              'fr': 'La ligne du haut est E2, celle du bas E1.',
              'ar': '\u0627\u0644\u062E\u0637 \u0627\u0644\u0639\u0644\u0648\u064A \u0647\u0648 E2 \u0648\u0627\u0644\u0633\u0641\u0644\u064A \u0647\u0648 E1.',
            },
            'asset': {
              'type': 'svg',
              'svg': "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 200 100'><rect width='200' height='100' rx='8' fill='{{bg}}'/><line x1='20' y1='78' x2='180' y2='78' stroke='{{muted}}' stroke-width='2'/><line x1='20' y1='30' x2='180' y2='30' stroke='{{accent}}' stroke-width='3'/><text x='100' y='22' font-size='12' text-anchor='middle' fill='{{fg}}'>E2</text><text x='100' y='94' font-size='12' text-anchor='middle' fill='{{fg}}'>E1</text></svg>",
              'alt': {
                'en': 'Energy level diagram',
                'fr': "Diagramme de niveaux d'\u00E9nergie",
                'ar': '\u0645\u062E\u0637\u0637 \u0645\u0633\u062A\u0648\u064A\u0627\u062A \u0627\u0644\u0637\u0627\u0642\u0629',
              },
            },
          },
          {
            'id': 'demo_u1',
            'type': 'future_block_type',
            'content': {
              'en': 'Unknown block type: its text is shown and the app keeps working.',
              'fr': "Type de bloc inconnu : son texte est affich\u00E9 et l'application continue.",
              'ar': '\u0646\u0648\u0639 \u0643\u062A\u0644\u0629 \u063A\u064A\u0631 \u0645\u0639\u0631\u0648\u0641: \u064A\u064F\u0639\u0631\u0636 \u0646\u0635\u0647 \u0648\u064A\u0633\u062A\u0645\u0631 \u0627\u0644\u062A\u0637\u0628\u064A\u0642.',
            },
          },
        ],
      },
    ],
  },
};
