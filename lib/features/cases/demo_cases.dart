/// DEMO carousel cases (lead brief B3) until the real content arrives with
/// backend file 11. Source format: every text is {en, fr, ar}.
/// Switch kShowDemoCases off before a Play Store release.
const kShowDemoCases = true;

const List<Map<String, Object?>> demoCases = [
  {
    'id': 'demo_case_sodium',
    'title': {
      'en': 'The disappearing shine',
      'fr': 'L\u2019\u00E9clat qui dispara\u00EEt',
      'ar': '\u0627\u0644\u0644\u0645\u0639\u0627\u0646 \u0627\u0644\u0630\u064A \u064A\u062E\u062A\u0641\u064A',
    },
    'slides': [
      {
        'id': 's1',
        'role': 'hook',
        'title': {
          'en': 'The disappearing shine',
          'fr': 'L\u2019\u00E9clat qui dispara\u00EEt',
          'ar': '\u0627\u0644\u0644\u0645\u0639\u0627\u0646 \u0627\u0644\u0630\u064A \u064A\u062E\u062A\u0641\u064A',
        },
        'content': {
          'en': 'A freshly cut piece of sodium is bright silver. Less than a minute later, in the air, it is dull grey. What happened?',
          'fr': 'Un morceau de sodium fra\u00EEchement coup\u00E9 est argent\u00E9 et brillant. Moins d\u2019une minute plus tard, \u00E0 l\u2019air, il est gris et terne. Que s\u2019est-il pass\u00E9 ?',
          'ar': '\u0642\u0637\u0639\u0629 \u0635\u0648\u062F\u064A\u0648\u0645 \u0645\u0642\u0637\u0648\u0639\u0629 \u0644\u0644\u062A\u0648 \u0644\u0627\u0645\u0639\u0629 \u0648\u0641\u0636\u064A\u0629. \u0628\u0639\u062F \u0623\u0642\u0644 \u0645\u0646 \u062F\u0642\u064A\u0642\u0629 \u0641\u064A \u0627\u0644\u0647\u0648\u0627\u0621 \u062A\u0635\u0628\u062D \u0631\u0645\u0627\u062F\u064A\u0629 \u0628\u0627\u0647\u062A\u0629. \u0645\u0627\u0630\u0627 \u062D\u062F\u062B\u061F',
        },
      },
      {
        'id': 's2',
        'role': 'clue',
        'content': {
          'en': 'Sodium has one electron in its outer shell and gives it away very easily: its oxidation state is +I.',
          'fr': 'Le sodium a un seul \u00E9lectron sur sa couche externe et le c\u00E8de tr\u00E8s facilement : son degr\u00E9 d\u2019oxydation est +I.',
          'ar': '\u0644\u0644\u0635\u0648\u062F\u064A\u0648\u0645 \u0625\u0644\u0643\u062A\u0631\u0648\u0646 \u0648\u0627\u062D\u062F \u0641\u064A \u0637\u0628\u0642\u062A\u0647 \u0627\u0644\u062E\u0627\u0631\u062C\u064A\u0629 \u0648\u064A\u0641\u0642\u062F\u0647 \u0628\u0633\u0647\u0648\u0644\u0629 \u0643\u0628\u064A\u0631\u0629: \u062F\u0631\u062C\u0629 \u0623\u0643\u0633\u062F\u062A\u0647 \u200E+I.',
        },
        'highlights': {
          'en': [
            {'text': '+I', 'kind': 'value'},
          ],
          'fr': [
            {'text': '+I', 'kind': 'value'},
          ],
          'ar': [
            {'text': '+I', 'kind': 'value'},
          ],
        },
      },
      {
        'id': 's3',
        'role': 'clue',
        'content': {
          'en': 'Air is about 21 % oxygen, and oxygen usually takes the oxidation state \u2212II.',
          'fr': 'L\u2019air contient environ 21 % d\u2019oxyg\u00E8ne, dont le degr\u00E9 d\u2019oxydation habituel est \u2212II.',
          'ar': '\u064A\u062D\u062A\u0648\u064A \u0627\u0644\u0647\u0648\u0627\u0621 \u0639\u0644\u0649 \u0646\u062D\u0648 21 % \u0645\u0646 \u0627\u0644\u0623\u0643\u0633\u062C\u064A\u0646\u060C \u0648\u062F\u0631\u062C\u0629 \u0623\u0643\u0633\u062F\u062A\u0647 \u0627\u0644\u0645\u0639\u062A\u0627\u062F\u0629 \u200E\u2212II.',
        },
        'highlights': {
          'en': [
            {'text': '21 %', 'kind': 'value'},
          ],
          'fr': [
            {'text': '21 %', 'kind': 'value'},
          ],
          'ar': [
            {'text': '21 %', 'kind': 'value'},
          ],
        },
      },
      {
        'id': 's4',
        'role': 'commit',
        'prompt': {
          'en': 'What forms on the surface?',
          'fr': 'Que se forme-t-il \u00E0 la surface ?',
          'ar': '\u0645\u0627 \u0627\u0644\u0630\u064A \u064A\u062A\u0643\u0648\u0651\u0646 \u0639\u0644\u0649 \u0627\u0644\u0633\u0637\u062D\u061F',
        },
        'options': [
          {
            'en': 'Sodium hydride NaH',
            'fr': 'Hydrure de sodium NaH',
            'ar': '\u0647\u064A\u062F\u0631\u064A\u062F \u0627\u0644\u0635\u0648\u062F\u064A\u0648\u0645 NaH',
          },
          {
            'en': 'Sodium oxide Na\u2082O',
            'fr': 'Oxyde de sodium Na\u2082O',
            'ar': '\u0623\u0643\u0633\u064A\u062F \u0627\u0644\u0635\u0648\u062F\u064A\u0648\u0645 Na\u2082O',
          },
          {
            'en': 'Sodium chloride NaCl',
            'fr': 'Chlorure de sodium NaCl',
            'ar': '\u0643\u0644\u0648\u0631\u064A\u062F \u0627\u0644\u0635\u0648\u062F\u064A\u0648\u0645 NaCl',
          },
        ],
        'correct_index': 1,
      },
      {
        'id': 's5',
        'role': 'reveal',
        'content': {
          'en': 'Sodium reacts with the oxygen of the air: \\(4\\,\\mathrm{Na} + \\mathrm{O_2} \\longrightarrow 2\\,\\mathrm{Na_2O}\\). The grey layer is sodium oxide, a basic oxide.',
          'fr': 'Le sodium r\u00E9agit avec l\u2019oxyg\u00E8ne de l\u2019air : \\(4\\,\\mathrm{Na} + \\mathrm{O_2} \\longrightarrow 2\\,\\mathrm{Na_2O}\\). La couche grise est de l\u2019oxyde de sodium, un oxyde basique.',
          'ar': '\u064A\u062A\u0641\u0627\u0639\u0644 \u0627\u0644\u0635\u0648\u062F\u064A\u0648\u0645 \u0645\u0639 \u0623\u0643\u0633\u062C\u064A\u0646 \u0627\u0644\u0647\u0648\u0627\u0621: \\(4\\,\\mathrm{Na} + \\mathrm{O_2} \\longrightarrow 2\\,\\mathrm{Na_2O}\\). \u0627\u0644\u0637\u0628\u0642\u0629 \u0627\u0644\u0631\u0645\u0627\u062F\u064A\u0629 \u0647\u064A \u0623\u0643\u0633\u064A\u062F \u0627\u0644\u0635\u0648\u062F\u064A\u0648\u0645\u060C \u0648\u0647\u0648 \u0623\u0643\u0633\u064A\u062F \u0642\u0627\u0639\u062F\u064A.',
        },
      },
      {
        'id': 's6',
        'role': 'quiz',
        'prompt': {
          'en': 'Na\u2082O dissolved in water gives\u2026',
          'fr': 'Na\u2082O dissous dans l\u2019eau donne\u2026',
          'ar': 'Na\u2082O \u0627\u0644\u0645\u0630\u0627\u0628 \u0641\u064A \u0627\u0644\u0645\u0627\u0621 \u064A\u0639\u0637\u064A\u2026',
        },
        'options': [
          {
            'en': 'an acidic solution',
            'fr': 'une solution acide',
            'ar': '\u0645\u062D\u0644\u0648\u0644\u064B\u0627 \u062D\u0645\u0636\u064A\u064B\u0627',
          },
          {
            'en': 'a basic solution (NaOH)',
            'fr': 'une solution basique (NaOH)',
            'ar': '\u0645\u062D\u0644\u0648\u0644\u064B\u0627 \u0642\u0627\u0639\u062F\u064A\u064B\u0627 (NaOH)',
          },
          {
            'en': 'a neutral solution',
            'fr': 'une solution neutre',
            'ar': '\u0645\u062D\u0644\u0648\u0644\u064B\u0627 \u0645\u062A\u0639\u0627\u062F\u0644\u064B\u0627',
          },
        ],
        'correct_index': 1,
        'explanation': {
          'en': 'Basic oxide + water gives a hydroxide: \\(\\mathrm{Na_2O} + \\mathrm{H_2O} \\to 2\\,\\mathrm{NaOH}\\).',
          'fr': 'Oxyde basique + eau donne un hydroxyde : \\(\\mathrm{Na_2O} + \\mathrm{H_2O} \\to 2\\,\\mathrm{NaOH}\\).',
          'ar': '\u0623\u0643\u0633\u064A\u062F \u0642\u0627\u0639\u062F\u064A + \u0645\u0627\u0621 \u064A\u0639\u0637\u064A \u0647\u064A\u062F\u0631\u0648\u0643\u0633\u064A\u062F\u064B\u0627: \\(\\mathrm{Na_2O} + \\mathrm{H_2O} \\to 2\\,\\mathrm{NaOH}\\).',
        },
      },
      {
        'id': 's7',
        'role': 'takeaway',
        'content': {
          'en': 'Alkali metals oxidise in air within seconds. That is why sodium is stored under oil.',
          'fr': 'Les m\u00E9taux alcalins s\u2019oxydent \u00E0 l\u2019air en quelques secondes. C\u2019est pourquoi le sodium est conserv\u00E9 dans l\u2019huile.',
          'ar': '\u062A\u062A\u0623\u0643\u0633\u062F \u0627\u0644\u0641\u0644\u0632\u0627\u062A \u0627\u0644\u0642\u0644\u0648\u064A\u0629 \u0641\u064A \u0627\u0644\u0647\u0648\u0627\u0621 \u062E\u0644\u0627\u0644 \u062B\u0648\u0627\u0646\u064D\u060C \u0644\u0630\u0644\u0643 \u064A\u064F\u062D\u0641\u0638 \u0627\u0644\u0635\u0648\u062F\u064A\u0648\u0645 \u0641\u064A \u0627\u0644\u0632\u064A\u062A.',
        },
      },
    ],
  },
  {
    'id': 'demo_case_average',
    'title': {
      'en': 'The class average trap',
      'fr': 'Le pi\u00E8ge de la moyenne',
      'ar': '\u0641\u062E \u0627\u0644\u0645\u0639\u062F\u0651\u0644',
    },
    'slides': [
      {
        'id': 's1',
        'role': 'hook',
        'title': {
          'en': 'The class average trap',
          'fr': 'Le pi\u00E8ge de la moyenne',
          'ar': '\u0641\u062E \u0627\u0644\u0645\u0639\u062F\u0651\u0644',
        },
        'content': {
          'en': 'Group A: 10 students, average 12/20. Group B: 30 students, average 8/20. Is the average of all 40 students 10/20?',
          'fr': 'Groupe A : 10 \u00E9tudiants, moyenne 12/20. Groupe B : 30 \u00E9tudiants, moyenne 8/20. La moyenne des 40 \u00E9tudiants est-elle 10/20 ?',
          'ar': '\u0627\u0644\u0641\u0648\u062C A: \u200F10 \u0637\u0644\u0627\u0628 \u0628\u0645\u0639\u062F\u0651\u0644 12/20. \u0627\u0644\u0641\u0648\u062C B: \u200F30 \u0637\u0627\u0644\u0628\u064B\u0627 \u0628\u0645\u0639\u062F\u0651\u0644 8/20. \u0647\u0644 \u0645\u0639\u062F\u0651\u0644 \u0627\u0644\u0637\u0644\u0627\u0628 \u0627\u0644\u0623\u0631\u0628\u0639\u064A\u0646 \u0647\u0648 10/20\u061F',
        },
      },
      {
        'id': 's2',
        'role': 'step',
        'content': {
          'en': 'An average counts every student once, not every group once.',
          'fr': 'Une moyenne compte chaque \u00E9tudiant une fois, pas chaque groupe.',
          'ar': '\u0627\u0644\u0645\u0639\u062F\u0651\u0644 \u064A\u062D\u0633\u0628 \u0643\u0644 \u0637\u0627\u0644\u0628 \u0645\u0631\u0629 \u0648\u0627\u062D\u062F\u0629\u060C \u0644\u0627 \u0643\u0644 \u0641\u0648\u062C.',
        },
      },
      {
        'id': 's3',
        'role': 'commit',
        'prompt': {
          'en': 'The average of the 40 students is\u2026',
          'fr': 'La moyenne des 40 \u00E9tudiants est\u2026',
          'ar': '\u0645\u0639\u062F\u0651\u0644 \u0627\u0644\u0637\u0644\u0627\u0628 \u0627\u0644\u0623\u0631\u0628\u0639\u064A\u0646 \u0647\u0648\u2026',
        },
        'options': [
          {'en': '10/20', 'fr': '10/20', 'ar': '10/20'},
          {'en': '9/20', 'fr': '9/20', 'ar': '9/20'},
          {'en': '11/20', 'fr': '11/20', 'ar': '11/20'},
        ],
        'correct_index': 1,
      },
      {
        'id': 's4',
        'role': 'reveal',
        'content': {
          'en': '\\(\\bar{x} = \\frac{10 \\times 12 + 30 \\times 8}{40} = \\frac{360}{40} = 9\\). The bigger group pulls the mean towards its own average.',
          'fr': 'La plus grande classe tire la moyenne vers la sienne : \\(\\bar{x} = \\frac{10 \\times 12 + 30 \\times 8}{40} = \\frac{360}{40} = 9\\).',
          'ar': '\u0627\u0644\u0641\u0648\u062C \u0627\u0644\u0623\u0643\u0628\u0631 \u064A\u0633\u062D\u0628 \u0627\u0644\u0645\u0639\u062F\u0651\u0644 \u0646\u062D\u0648 \u0645\u0639\u062F\u0651\u0644\u0647: \\(\\bar{x} = \\frac{10 \\times 12 + 30 \\times 8}{40} = \\frac{360}{40} = 9\\).',
        },
      },
      {
        'id': 's5',
        'role': 'takeaway',
        'content': {
          'en': 'Weighted mean: \\(\\bar{x} = \\frac{\\sum n_i \\bar{x}_i}{\\sum n_i}\\).',
          'fr': 'Moyenne pond\u00E9r\u00E9e : \\(\\bar{x} = \\frac{\\sum n_i \\bar{x}_i}{\\sum n_i}\\).',
          'ar': '\u0627\u0644\u0645\u0639\u062F\u0651\u0644 \u0627\u0644\u0645\u0631\u062C\u0651\u062D: \\(\\bar{x} = \\frac{\\sum n_i \\bar{x}_i}{\\sum n_i}\\).',
        },
      },
    ],
  },
];
