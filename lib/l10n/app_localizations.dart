import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('fr'),
  ];

  /// App name, never translated
  ///
  /// In en, this message translates to:
  /// **'KampusLink'**
  String get appTitle;

  /// One-line promise under the logo
  ///
  /// In en, this message translates to:
  /// **'Study smarter. Even offline.'**
  String get splashTagline;

  /// Title above the language picker
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// Always written in Arabic
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get languageNameAr;

  /// Always written in French
  ///
  /// In en, this message translates to:
  /// **'Français'**
  String get languageNameFr;

  /// Always written in English
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageNameEn;

  /// Bottom tab: flashcard feed
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// Bottom tab: the student's modules (Arabic: maqayis)
  ///
  /// In en, this message translates to:
  /// **'Modules'**
  String get tabModules;

  /// Bottom tab: account and settings
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get tabProfile;

  /// Placeholder under a screen that is not built yet
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// Placeholder title on the Modules tab
  ///
  /// In en, this message translates to:
  /// **'Your modules, lessons, library and chat'**
  String get modulesPlaceholder;

  /// Placeholder title on the Profile tab
  ///
  /// In en, this message translates to:
  /// **'Your account, language and reminders'**
  String get profilePlaceholder;

  /// No description provided for @errorTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorTitle;

  /// No description provided for @errorOffline.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Connect to the internet and try again.'**
  String get errorOffline;

  /// No description provided for @errorSession.
  ///
  /// In en, this message translates to:
  /// **'Your session ended. Please sign in again.'**
  String get errorSession;

  /// No description provided for @errorForbidden.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have access to this.'**
  String get errorForbidden;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'This is no longer available.'**
  String get errorNotFound;

  /// No description provided for @errorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Slow down a little and try again in a minute.'**
  String get errorRateLimited;

  /// No description provided for @errorServer.
  ///
  /// In en, this message translates to:
  /// **'Our server had a problem. Try again in a moment.'**
  String get errorServer;

  /// No description provided for @errorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something unexpected happened. Try again.'**
  String get errorUnknown;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @offlineBanner.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline · showing what\'s saved on your phone'**
  String get offlineBanner;

  /// No description provided for @semesterLabel.
  ///
  /// In en, this message translates to:
  /// **'Semester {number}'**
  String semesterLabel(int number);

  /// No description provided for @lessonsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No lessons yet} =1{1 lesson} other{{count} lessons}}'**
  String lessonsCount(int count);

  /// No description provided for @signInToSeeModules.
  ///
  /// In en, this message translates to:
  /// **'Sign in to download your modules'**
  String get signInToSeeModules;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @noModulesTitle.
  ///
  /// In en, this message translates to:
  /// **'No modules yet'**
  String get noModulesTitle;

  /// No description provided for @noModulesOffline.
  ///
  /// In en, this message translates to:
  /// **'Connect to the internet once to download your modules.'**
  String get noModulesOffline;

  /// No description provided for @noModulesOnline.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find modules for your year yet.'**
  String get noModulesOnline;

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncing;

  /// No description provided for @synced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get synced;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {email}'**
  String signedInAs(String email);

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Save your progress'**
  String get onboardingSignInTitle;

  /// No description provided for @onboardingSignInBody.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google to keep your streak, cards and notes on every phone.'**
  String get onboardingSignInBody;

  /// No description provided for @onboardingStudiesTitle.
  ///
  /// In en, this message translates to:
  /// **'Your studies'**
  String get onboardingStudiesTitle;

  /// No description provided for @studiesPilot.
  ///
  /// In en, this message translates to:
  /// **'Mining Engineering · L2'**
  String get studiesPilot;

  /// No description provided for @studiesComingSoon.
  ///
  /// In en, this message translates to:
  /// **'More specialities coming soon'**
  String get studiesComingSoon;

  /// No description provided for @studiesNotifyMe.
  ///
  /// In en, this message translates to:
  /// **'Notify me'**
  String get studiesNotifyMe;

  /// No description provided for @universityLabel.
  ///
  /// In en, this message translates to:
  /// **'University'**
  String get universityLabel;

  /// No description provided for @chooseUniversity.
  ///
  /// In en, this message translates to:
  /// **'Choose your university'**
  String get chooseUniversity;

  /// No description provided for @usernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get usernameLabel;

  /// No description provided for @usernameHelp.
  ///
  /// In en, this message translates to:
  /// **'3–20 characters: a–z, 0–9, _ or .'**
  String get usernameHelp;

  /// No description provided for @usernameTaken.
  ///
  /// In en, this message translates to:
  /// **'This username is taken'**
  String get usernameTaken;

  /// No description provided for @studyGoalLabel.
  ///
  /// In en, this message translates to:
  /// **'Daily study goal: {minutes} min'**
  String studyGoalLabel(int minutes);

  /// No description provided for @remindersLabel.
  ///
  /// In en, this message translates to:
  /// **'Remind me to study'**
  String get remindersLabel;

  /// No description provided for @reminderTime.
  ///
  /// In en, this message translates to:
  /// **'At {time}'**
  String reminderTime(String time);

  /// No description provided for @onboardingFinishStudies.
  ///
  /// In en, this message translates to:
  /// **'Download my modules'**
  String get onboardingFinishStudies;

  /// No description provided for @downloadTitle.
  ///
  /// In en, this message translates to:
  /// **'Downloading your modules'**
  String get downloadTitle;

  /// No description provided for @downloadProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} ready'**
  String downloadProgress(int done, int total);

  /// No description provided for @downloadNoContent.
  ///
  /// In en, this message translates to:
  /// **'Lessons coming soon'**
  String get downloadNoContent;

  /// No description provided for @downloadReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get downloadReady;

  /// No description provided for @downloadSkip.
  ///
  /// In en, this message translates to:
  /// **'Continue in the background'**
  String get downloadSkip;

  /// No description provided for @startLearning.
  ///
  /// In en, this message translates to:
  /// **'Start learning'**
  String get startLearning;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
