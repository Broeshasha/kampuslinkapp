// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'KampusLink';

  @override
  String get splashTagline => 'ادرس بذكاء، حتى دون إنترنت.';

  @override
  String get languageLabel => 'اللغة';

  @override
  String get languageNameAr => 'العربية';

  @override
  String get languageNameFr => 'Français';

  @override
  String get languageNameEn => 'English';

  @override
  String get tabHome => 'الرئيسية';

  @override
  String get tabModules => 'المقاييس';

  @override
  String get tabProfile => 'حسابي';

  @override
  String get comingSoon => 'قريبًا';

  @override
  String get modulesPlaceholder => 'مقاييسك، دروسك، مكتبتك والدردشة';

  @override
  String get profilePlaceholder => 'حسابك، لغتك وتذكيراتك';
}
