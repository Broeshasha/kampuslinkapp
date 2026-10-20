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
}
