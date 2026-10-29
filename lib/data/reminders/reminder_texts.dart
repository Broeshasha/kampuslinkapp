/// Reminder texts (built when scheduling, outside any screen, so they
/// live here in the 3 languages). Arabic and accents are escaped.
class ReminderTexts {
  const ReminderTexts({
    required this.channelName,
    required this.channelDescription,
    required this.start,
    required this.notNow,
    required this.generic,
    required this.cards,
    required this.cardsNoModule,
    required this.secondChance,
  });

  final String channelName;
  final String channelDescription;
  final String start;
  final String notNow;
  final String generic;
  final String Function(int count, String module) cards;
  final String Function(int count) cardsNoModule;

  /// The one second chance after reminders stopped.
  final String secondChance;

  String body(int count, String? module) {
    if (count <= 0) {
      return generic;
    }
    return module == null ? cardsNoModule(count) : cards(count, module);
  }
}

const reminderTitle = 'KampusLink';

ReminderTexts reminderTexts(String language) => switch (language) {
  'ar' => ReminderTexts(
    channelName: '\u062a\u0630\u0643\u064a\u0631\u0627\u062a \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629',
    channelDescription: '\u062a\u0630\u0643\u064a\u0631 \u0628\u0645\u0648\u0639\u062f \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629 \u0627\u0644\u0630\u064a \u0627\u062e\u062a\u0631\u062a\u0647',
    start: '\u0627\u0628\u062f\u0623',
    notNow: '\u0644\u064a\u0633 \u0627\u0644\u0622\u0646',
    generic: '\u062d\u0627\u0646 \u0648\u0642\u062a \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629 \u00b7 10 \u062f\u0642\u0627\u0626\u0642\u061f',
    cards: (count, module) =>
        '\u0644\u062f\u064a\u0643 $count \u0628\u0637\u0627\u0642\u0629 \u0644\u0644\u0645\u0631\u0627\u062c\u0639\u0629 \u0641\u064a $module \u00b7 10 \u062f\u0642\u0627\u0626\u0642\u061f',
    secondChance: '\u0645\u0633\u062a\u0639\u062f \u0644\u0628\u062f\u0627\u064a\u0629 \u062c\u062f\u064a\u062f\u0629\u061f 10 \u062f\u0642\u0627\u0626\u0642 \u0627\u0644\u064a\u0648\u0645 \u062a\u0643\u0641\u064a.',
    cardsNoModule: (count) =>
        '\u0644\u062f\u064a\u0643 $count \u0628\u0637\u0627\u0642\u0629 \u0641\u064a \u0627\u0646\u062a\u0638\u0627\u0631\u0643 \u00b7 10 \u062f\u0642\u0627\u0626\u0642\u061f',
  ),
  'en' => ReminderTexts(
    channelName: 'Study reminders',
    channelDescription: 'A reminder at the study time you chose',
    start: 'Start',
    notNow: 'Not now',
    generic: 'Time to study \u00b7 10 minutes?',
    cards: (count, module) =>
        '$count cards are waiting in $module \u00b7 10 minutes?',
    cardsNoModule: (count) => '$count cards are waiting \u00b7 10 minutes?',
    secondChance: 'Ready for a fresh start? 10 minutes today is enough.',
  ),
  _ => ReminderTexts(
    channelName: 'Rappels de r\u00e9vision',
    channelDescription: "Un rappel \u00e0 l'heure de r\u00e9vision choisie",
    start: 'Commencer',
    notNow: 'Plus tard',
    generic: "C'est l'heure de r\u00e9viser \u00b7 10 minutes ?",
    cards: (count, module) =>
        "$count cartes t'attendent en $module \u00b7 10 minutes ?",
    cardsNoModule: (count) => "$count cartes t'attendent \u00b7 10 minutes ?",
    secondChance: 'Pr\u00eat pour un nouveau d\u00e9part ? 10 minutes aujourd\'hui suffisent.',
  ),
};
