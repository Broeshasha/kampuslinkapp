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
}
