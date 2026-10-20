// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'KampusLink';

  @override
  String get splashTagline => 'Study smarter. Even offline.';

  @override
  String get languageLabel => 'Language';

  @override
  String get languageNameAr => 'العربية';

  @override
  String get languageNameFr => 'Français';

  @override
  String get languageNameEn => 'English';

  @override
  String get tabHome => 'Home';

  @override
  String get tabModules => 'Modules';

  @override
  String get tabProfile => 'Profile';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get modulesPlaceholder => 'Your modules, lessons, library and chat';

  @override
  String get profilePlaceholder => 'Your account, language and reminders';

  @override
  String get errorTitle => 'Something went wrong';

  @override
  String get errorOffline =>
      'You\'re offline. Connect to the internet and try again.';

  @override
  String get errorSession => 'Your session ended. Please sign in again.';

  @override
  String get errorForbidden => 'You don\'t have access to this.';

  @override
  String get errorNotFound => 'This is no longer available.';

  @override
  String get errorRateLimited =>
      'Slow down a little and try again in a minute.';

  @override
  String get errorServer => 'Our server had a problem. Try again in a moment.';

  @override
  String get errorUnknown => 'Something unexpected happened. Try again.';

  @override
  String get retry => 'Try again';

  @override
  String get loading => 'Loading…';

  @override
  String get offlineBanner =>
      'You\'re offline · showing what\'s saved on your phone';

  @override
  String semesterLabel(int number) {
    return 'Semester $number';
  }

  @override
  String lessonsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lessons',
      one: '1 lesson',
      zero: 'No lessons yet',
    );
    return '$_temp0';
  }

  @override
  String get signInToSeeModules => 'Sign in to download your modules';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get noModulesTitle => 'No modules yet';

  @override
  String get noModulesOffline =>
      'Connect to the internet once to download your modules.';

  @override
  String get noModulesOnline => 'We couldn\'t find modules for your year yet.';

  @override
  String get syncing => 'Syncing…';

  @override
  String get synced => 'Synced';

  @override
  String get signOut => 'Sign out';

  @override
  String signedInAs(String email) {
    return 'Signed in as $email';
  }

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingSignInTitle => 'Save your progress';

  @override
  String get onboardingSignInBody =>
      'Sign in with Google to keep your streak, cards and notes on every phone.';

  @override
  String get onboardingStudiesTitle => 'Your studies';

  @override
  String get studiesPilot => 'Mining Engineering · L2';

  @override
  String get studiesComingSoon => 'More specialities coming soon';

  @override
  String get studiesNotifyMe => 'Notify me';

  @override
  String get universityLabel => 'University';

  @override
  String get chooseUniversity => 'Choose your university';

  @override
  String get usernameLabel => 'Username';

  @override
  String get usernameHelp => '3–20 characters: a–z, 0–9, _ or .';

  @override
  String get usernameTaken => 'This username is taken';

  @override
  String studyGoalLabel(int minutes) {
    return 'Daily study goal: $minutes min';
  }

  @override
  String get remindersLabel => 'Remind me to study';

  @override
  String reminderTime(String time) {
    return 'At $time';
  }

  @override
  String get onboardingFinishStudies => 'Download my modules';

  @override
  String get downloadTitle => 'Downloading your modules';

  @override
  String downloadProgress(int done, int total) {
    return '$done of $total ready';
  }

  @override
  String get downloadNoContent => 'Lessons coming soon';

  @override
  String get downloadReady => 'Ready';

  @override
  String get downloadSkip => 'Continue in the background';

  @override
  String get startLearning => 'Start learning';

  @override
  String get blockDefinition => 'Definition';

  @override
  String get blockExample => 'Example';

  @override
  String get blockNote => 'Note';

  @override
  String get blockApplication => 'Application';

  @override
  String get blockDiagram => 'Diagram';

  @override
  String get blockDescription => 'Description';

  @override
  String figureLabel(int number) {
    return 'Figure $number';
  }

  @override
  String get readerTextSize => 'Text size';

  @override
  String get moduleLessons => 'Lessons';

  @override
  String get moduleLibrary => 'Library';

  @override
  String chapterLabel(int number) {
    return 'Chapter $number';
  }

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get moduleNotDownloaded => 'This module is not downloaded yet';

  @override
  String get downloadModule => 'Download';

  @override
  String get moduleNoLessons =>
      'No lessons yet for this module. They are coming soon.';

  @override
  String get moduleUpdateAvailable => 'New content available';

  @override
  String get updateAction => 'Update';

  @override
  String get needInternetToDownload =>
      'Connect to the internet to download it.';

  @override
  String get libraryEmpty => 'No files yet';

  @override
  String resourceType(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'cours': 'Course',
      'td': 'Tutorials',
      'tp': 'Labs',
      'textbook': 'Textbook',
      'exercices_corriges': 'Solved exercises',
      'exam': 'Exams',
      'notes': 'Notes',
      'memoire': 'Thesis',
      'other': 'Other files',
    });
    return '$_temp0';
  }

  @override
  String trustLabel(String label) {
    String _temp0 = intl.Intl.selectLogic(label, {
      'official': 'Official',
      'verified': 'Verified',
      'other': 'Student',
    });
    return '$_temp0';
  }

  @override
  String get backToWhereYouStopped => 'Back to where you stopped';

  @override
  String get markAsDone => 'Mark as done';

  @override
  String get lessonDone => 'Done';

  @override
  String get nextLesson => 'Next lesson';

  @override
  String get backToModule => 'Back to the module';

  @override
  String get lessonLanguage => 'Lesson language';

  @override
  String get lessonNotFound => 'This lesson is no longer on your phone.';

  @override
  String get needInternetForFile =>
      'Files open online for now. Connect to the internet.';

  @override
  String get fileOpenFailed => 'Could not open this file.';

  @override
  String get feedEmptyTitle => 'Nothing to review yet';

  @override
  String get feedEmptyBody =>
      'Download a module and its flashcards appear here.';

  @override
  String get openModules => 'Open my modules';

  @override
  String get feedDoneTitle => 'All done for now';

  @override
  String feedDoneNext(String time) {
    return 'Next cards at $time';
  }

  @override
  String get feedDoneNoMore => 'Read a lesson to unlock new cards.';

  @override
  String get practiseAhead => 'Practise ahead';

  @override
  String get tapToFlip => 'Tap to see the answer';

  @override
  String get knewIt => 'I knew it';

  @override
  String get again => 'Again';

  @override
  String get continueLabel => 'Continue';

  @override
  String get streakLabel => 'Day streak';

  @override
  String get xpLabel => 'XP';

  @override
  String todayMinutes(int done, int goal) {
    return '$done / $goal min today';
  }

  @override
  String get likeLabel => 'Like';

  @override
  String get saveLabel => 'Save';

  @override
  String get quizTitle => 'Quiz';

  @override
  String get takeQuiz => 'Take the quiz';

  @override
  String questionOf(int n, int total) {
    return 'Question $n of $total';
  }

  @override
  String get quizCorrect => 'Correct!';

  @override
  String get quizWrong => 'Not quite';

  @override
  String get quizNext => 'Next';

  @override
  String get quizSeeResults => 'See results';

  @override
  String quizScore(int correct, int total) {
    return '$correct / $total correct';
  }

  @override
  String get quizCardsBack => 'The cards of this lesson are back in your feed.';

  @override
  String get quizFinish => 'Finish';

  @override
  String get quizNoQuestions => 'No questions for this lesson yet.';

  @override
  String get trueLabel => 'True';

  @override
  String get falseLabel => 'False';

  @override
  String get noteIntuition => 'In plain words';

  @override
  String get noteMistake => 'Common mistake';

  @override
  String get noteExamTip => 'Exam tip';

  @override
  String get noteRemember => 'Remember';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get themeLabel => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get minutesStudied => 'Minutes studied';

  @override
  String get lessonsDoneLabel => 'Lessons done';

  @override
  String get savedCards => 'Saved cards';

  @override
  String get savedCardsEmpty =>
      'Tap the bookmark on a flashcard to keep it here.';

  @override
  String get allSynced => 'Everything is synced';

  @override
  String pendingSync(int count) {
    return '$count changes waiting to sync';
  }

  @override
  String get aboutTitle => 'About';

  @override
  String get sendFeedback => 'Send feedback';

  @override
  String appVersion(String version) {
    return 'Version $version';
  }

  @override
  String get deleteAccount => 'Delete my account';

  @override
  String get deleteAccountTitle => 'Delete your account?';

  @override
  String get deleteAccountBody =>
      'Your profile, progress, streak, XP and messages are deleted from our servers, and this phone is cleared. This cannot be undone.';

  @override
  String get deleteAccountCheck => 'I understand this cannot be undone';

  @override
  String get deleteAccountConfirm => 'Delete everything';

  @override
  String get deleteAccountDone => 'Your account was deleted.';

  @override
  String get chatTitle => 'Chat';

  @override
  String get chatEmpty => 'No messages yet. Say hello to your classmates!';

  @override
  String get chatHint => 'Write a message';

  @override
  String get chatSend => 'Send';

  @override
  String get chatSending => 'Sending...';

  @override
  String get chatFailed => 'Not sent. Tap to retry.';

  @override
  String get chatTranslated => 'Translated';

  @override
  String get chatShowOriginal => 'Show original';

  @override
  String get chatShowTranslation => 'Show translation';

  @override
  String get chatTranslating => 'translating...';

  @override
  String get chatReport => 'Report';

  @override
  String chatBlock(String name) {
    return 'Block @$name';
  }

  @override
  String get chatDelete => 'Delete';

  @override
  String get reportTitle => 'Report this message';

  @override
  String get reportSpam => 'Spam';

  @override
  String get reportHarassment => 'Harassment or insults';

  @override
  String get reportWrong => 'Wrong information';

  @override
  String get reportOther => 'Something else';

  @override
  String get reportDetails => 'Details (optional)';

  @override
  String get reportSend => 'Send report';

  @override
  String get reportThanks => 'Thanks. We will look at it.';

  @override
  String blockConfirmTitle(String name) {
    return 'Block @$name?';
  }

  @override
  String get blockConfirmBody =>
      'You will no longer see each other\'s messages.';

  @override
  String blockDone(String name) {
    return '@$name is blocked.';
  }

  @override
  String get updateTitle => 'A new version is needed';

  @override
  String get updateBody =>
      'This version of KampusLink is too old to keep your progress safe. Please update to continue.';
}
