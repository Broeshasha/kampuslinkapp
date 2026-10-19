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

  @override
  String get errorTitle => 'Un problème est survenu';

  @override
  String get errorOffline =>
      'Tu es hors ligne. Connecte-toi à Internet et réessaie.';

  @override
  String get errorSession => 'Ta session a expiré. Reconnecte-toi.';

  @override
  String get errorForbidden => 'Tu n\'as pas accès à ceci.';

  @override
  String get errorNotFound => 'Ce contenu n\'est plus disponible.';

  @override
  String get errorRateLimited => 'Doucement ! Réessaie dans une minute.';

  @override
  String get errorServer =>
      'Notre serveur a un souci. Réessaie dans un instant.';

  @override
  String get errorUnknown => 'Une erreur inattendue s\'est produite. Réessaie.';

  @override
  String get retry => 'Réessayer';

  @override
  String get loading => 'Chargement…';

  @override
  String get offlineBanner =>
      'Hors ligne · tu vois ce qui est enregistré sur ton téléphone';
}
