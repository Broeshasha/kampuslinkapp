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

  @override
  String get errorTitle => 'حدث خطأ ما';

  @override
  String get errorOffline => 'أنت غير متصل. اتصل بالإنترنت وحاول مجددًا.';

  @override
  String get errorSession => 'انتهت جلستك. يرجى تسجيل الدخول من جديد.';

  @override
  String get errorForbidden => 'ليس لديك صلاحية الوصول إلى هذا.';

  @override
  String get errorNotFound => 'هذا المحتوى لم يعد متاحًا.';

  @override
  String get errorRateLimited => 'تمهّل قليلًا وحاول بعد دقيقة.';

  @override
  String get errorServer => 'حدثت مشكلة في الخادم. حاول بعد لحظات.';

  @override
  String get errorUnknown => 'حدث أمر غير متوقع. حاول مجددًا.';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get loading => 'جارٍ التحميل…';
}
