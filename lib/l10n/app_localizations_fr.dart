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
  String get diagramUnavailable => 'Schéma indisponible';

  @override
  String get zoomFigure => 'Agrandir';

  @override
  String get resumeTitle => 'Reprends là où tu t’es arrêté';

  @override
  String get reasonWrongAnswer => 'Réponse fausse';

  @override
  String get reasonTypo => 'Faute de frappe';

  @override
  String get reasonUnclear => 'Pas clair';

  @override
  String get reasonTranslation => 'Problème de traduction';

  @override
  String get semesterPick => 'Tu es en quel semestre ?';

  @override
  String get semesterPinnedHelp =>
      'Semestres que tu suis encore (dettes, rattrapages) :';

  @override
  String get semesterNone => 'Choisis ton semestre actuel';

  @override
  String semesterCurrent(int number) {
    return 'Semestre actuel : S$number';
  }

  @override
  String semesterPinned(String list) {
    return 'Suivis aussi : $list';
  }

  @override
  String get semesterNewHint =>
      'Nouveau semestre ? Vérifie que le tien est juste.';

  @override
  String get semesterUpdate => 'Mettre à jour';

  @override
  String semesterThis(int number) {
    return 'Ce semestre · S$number';
  }

  @override
  String semesterStillFollowing(int number) {
    return 'S$number · encore suivi';
  }

  @override
  String get semesterPrevious => 'Semestres précédents';

  @override
  String yearQuestionTitle(String year) {
    return 'As-tu validé ton année ($year) ?';
  }

  @override
  String get yearPassed => 'J’ai validé';

  @override
  String get yearPassedDebts => 'Validé avec dettes';

  @override
  String get yearRepeat => 'Je redouble';

  @override
  String get yearThanks => 'C’est noté. Tes modules sont mis à jour.';

  @override
  String get previewTitle => 'Aperçu des brouillons';

  @override
  String get previewDrafts => 'Aperçu des brouillons';

  @override
  String get previewDraftsHelp =>
      'Admins seulement : voir les leçons et séries en brouillon avant publication.';

  @override
  String get draftBadge => 'BROUILLON';

  @override
  String get kindMystery => 'Mystère';

  @override
  String get kindExplainer => 'Explication';

  @override
  String get kindQuizChain => 'Quiz en chaîne';

  @override
  String clueCount(int n, int total) {
    return 'Indice $n/$total';
  }

  @override
  String stepCount(int n, int total) {
    return 'Étape $n/$total';
  }

  @override
  String get whyExam => 'Pourquoi c’est important pour l’examen';

  @override
  String get nextCase => 'Suivant';

  @override
  String get reportMistake => 'Signaler une erreur';

  @override
  String get caseSaved => 'Enregistré';

  @override
  String get shuffleFeed => 'Mélanger le fil';

  @override
  String get swipeForMore => 'Glisse pour voir la suite';

  @override
  String get quickRight => 'Bonne réponse !';

  @override
  String get quickWrong => 'Pas tout à fait. La bonne réponse est en vert.';

  @override
  String get dlRunCheck => 'Vérifier le téléchargement';

  @override
  String get dlOffline =>
      'Pas d\'internet. Ce qui est déjà arrivé reste sur ton téléphone ; on continue dès que tu es en ligne.';

  @override
  String get dlTimeout =>
      'Le serveur a mis trop de temps. Touche Réessayer : on reprend là où ça s\'est arrêté.';

  @override
  String get dlServer =>
      'Le serveur a eu un problème pour envoyer ce module. Réessaie dans un instant.';

  @override
  String get dlStorage =>
      'Plus de place sur ton téléphone ou ton navigateur (ou stockage bloqué). Libère de l\'espace puis réessaie.';

  @override
  String get dlDatabase =>
      'L\'enregistrement sur cet appareil a échoué. Réessaie ; si ça continue, envoie-nous les détails.';

  @override
  String get dlUnknown =>
      'Le téléchargement s\'est arrêté. Réessaie ; si ça continue, envoie-nous les détails.';

  @override
  String get dlDetails => 'Détails';

  @override
  String get dlCopy => 'Copier';

  @override
  String get dlCopied => 'Copié';

  @override
  String dlDownloadingLessons(int done, int total) {
    return 'Téléchargement $done / $total leçons';
  }

  @override
  String get langDownloading => 'Téléchargement de cette langue pour la leçon…';

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

  @override
  String get blockDefinition => 'Définition';

  @override
  String get blockExample => 'Exemple';

  @override
  String get blockNote => 'Remarque';

  @override
  String get blockApplication => 'Application';

  @override
  String get blockDiagram => 'Schéma';

  @override
  String get blockDescription => 'Description';

  @override
  String figureLabel(int number) {
    return 'Figure $number';
  }

  @override
  String get readerTextSize => 'Taille du texte';

  @override
  String get moduleLessons => 'Leçons';

  @override
  String get moduleLibrary => 'Bibliothèque';

  @override
  String chapterLabel(int number) {
    return 'Chapitre $number';
  }

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get moduleNotDownloaded => 'Ce module n\'est pas encore téléchargé';

  @override
  String get downloadModule => 'Télécharger';

  @override
  String get moduleNoLessons =>
      'Pas encore de leçons pour ce module. Elles arrivent bientôt.';

  @override
  String get moduleUpdateAvailable => 'Nouveau contenu disponible';

  @override
  String get updateAction => 'Mettre à jour';

  @override
  String get needInternetToDownload =>
      'Connecte-toi à Internet pour le télécharger.';

  @override
  String get libraryEmpty => 'Aucun fichier pour l\'instant';

  @override
  String resourceType(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'cours': 'Cours',
      'td': 'TD',
      'tp': 'TP',
      'textbook': 'Manuel',
      'exercices_corriges': 'Exercices corrigés',
      'exam': 'Examens',
      'notes': 'Notes',
      'memoire': 'Mémoires',
      'other': 'Autres fichiers',
    });
    return '$_temp0';
  }

  @override
  String trustLabel(String label) {
    String _temp0 = intl.Intl.selectLogic(label, {
      'official': 'Officiel',
      'verified': 'Vérifié',
      'other': 'Étudiant',
    });
    return '$_temp0';
  }

  @override
  String get backToWhereYouStopped => 'Reprendre où tu t\'es arrêté';

  @override
  String get markAsDone => 'Marquer comme terminé';

  @override
  String get lessonDone => 'Terminé';

  @override
  String get nextLesson => 'Leçon suivante';

  @override
  String get backToModule => 'Retour au module';

  @override
  String get lessonLanguage => 'Langue de la leçon';

  @override
  String get lessonNotFound => 'Cette leçon n\'est plus sur ton téléphone.';

  @override
  String get needInternetForFile =>
      'Pour l\'instant, les fichiers s\'ouvrent en ligne. Connecte-toi à Internet.';

  @override
  String get fileOpenFailed => 'Impossible d\'ouvrir ce fichier.';

  @override
  String get feedEmptyTitle => 'Rien à réviser pour l\'instant';

  @override
  String get feedEmptyBody =>
      'Télécharge un module et ses cartes apparaîtront ici.';

  @override
  String get openModules => 'Ouvrir mes modules';

  @override
  String get feedDoneTitle => 'C\'est tout pour l\'instant';

  @override
  String feedDoneNext(String time) {
    return 'Prochaines cartes à $time';
  }

  @override
  String get feedDoneNoMore =>
      'Lis une leçon pour débloquer de nouvelles cartes.';

  @override
  String get practiseAhead => 'Réviser en avance';

  @override
  String get tapToFlip => 'Touche pour voir la réponse';

  @override
  String get knewIt => 'Je savais';

  @override
  String get again => 'Encore';

  @override
  String get continueLabel => 'Continuer';

  @override
  String get streakLabel => 'Jours d\'affilée';

  @override
  String get xpLabel => 'XP';

  @override
  String todayMinutes(int done, int goal) {
    return '$done / $goal min aujourd\'hui';
  }

  @override
  String get likeLabel => 'J\'aime';

  @override
  String get saveLabel => 'Enregistrer';

  @override
  String get quizTitle => 'Quiz';

  @override
  String get takeQuiz => 'Faire le quiz';

  @override
  String questionOf(int n, int total) {
    return 'Question $n sur $total';
  }

  @override
  String get quizCorrect => 'Correct !';

  @override
  String get quizWrong => 'Pas tout à fait';

  @override
  String get quizNext => 'Suivant';

  @override
  String get quizSeeResults => 'Voir les résultats';

  @override
  String quizScore(int correct, int total) {
    return '$correct / $total bonnes réponses';
  }

  @override
  String get quizCardsBack =>
      'Les cartes de cette leçon reviennent dans ton fil.';

  @override
  String get quizFinish => 'Terminer';

  @override
  String get quizNoQuestions => 'Pas encore de questions pour cette leçon.';

  @override
  String get trueLabel => 'Vrai';

  @override
  String get falseLabel => 'Faux';

  @override
  String get noteIntuition => 'En termes simples';

  @override
  String get noteMistake => 'Erreur fréquente';

  @override
  String get noteExamTip => 'Astuce d\'examen';

  @override
  String get noteRemember => 'À retenir';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get themeLabel => 'Thème';

  @override
  String get themeSystem => 'Système';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get minutesStudied => 'Minutes d\'étude';

  @override
  String get lessonsDoneLabel => 'Leçons terminées';

  @override
  String get savedCards => 'Cartes enregistrées';

  @override
  String get savedCardsEmpty =>
      'Touche le signet d\'une carte pour la garder ici.';

  @override
  String get allSynced => 'Tout est synchronisé';

  @override
  String pendingSync(int count) {
    return '$count changements en attente de synchronisation';
  }

  @override
  String get aboutTitle => 'À propos';

  @override
  String get sendFeedback => 'Envoyer un avis';

  @override
  String appVersion(String version) {
    return 'Version $version';
  }

  @override
  String get deleteAccount => 'Supprimer mon compte';

  @override
  String get deleteAccountTitle => 'Supprimer ton compte ?';

  @override
  String get deleteAccountBody =>
      'Ton profil, ta progression, ta série, tes XP et tes messages sont supprimés de nos serveurs, et ce téléphone est vidé. C\'est irréversible.';

  @override
  String get deleteAccountCheck => 'Je comprends que c\'est irréversible';

  @override
  String get deleteAccountConfirm => 'Tout supprimer';

  @override
  String get deleteAccountDone => 'Ton compte a été supprimé.';

  @override
  String get chatTitle => 'Discussion';

  @override
  String get chatEmpty =>
      'Pas encore de messages. Dis bonjour à tes camarades !';

  @override
  String get chatHint => 'Écris un message';

  @override
  String get chatSend => 'Envoyer';

  @override
  String get chatSending => 'Envoi...';

  @override
  String get chatFailed => 'Non envoyé. Touche pour réessayer.';

  @override
  String get chatTranslated => 'Traduit';

  @override
  String get chatShowOriginal => 'Voir l\'original';

  @override
  String get chatShowTranslation => 'Voir la traduction';

  @override
  String get chatTranslating => 'traduction...';

  @override
  String get chatReport => 'Signaler';

  @override
  String chatBlock(String name) {
    return 'Bloquer @$name';
  }

  @override
  String get chatDelete => 'Supprimer';

  @override
  String get reportTitle => 'Signaler ce message';

  @override
  String get reportSpam => 'Spam';

  @override
  String get reportHarassment => 'Harcèlement ou insultes';

  @override
  String get reportWrong => 'Information fausse';

  @override
  String get reportOther => 'Autre chose';

  @override
  String get reportDetails => 'Détails (facultatif)';

  @override
  String get reportSend => 'Envoyer le signalement';

  @override
  String get reportThanks => 'Merci. Nous allons vérifier.';

  @override
  String blockConfirmTitle(String name) {
    return 'Bloquer @$name ?';
  }

  @override
  String get blockConfirmBody => 'Vous ne verrez plus vos messages respectifs.';

  @override
  String blockDone(String name) {
    return '@$name est bloqué.';
  }

  @override
  String get updateTitle => 'Une nouvelle version est nécessaire';

  @override
  String get updateBody =>
      'Cette version de KampusLink est trop ancienne pour protéger ta progression. Mets-la à jour pour continuer.';

  @override
  String get caseLabel => 'Enquête';

  @override
  String get demoBadge => 'DÉMO';

  @override
  String get continueCase => 'Reprendre l\'enquête';

  @override
  String get roleHook => 'L\'enquête';

  @override
  String get roleClue => 'Indice';

  @override
  String get roleStep => 'Étape';

  @override
  String get roleCommit => 'Ton hypothèse';

  @override
  String get roleReveal => 'La réponse';

  @override
  String get roleQuiz => 'Vérification rapide';

  @override
  String get roleTakeaway => 'À retenir';

  @override
  String get lockGuess => 'Je valide mon choix';

  @override
  String get lockGuessFirst => 'Valide une réponse avant de voir la solution';

  @override
  String get guessRight => 'Bien vu !';

  @override
  String get guessWrong => 'Pas cette fois. Voici pourquoi :';

  @override
  String get swipeHint => 'Glisse pour voir la réponse';

  @override
  String get caseDone => 'Enquête résolue';
}
