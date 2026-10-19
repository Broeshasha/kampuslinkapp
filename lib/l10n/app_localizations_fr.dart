// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'KampusLink';

  @override
  String get splashTagline => 'Révise mieux. Même hors ligne.';

  @override
  String get languageLabel => 'Langue';

  @override
  String get languageNameAr => 'العربية';

  @override
  String get languageNameFr => 'Français';

  @override
  String get languageNameEn => 'English';

  @override
  String get tabHome => 'Accueil';

  @override
  String get tabModules => 'Modules';

  @override
  String get tabProfile => 'Profil';

  @override
  String get comingSoon => 'Bientôt disponible';

  @override
  String get modulesPlaceholder => 'Tes modules, leçons, bibliothèque et chat';

  @override
  String get profilePlaceholder => 'Ton compte, ta langue et tes rappels';
}
