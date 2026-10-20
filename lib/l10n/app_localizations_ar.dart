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

  @override
  String get offlineBanner => 'غير متصل · تشاهد ما هو محفوظ على هاتفك';

  @override
  String semesterLabel(int number) {
    return 'السداسي $number';
  }

  @override
  String lessonsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count درس',
      many: '$count درسًا',
      few: '$count دروس',
      two: 'درسان',
      one: 'درس واحد',
      zero: 'لا دروس بعد',
    );
    return '$_temp0';
  }

  @override
  String get signInToSeeModules => 'سجّل الدخول لتحميل مقاييسك';

  @override
  String get continueWithGoogle => 'المتابعة باستخدام Google';

  @override
  String get noModulesTitle => 'لا توجد مقاييس بعد';

  @override
  String get noModulesOffline => 'اتصل بالإنترنت مرة واحدة لتحميل مقاييسك.';

  @override
  String get noModulesOnline => 'لم نجد مقاييس لسنتك بعد.';

  @override
  String get syncing => 'جارٍ المزامنة…';

  @override
  String get synced => 'تمت المزامنة';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String signedInAs(String email) {
    return 'مسجّل باسم $email';
  }

  @override
  String get onboardingNext => 'التالي';

  @override
  String get onboardingSignInTitle => 'احفظ تقدّمك';

  @override
  String get onboardingSignInBody =>
      'سجّل الدخول بحساب Google للحفاظ على سلسلتك وبطاقاتك وملاحظاتك على كل هواتفك.';

  @override
  String get onboardingStudiesTitle => 'دراستك';

  @override
  String get studiesPilot => 'هندسة المناجم · L2';

  @override
  String get studiesComingSoon => 'تخصصات أخرى قريبًا';

  @override
  String get studiesNotifyMe => 'أعلمني';

  @override
  String get universityLabel => 'الجامعة';

  @override
  String get chooseUniversity => 'اختر جامعتك';

  @override
  String get usernameLabel => 'اسم المستخدم';

  @override
  String get usernameHelp => 'من 3 إلى 20 حرفًا: a–z أو 0–9 أو _ أو .';

  @override
  String get usernameTaken => 'اسم المستخدم هذا مأخوذ';

  @override
  String studyGoalLabel(int minutes) {
    return 'هدف الدراسة اليومي: $minutes دقيقة';
  }

  @override
  String get remindersLabel => 'ذكّرني بالمراجعة';

  @override
  String reminderTime(String time) {
    return 'في $time';
  }

  @override
  String get onboardingFinishStudies => 'تحميل مقاييسي';

  @override
  String get downloadTitle => 'جارٍ تحميل مقاييسك';

  @override
  String downloadProgress(int done, int total) {
    return '$done من $total جاهزة';
  }

  @override
  String get downloadNoContent => 'الدروس قريبًا';

  @override
  String get downloadReady => 'جاهز';

  @override
  String get downloadSkip => 'المتابعة في الخلفية';

  @override
  String get startLearning => 'ابدأ التعلم';

  @override
  String get blockDefinition => 'تعريف';

  @override
  String get blockExample => 'مثال';

  @override
  String get blockNote => 'ملاحظة';

  @override
  String get blockApplication => 'تطبيق';

  @override
  String get blockDiagram => 'مخطط';

  @override
  String get blockDescription => 'الوصف';

  @override
  String figureLabel(int number) {
    return 'الشكل $number';
  }

  @override
  String get readerTextSize => 'حجم النص';

  @override
  String get moduleLessons => 'الدروس';

  @override
  String get moduleLibrary => 'المكتبة';

  @override
  String chapterLabel(int number) {
    return 'الفصل $number';
  }

  @override
  String minutesShort(int minutes) {
    return '$minutes د';
  }

  @override
  String get moduleNotDownloaded => 'لم يتم تنزيل هذه الوحدة بعد';

  @override
  String get downloadModule => 'تنزيل';

  @override
  String get moduleNoLessons => 'لا توجد دروس لهذه الوحدة بعد. ستصل قريبًا.';

  @override
  String get moduleUpdateAvailable => 'محتوى جديد متوفر';

  @override
  String get updateAction => 'تحديث';

  @override
  String get needInternetToDownload => 'اتصل بالإنترنت لتنزيلها.';

  @override
  String get libraryEmpty => 'لا توجد ملفات بعد';

  @override
  String resourceType(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'cours': 'محاضرات',
      'td': 'أعمال موجهة',
      'tp': 'أعمال تطبيقية',
      'textbook': 'كتاب',
      'exercices_corriges': 'تمارين محلولة',
      'exam': 'امتحانات',
      'notes': 'ملاحظات',
      'memoire': 'مذكرات',
      'other': 'ملفات أخرى',
    });
    return '$_temp0';
  }

  @override
  String trustLabel(String label) {
    String _temp0 = intl.Intl.selectLogic(label, {
      'official': 'رسمي',
      'verified': 'موثّق',
      'other': 'طالب',
    });
    return '$_temp0';
  }

  @override
  String get backToWhereYouStopped => 'العودة إلى حيث توقفت';

  @override
  String get markAsDone => 'تحديد كمكتمل';

  @override
  String get lessonDone => 'مكتمل';

  @override
  String get nextLesson => 'الدرس التالي';

  @override
  String get backToModule => 'العودة إلى الوحدة';

  @override
  String get lessonLanguage => 'لغة الدرس';

  @override
  String get lessonNotFound => 'هذا الدرس لم يعد على هاتفك.';

  @override
  String get needInternetForFile =>
      'تُفتح الملفات عبر الإنترنت حاليًا. اتصل بالإنترنت.';

  @override
  String get fileOpenFailed => 'تعذّر فتح هذا الملف.';

  @override
  String get feedEmptyTitle => 'لا شيء للمراجعة بعد';

  @override
  String get feedEmptyBody => 'نزّل وحدة وستظهر بطاقاتها هنا.';

  @override
  String get openModules => 'افتح وحداتي';

  @override
  String get feedDoneTitle => 'انتهيت الآن';

  @override
  String feedDoneNext(String time) {
    return 'البطاقات التالية في $time';
  }

  @override
  String get feedDoneNoMore => 'اقرأ درسًا لفتح بطاقات جديدة.';

  @override
  String get practiseAhead => 'تدرّب مسبقًا';

  @override
  String get tapToFlip => 'المس لرؤية الإجابة';

  @override
  String get knewIt => 'عرفتها';

  @override
  String get again => 'مرة أخرى';

  @override
  String get continueLabel => 'تابع';

  @override
  String get streakLabel => 'أيام متتالية';

  @override
  String get xpLabel => 'نقاط';

  @override
  String todayMinutes(int done, int goal) {
    return '$done / $goal د اليوم';
  }

  @override
  String get likeLabel => 'إعجاب';

  @override
  String get saveLabel => 'حفظ';

  @override
  String get quizTitle => 'اختبار';

  @override
  String get takeQuiz => 'ابدأ الاختبار';

  @override
  String questionOf(int n, int total) {
    return 'السؤال $n من $total';
  }

  @override
  String get quizCorrect => 'صحيح!';

  @override
  String get quizWrong => 'ليس تمامًا';

  @override
  String get quizNext => 'التالي';

  @override
  String get quizSeeResults => 'عرض النتائج';

  @override
  String quizScore(int correct, int total) {
    return '$correct / $total إجابات صحيحة';
  }

  @override
  String get quizCardsBack => 'عادت بطاقات هذا الدرس إلى قائمتك.';

  @override
  String get quizFinish => 'إنهاء';

  @override
  String get quizNoQuestions => 'لا توجد أسئلة لهذا الدرس بعد.';

  @override
  String get trueLabel => 'صح';

  @override
  String get falseLabel => 'خطأ';

  @override
  String get noteIntuition => 'ببساطة';

  @override
  String get noteMistake => 'خطأ شائع';

  @override
  String get noteExamTip => 'نصيحة للامتحان';

  @override
  String get noteRemember => 'تذكّر';
}
