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

  /// No description provided for @reasonWrongAnswer.
  ///
  /// In en, this message translates to:
  /// **'Wrong answer'**
  String get reasonWrongAnswer;

  /// No description provided for @reasonTypo.
  ///
  /// In en, this message translates to:
  /// **'Typo'**
  String get reasonTypo;

  /// No description provided for @reasonUnclear.
  ///
  /// In en, this message translates to:
  /// **'Unclear'**
  String get reasonUnclear;

  /// No description provided for @reasonTranslation.
  ///
  /// In en, this message translates to:
  /// **'Translation problem'**
  String get reasonTranslation;

  /// No description provided for @semesterPick.
  ///
  /// In en, this message translates to:
  /// **'Which semester are you in?'**
  String get semesterPick;

  /// No description provided for @semesterPinnedHelp.
  ///
  /// In en, this message translates to:
  /// **'Semesters you still follow (debts, retakes):'**
  String get semesterPinnedHelp;

  /// No description provided for @semesterNone.
  ///
  /// In en, this message translates to:
  /// **'Choose your current semester'**
  String get semesterNone;

  /// No description provided for @semesterCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current semester: S{number}'**
  String semesterCurrent(int number);

  /// No description provided for @semesterPinned.
  ///
  /// In en, this message translates to:
  /// **'Also following: {list}'**
  String semesterPinned(String list);

  /// No description provided for @semesterNewHint.
  ///
  /// In en, this message translates to:
  /// **'New semester? Check that yours is right.'**
  String get semesterNewHint;

  /// No description provided for @semesterUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get semesterUpdate;

  /// No description provided for @semesterThis.
  ///
  /// In en, this message translates to:
  /// **'This semester · S{number}'**
  String semesterThis(int number);

  /// No description provided for @semesterStillFollowing.
  ///
  /// In en, this message translates to:
  /// **'S{number} · still following'**
  String semesterStillFollowing(int number);

  /// No description provided for @semesterPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous semesters'**
  String get semesterPrevious;

  /// No description provided for @yearQuestionTitle.
  ///
  /// In en, this message translates to:
  /// **'Did you pass your year ({year})?'**
  String yearQuestionTitle(String year);

  /// No description provided for @yearPassed.
  ///
  /// In en, this message translates to:
  /// **'I passed'**
  String get yearPassed;

  /// No description provided for @yearPassedDebts.
  ///
  /// In en, this message translates to:
  /// **'Passed with debts'**
  String get yearPassedDebts;

  /// No description provided for @yearRepeat.
  ///
  /// In en, this message translates to:
  /// **'I repeat the year'**
  String get yearRepeat;

  /// No description provided for @yearThanks.
  ///
  /// In en, this message translates to:
  /// **'Saved. Your modules are being updated.'**
  String get yearThanks;

  /// No description provided for @previewTitle.
  ///
  /// In en, this message translates to:
  /// **'Draft preview'**
  String get previewTitle;

  /// No description provided for @previewDrafts.
  ///
  /// In en, this message translates to:
  /// **'Preview drafts'**
  String get previewDrafts;

  /// No description provided for @previewDraftsHelp.
  ///
  /// In en, this message translates to:
  /// **'Admins only: see draft lessons and sets before they are published.'**
  String get previewDraftsHelp;

  /// No description provided for @draftBadge.
  ///
  /// In en, this message translates to:
  /// **'DRAFT'**
  String get draftBadge;

  /// No description provided for @kindMystery.
  ///
  /// In en, this message translates to:
  /// **'Mystery'**
  String get kindMystery;

  /// No description provided for @kindExplainer.
  ///
  /// In en, this message translates to:
  /// **'Explainer'**
  String get kindExplainer;

  /// No description provided for @kindQuizChain.
  ///
  /// In en, this message translates to:
  /// **'Quiz chain'**
  String get kindQuizChain;

  /// No description provided for @clueCount.
  ///
  /// In en, this message translates to:
  /// **'Clue {n}/{total}'**
  String clueCount(int n, int total);

  /// No description provided for @stepCount.
  ///
  /// In en, this message translates to:
  /// **'Step {n}/{total}'**
  String stepCount(int n, int total);

  /// No description provided for @whyExam.
  ///
  /// In en, this message translates to:
  /// **'Why it matters for the exam'**
  String get whyExam;

  /// No description provided for @nextCase.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextCase;

  /// No description provided for @reportMistake.
  ///
  /// In en, this message translates to:
  /// **'Report a mistake'**
  String get reportMistake;

  /// No description provided for @caseSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get caseSaved;

  /// No description provided for @shuffleFeed.
  ///
  /// In en, this message translates to:
  /// **'Shuffle the feed'**
  String get shuffleFeed;

  /// No description provided for @swipeForMore.
  ///
  /// In en, this message translates to:
  /// **'Swipe to see more'**
  String get swipeForMore;

  /// No description provided for @quickRight.
  ///
  /// In en, this message translates to:
  /// **'Right!'**
  String get quickRight;

  /// No description provided for @quickWrong.
  ///
  /// In en, this message translates to:
  /// **'Not quite. The right answer is in green.'**
  String get quickWrong;

  /// No description provided for @dlRunCheck.
  ///
  /// In en, this message translates to:
  /// **'Download check'**
  String get dlRunCheck;

  /// No description provided for @dlOffline.
  ///
  /// In en, this message translates to:
  /// **'No internet. What already arrived stays on your phone; we continue when you are back online.'**
  String get dlOffline;

  /// No description provided for @dlTimeout.
  ///
  /// In en, this message translates to:
  /// **'The server took too long. Tap Retry: we continue from where it stopped.'**
  String get dlTimeout;

  /// No description provided for @dlServer.
  ///
  /// In en, this message translates to:
  /// **'The server had a problem sending this module. Tap Retry in a moment.'**
  String get dlServer;

  /// No description provided for @dlStorage.
  ///
  /// In en, this message translates to:
  /// **'Your phone or browser has no space left (or blocks storage). Free some space, then Retry.'**
  String get dlStorage;

  /// No description provided for @dlDatabase.
  ///
  /// In en, this message translates to:
  /// **'Saving on this device failed. Tap Retry; if it keeps failing, send us the details.'**
  String get dlDatabase;

  /// No description provided for @dlUnknown.
  ///
  /// In en, this message translates to:
  /// **'The download stopped. Tap Retry; if it keeps failing, send us the details.'**
  String get dlUnknown;

  /// No description provided for @dlDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get dlDetails;

  /// No description provided for @dlCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get dlCopy;

  /// No description provided for @dlCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get dlCopied;

  /// No description provided for @dlDownloadingLessons.
  ///
  /// In en, this message translates to:
  /// **'Downloading {done} / {total} lessons'**
  String dlDownloadingLessons(int done, int total);

  /// No description provided for @langDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading this language for the lesson…'**
  String get langDownloading;

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

  /// No description provided for @blockDefinition.
  ///
  /// In en, this message translates to:
  /// **'Definition'**
  String get blockDefinition;

  /// No description provided for @blockExample.
  ///
  /// In en, this message translates to:
  /// **'Example'**
  String get blockExample;

  /// No description provided for @blockNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get blockNote;

  /// No description provided for @blockApplication.
  ///
  /// In en, this message translates to:
  /// **'Application'**
  String get blockApplication;

  /// No description provided for @blockDiagram.
  ///
  /// In en, this message translates to:
  /// **'Diagram'**
  String get blockDiagram;

  /// No description provided for @blockDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get blockDescription;

  /// No description provided for @figureLabel.
  ///
  /// In en, this message translates to:
  /// **'Figure {number}'**
  String figureLabel(int number);

  /// No description provided for @readerTextSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get readerTextSize;

  /// No description provided for @moduleLessons.
  ///
  /// In en, this message translates to:
  /// **'Lessons'**
  String get moduleLessons;

  /// No description provided for @moduleLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get moduleLibrary;

  /// No description provided for @chapterLabel.
  ///
  /// In en, this message translates to:
  /// **'Chapter {number}'**
  String chapterLabel(int number);

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String minutesShort(int minutes);

  /// No description provided for @moduleNotDownloaded.
  ///
  /// In en, this message translates to:
  /// **'This module is not downloaded yet'**
  String get moduleNotDownloaded;

  /// No description provided for @downloadModule.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get downloadModule;

  /// No description provided for @moduleNoLessons.
  ///
  /// In en, this message translates to:
  /// **'No lessons yet for this module. They are coming soon.'**
  String get moduleNoLessons;

  /// No description provided for @moduleUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'New content available'**
  String get moduleUpdateAvailable;

  /// No description provided for @updateAction.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateAction;

  /// No description provided for @needInternetToDownload.
  ///
  /// In en, this message translates to:
  /// **'Connect to the internet to download it.'**
  String get needInternetToDownload;

  /// No description provided for @libraryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No files yet'**
  String get libraryEmpty;

  /// No description provided for @resourceType.
  ///
  /// In en, this message translates to:
  /// **'{type, select, cours{Course} td{Tutorials} tp{Labs} textbook{Textbook} exercices_corriges{Solved exercises} exam{Exams} notes{Notes} memoire{Thesis} other{Other files}}'**
  String resourceType(String type);

  /// No description provided for @trustLabel.
  ///
  /// In en, this message translates to:
  /// **'{label, select, official{Official} verified{Verified} other{Student}}'**
  String trustLabel(String label);

  /// No description provided for @backToWhereYouStopped.
  ///
  /// In en, this message translates to:
  /// **'Back to where you stopped'**
  String get backToWhereYouStopped;

  /// No description provided for @markAsDone.
  ///
  /// In en, this message translates to:
  /// **'Mark as done'**
  String get markAsDone;

  /// No description provided for @lessonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get lessonDone;

  /// No description provided for @nextLesson.
  ///
  /// In en, this message translates to:
  /// **'Next lesson'**
  String get nextLesson;

  /// No description provided for @backToModule.
  ///
  /// In en, this message translates to:
  /// **'Back to the module'**
  String get backToModule;

  /// No description provided for @lessonLanguage.
  ///
  /// In en, this message translates to:
  /// **'Lesson language'**
  String get lessonLanguage;

  /// No description provided for @lessonNotFound.
  ///
  /// In en, this message translates to:
  /// **'This lesson is no longer on your phone.'**
  String get lessonNotFound;

  /// No description provided for @needInternetForFile.
  ///
  /// In en, this message translates to:
  /// **'Files open online for now. Connect to the internet.'**
  String get needInternetForFile;

  /// No description provided for @fileOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open this file.'**
  String get fileOpenFailed;

  /// No description provided for @feedEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing to review yet'**
  String get feedEmptyTitle;

  /// No description provided for @feedEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Download a module and its flashcards appear here.'**
  String get feedEmptyBody;

  /// No description provided for @openModules.
  ///
  /// In en, this message translates to:
  /// **'Open my modules'**
  String get openModules;

  /// No description provided for @feedDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'All done for now'**
  String get feedDoneTitle;

  /// No description provided for @feedDoneNext.
  ///
  /// In en, this message translates to:
  /// **'Next cards at {time}'**
  String feedDoneNext(String time);

  /// No description provided for @feedDoneNoMore.
  ///
  /// In en, this message translates to:
  /// **'Read a lesson to unlock new cards.'**
  String get feedDoneNoMore;

  /// No description provided for @practiseAhead.
  ///
  /// In en, this message translates to:
  /// **'Practise ahead'**
  String get practiseAhead;

  /// No description provided for @tapToFlip.
  ///
  /// In en, this message translates to:
  /// **'Tap to see the answer'**
  String get tapToFlip;

  /// No description provided for @knewIt.
  ///
  /// In en, this message translates to:
  /// **'I knew it'**
  String get knewIt;

  /// No description provided for @again.
  ///
  /// In en, this message translates to:
  /// **'Again'**
  String get again;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @streakLabel.
  ///
  /// In en, this message translates to:
  /// **'Day streak'**
  String get streakLabel;

  /// No description provided for @xpLabel.
  ///
  /// In en, this message translates to:
  /// **'XP'**
  String get xpLabel;

  /// No description provided for @todayMinutes.
  ///
  /// In en, this message translates to:
  /// **'{done} / {goal} min today'**
  String todayMinutes(int done, int goal);

  /// No description provided for @likeLabel.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get likeLabel;

  /// No description provided for @saveLabel.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveLabel;

  /// No description provided for @quizTitle.
  ///
  /// In en, this message translates to:
  /// **'Quiz'**
  String get quizTitle;

  /// No description provided for @takeQuiz.
  ///
  /// In en, this message translates to:
  /// **'Take the quiz'**
  String get takeQuiz;

  /// No description provided for @questionOf.
  ///
  /// In en, this message translates to:
  /// **'Question {n} of {total}'**
  String questionOf(int n, int total);

  /// No description provided for @quizCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct!'**
  String get quizCorrect;

  /// No description provided for @quizWrong.
  ///
  /// In en, this message translates to:
  /// **'Not quite'**
  String get quizWrong;

  /// No description provided for @quizNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get quizNext;

  /// No description provided for @quizSeeResults.
  ///
  /// In en, this message translates to:
  /// **'See results'**
  String get quizSeeResults;

  /// No description provided for @quizScore.
  ///
  /// In en, this message translates to:
  /// **'{correct} / {total} correct'**
  String quizScore(int correct, int total);

  /// No description provided for @quizCardsBack.
  ///
  /// In en, this message translates to:
  /// **'The cards of this lesson are back in your feed.'**
  String get quizCardsBack;

  /// No description provided for @quizFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get quizFinish;

  /// No description provided for @quizNoQuestions.
  ///
  /// In en, this message translates to:
  /// **'No questions for this lesson yet.'**
  String get quizNoQuestions;

  /// No description provided for @trueLabel.
  ///
  /// In en, this message translates to:
  /// **'True'**
  String get trueLabel;

  /// No description provided for @falseLabel.
  ///
  /// In en, this message translates to:
  /// **'False'**
  String get falseLabel;

  /// No description provided for @noteIntuition.
  ///
  /// In en, this message translates to:
  /// **'In plain words'**
  String get noteIntuition;

  /// No description provided for @noteMistake.
  ///
  /// In en, this message translates to:
  /// **'Common mistake'**
  String get noteMistake;

  /// No description provided for @noteExamTip.
  ///
  /// In en, this message translates to:
  /// **'Exam tip'**
  String get noteExamTip;

  /// No description provided for @noteRemember.
  ///
  /// In en, this message translates to:
  /// **'Remember'**
  String get noteRemember;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @themeLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeLabel;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @minutesStudied.
  ///
  /// In en, this message translates to:
  /// **'Minutes studied'**
  String get minutesStudied;

  /// No description provided for @lessonsDoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Lessons done'**
  String get lessonsDoneLabel;

  /// No description provided for @savedCards.
  ///
  /// In en, this message translates to:
  /// **'Saved cards'**
  String get savedCards;

  /// No description provided for @savedCardsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Tap the bookmark on a flashcard to keep it here.'**
  String get savedCardsEmpty;

  /// No description provided for @allSynced.
  ///
  /// In en, this message translates to:
  /// **'Everything is synced'**
  String get allSynced;

  /// No description provided for @pendingSync.
  ///
  /// In en, this message translates to:
  /// **'{count} changes waiting to sync'**
  String pendingSync(int count);

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// No description provided for @sendFeedback.
  ///
  /// In en, this message translates to:
  /// **'Send feedback'**
  String get sendFeedback;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String appVersion(String version);

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountBody.
  ///
  /// In en, this message translates to:
  /// **'Your profile, progress, streak, XP and messages are deleted from our servers, and this phone is cleared. This cannot be undone.'**
  String get deleteAccountBody;

  /// No description provided for @deleteAccountCheck.
  ///
  /// In en, this message translates to:
  /// **'I understand this cannot be undone'**
  String get deleteAccountCheck;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete everything'**
  String get deleteAccountConfirm;

  /// No description provided for @deleteAccountDone.
  ///
  /// In en, this message translates to:
  /// **'Your account was deleted.'**
  String get deleteAccountDone;

  /// No description provided for @chatTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatTitle;

  /// No description provided for @chatEmpty.
  ///
  /// In en, this message translates to:
  /// **'No messages yet. Say hello to your classmates!'**
  String get chatEmpty;

  /// No description provided for @chatHint.
  ///
  /// In en, this message translates to:
  /// **'Write a message'**
  String get chatHint;

  /// No description provided for @chatSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSend;

  /// No description provided for @chatSending.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get chatSending;

  /// No description provided for @chatFailed.
  ///
  /// In en, this message translates to:
  /// **'Not sent. Tap to retry.'**
  String get chatFailed;

  /// No description provided for @chatTranslated.
  ///
  /// In en, this message translates to:
  /// **'Translated'**
  String get chatTranslated;

  /// No description provided for @chatShowOriginal.
  ///
  /// In en, this message translates to:
  /// **'Show original'**
  String get chatShowOriginal;

  /// No description provided for @chatShowTranslation.
  ///
  /// In en, this message translates to:
  /// **'Show translation'**
  String get chatShowTranslation;

  /// No description provided for @chatTranslating.
  ///
  /// In en, this message translates to:
  /// **'translating...'**
  String get chatTranslating;

  /// No description provided for @chatReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get chatReport;

  /// No description provided for @chatBlock.
  ///
  /// In en, this message translates to:
  /// **'Block @{name}'**
  String chatBlock(String name);

  /// No description provided for @chatDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get chatDelete;

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report this message'**
  String get reportTitle;

  /// No description provided for @reportSpam.
  ///
  /// In en, this message translates to:
  /// **'Spam'**
  String get reportSpam;

  /// No description provided for @reportHarassment.
  ///
  /// In en, this message translates to:
  /// **'Harassment or insults'**
  String get reportHarassment;

  /// No description provided for @reportWrong.
  ///
  /// In en, this message translates to:
  /// **'Wrong information'**
  String get reportWrong;

  /// No description provided for @reportOther.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get reportOther;

  /// No description provided for @reportDetails.
  ///
  /// In en, this message translates to:
  /// **'Details (optional)'**
  String get reportDetails;

  /// No description provided for @reportSend.
  ///
  /// In en, this message translates to:
  /// **'Send report'**
  String get reportSend;

  /// No description provided for @reportThanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks. We will look at it.'**
  String get reportThanks;

  /// No description provided for @blockConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Block @{name}?'**
  String blockConfirmTitle(String name);

  /// No description provided for @blockConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You will no longer see each other\'s messages.'**
  String get blockConfirmBody;

  /// No description provided for @blockDone.
  ///
  /// In en, this message translates to:
  /// **'@{name} is blocked.'**
  String blockDone(String name);

  /// No description provided for @updateTitle.
  ///
  /// In en, this message translates to:
  /// **'A new version is needed'**
  String get updateTitle;

  /// No description provided for @updateBody.
  ///
  /// In en, this message translates to:
  /// **'This version of KampusLink is too old to keep your progress safe. Please update to continue.'**
  String get updateBody;

  /// No description provided for @caseLabel.
  ///
  /// In en, this message translates to:
  /// **'Case'**
  String get caseLabel;

  /// No description provided for @demoBadge.
  ///
  /// In en, this message translates to:
  /// **'DEMO'**
  String get demoBadge;

  /// No description provided for @continueCase.
  ///
  /// In en, this message translates to:
  /// **'Continue the case'**
  String get continueCase;

  /// No description provided for @roleHook.
  ///
  /// In en, this message translates to:
  /// **'The case'**
  String get roleHook;

  /// No description provided for @roleClue.
  ///
  /// In en, this message translates to:
  /// **'Clue'**
  String get roleClue;

  /// No description provided for @roleStep.
  ///
  /// In en, this message translates to:
  /// **'Step'**
  String get roleStep;

  /// No description provided for @roleCommit.
  ///
  /// In en, this message translates to:
  /// **'Your guess'**
  String get roleCommit;

  /// No description provided for @roleReveal.
  ///
  /// In en, this message translates to:
  /// **'The answer'**
  String get roleReveal;

  /// No description provided for @roleQuiz.
  ///
  /// In en, this message translates to:
  /// **'Quick check'**
  String get roleQuiz;

  /// No description provided for @roleTakeaway.
  ///
  /// In en, this message translates to:
  /// **'Remember this'**
  String get roleTakeaway;

  /// No description provided for @lockGuess.
  ///
  /// In en, this message translates to:
  /// **'Lock my guess'**
  String get lockGuess;

  /// No description provided for @lockGuessFirst.
  ///
  /// In en, this message translates to:
  /// **'Lock a guess before you see the answer'**
  String get lockGuessFirst;

  /// No description provided for @guessRight.
  ///
  /// In en, this message translates to:
  /// **'You guessed right!'**
  String get guessRight;

  /// No description provided for @guessWrong.
  ///
  /// In en, this message translates to:
  /// **'Not this time. Here is why:'**
  String get guessWrong;

  /// No description provided for @swipeHint.
  ///
  /// In en, this message translates to:
  /// **'Swipe to see the answer'**
  String get swipeHint;

  /// No description provided for @caseDone.
  ///
  /// In en, this message translates to:
  /// **'Case solved'**
  String get caseDone;
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
