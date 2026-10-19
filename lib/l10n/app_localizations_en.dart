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
}
