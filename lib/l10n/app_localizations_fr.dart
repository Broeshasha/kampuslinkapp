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

  @override
  String semesterLabel(int number) {
    return 'Semestre $number';
  }

  @override
  String lessonsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count leçons',
      one: '1 leçon',
      zero: 'Pas encore de leçons',
    );
    return '$_temp0';
  }

  @override
  String get signInToSeeModules => 'Connecte-toi pour télécharger tes modules';

  @override
  String get continueWithGoogle => 'Continuer avec Google';

  @override
  String get noModulesTitle => 'Pas encore de modules';

  @override
  String get noModulesOffline =>
      'Connecte-toi une fois à Internet pour télécharger tes modules.';

  @override
  String get noModulesOnline =>
      'Aucun module trouvé pour ton année pour l\'instant.';

  @override
  String get syncing => 'Synchronisation…';

  @override
  String get synced => 'À jour';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String signedInAs(String email) {
    return 'Connecté : $email';
  }

  @override
  String get onboardingNext => 'Suivant';

  @override
  String get onboardingSignInTitle => 'Sauvegarde ta progression';

  @override
  String get onboardingSignInBody =>
      'Connecte-toi avec Google pour garder ta série, tes cartes et tes notes sur tous tes téléphones.';

  @override
  String get onboardingStudiesTitle => 'Tes études';

  @override
  String get studiesPilot => 'Génie minier · L2';

  @override
  String get studiesComingSoon => 'D\'autres spécialités arrivent bientôt';

  @override
  String get studiesNotifyMe => 'Préviens-moi';

  @override
  String get universityLabel => 'Université';

  @override
  String get chooseUniversity => 'Choisis ton université';

  @override
  String get usernameLabel => 'Nom d\'utilisateur';

  @override
  String get usernameHelp => '3 à 20 caractères : a–z, 0–9, _ ou .';

  @override
  String get usernameTaken => 'Ce nom est déjà pris';

  @override
  String studyGoalLabel(int minutes) {
    return 'Objectif quotidien : $minutes min';
  }

  @override
  String get remindersLabel => 'Me rappeler de réviser';

  @override
  String reminderTime(String time) {
    return 'À $time';
  }

  @override
  String get onboardingFinishStudies => 'Télécharger mes modules';

  @override
  String get downloadTitle => 'Téléchargement de tes modules';

  @override
  String downloadProgress(int done, int total) {
    return '$done sur $total prêts';
  }

  @override
  String get downloadNoContent => 'Leçons bientôt';

  @override
  String get downloadReady => 'Prêt';

  @override
  String get downloadSkip => 'Continuer en arrière-plan';

  @override
  String get startLearning => 'Commencer';
}
