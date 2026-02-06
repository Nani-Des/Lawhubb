import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('en'),
    Locale('es'),
    Locale('fr')
  ];

  /// No description provided for @findYourLegalAlly.
  ///
  /// In en, this message translates to:
  /// **'Find your legal Ally'**
  String get findYourLegalAlly;

  /// No description provided for @tapToAskQuestions.
  ///
  /// In en, this message translates to:
  /// **'Tap to ask questions on various topics.'**
  String get tapToAskQuestions;

  /// No description provided for @attorneysNearYou.
  ///
  /// In en, this message translates to:
  /// **'Attorneys near you!'**
  String get attorneysNearYou;

  /// No description provided for @noChamberFound.
  ///
  /// In en, this message translates to:
  /// **'No Chamber found'**
  String get noChamberFound;

  /// No description provided for @findLawyerOrDescribe.
  ///
  /// In en, this message translates to:
  /// **'Find a lawyer? or describe your legal issue...'**
  String get findLawyerOrDescribe;

  /// No description provided for @chambers.
  ///
  /// In en, this message translates to:
  /// **'Chambers'**
  String get chambers;

  /// No description provided for @lawInsights.
  ///
  /// In en, this message translates to:
  /// **'Law Insights'**
  String get lawInsights;

  /// No description provided for @socialHubb.
  ///
  /// In en, this message translates to:
  /// **'SocialHubb'**
  String get socialHubb;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @createPost.
  ///
  /// In en, this message translates to:
  /// **'Create Post'**
  String get createPost;

  /// No description provided for @live.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get live;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password'**
  String get forgotPassword;

  /// No description provided for @needAnAccount.
  ///
  /// In en, this message translates to:
  /// **'Need an account'**
  String get needAnAccount;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @signInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInWithGoogle;

  /// No description provided for @bookAppointment.
  ///
  /// In en, this message translates to:
  /// **'Book appointment'**
  String get bookAppointment;

  /// No description provided for @findLawyer.
  ///
  /// In en, this message translates to:
  /// **'Find lawyer'**
  String get findLawyer;

  /// No description provided for @lawServices.
  ///
  /// In en, this message translates to:
  /// **'Law services'**
  String get lawServices;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First Name'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In en, this message translates to:
  /// **'Last Name'**
  String get lastName;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get createAccount;

  /// No description provided for @book_appointment.
  ///
  /// In en, this message translates to:
  /// **'How do I book an appointment with a lawyer?'**
  String get book_appointment;

  /// No description provided for @type_of_lawyer.
  ///
  /// In en, this message translates to:
  /// **'How do I know what type of lawyer I need?'**
  String get type_of_lawyer;

  /// No description provided for @services_provided.
  ///
  /// In en, this message translates to:
  /// **'What services does the chamber of law provide?'**
  String get services_provided;

  /// No description provided for @sue_someone.
  ///
  /// In en, this message translates to:
  /// **'What should I do when I want to sue someone?'**
  String get sue_someone;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'LawHubb'**
  String get appTitle;

  /// No description provided for @locationPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'We Need Your Location'**
  String get locationPermissionTitle;

  /// No description provided for @locationPermissionDescription.
  ///
  /// In en, this message translates to:
  /// **'To provide you with the best experience, we need your location to find Lawyers and Chambers near you.'**
  String get locationPermissionDescription;

  /// No description provided for @allowLocationButton.
  ///
  /// In en, this message translates to:
  /// **'Allow Location Access'**
  String get allowLocationButton;

  /// No description provided for @skipButton.
  ///
  /// In en, this message translates to:
  /// **'Skip for Now'**
  String get skipButton;

  /// No description provided for @platformOverview.
  ///
  /// In en, this message translates to:
  /// **'Platform Overview'**
  String get platformOverview;

  /// No description provided for @growing.
  ///
  /// In en, this message translates to:
  /// **'Growing'**
  String get growing;

  /// No description provided for @activeLawyersCount.
  ///
  /// In en, this message translates to:
  /// **'2,500+'**
  String get activeLawyersCount;

  /// No description provided for @activeLawyersLabel.
  ///
  /// In en, this message translates to:
  /// **'Active Lawyers'**
  String get activeLawyersLabel;

  /// No description provided for @lawChambersCount.
  ///
  /// In en, this message translates to:
  /// **'150+'**
  String get lawChambersCount;

  /// No description provided for @lawChambersLabel.
  ///
  /// In en, this message translates to:
  /// **'Law Chambers'**
  String get lawChambersLabel;

  /// No description provided for @casesResolvedCount.
  ///
  /// In en, this message translates to:
  /// **'10k+'**
  String get casesResolvedCount;

  /// No description provided for @casesResolvedLabel.
  ///
  /// In en, this message translates to:
  /// **'Cases Resolved'**
  String get casesResolvedLabel;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good Morning'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good Afternoon'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good Evening'**
  String get goodEvening;

  /// No description provided for @loggedInMessage.
  ///
  /// In en, this message translates to:
  /// **'Do you need any legal aid ?'**
  String get loggedInMessage;

  /// No description provided for @notLoggedInMessage.
  ///
  /// In en, this message translates to:
  /// **'Do you need any legal aid ?'**
  String get notLoggedInMessage;

  /// No description provided for @searchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search lawyers, chambers...'**
  String get searchPlaceholder;

  /// No description provided for @searchFunctionalityComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Search functionality coming soon'**
  String get searchFunctionalityComingSoon;

  /// No description provided for @quickServices.
  ///
  /// In en, this message translates to:
  /// **'Quick Services'**
  String get quickServices;

  /// No description provided for @available24_7.
  ///
  /// In en, this message translates to:
  /// **'24/7 Available'**
  String get available24_7;

  /// No description provided for @emergencyLegalHelp.
  ///
  /// In en, this message translates to:
  /// **'AI Assistant / Help'**
  String get emergencyLegalHelp;

  /// No description provided for @immediateAssistance.
  ///
  /// In en, this message translates to:
  /// **'Immediate assistance'**
  String get immediateAssistance;

  /// No description provided for @bookConsultation.
  ///
  /// In en, this message translates to:
  /// **'Bookings/ Consultation'**
  String get bookConsultation;

  /// No description provided for @scheduleWithExperts.
  ///
  /// In en, this message translates to:
  /// **'Schedule with experts'**
  String get scheduleWithExperts;

  /// No description provided for @pleaseSignInToBook.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to book consultations'**
  String get pleaseSignInToBook;

  /// No description provided for @legalCommunity.
  ///
  /// In en, this message translates to:
  /// **'Legal Community'**
  String get legalCommunity;

  /// No description provided for @connectAndDiscuss.
  ///
  /// In en, this message translates to:
  /// **'Connect & discuss'**
  String get connectAndDiscuss;

  /// No description provided for @useSocialHub.
  ///
  /// In en, this message translates to:
  /// **'Use bottom navigation to access Social Hub'**
  String get useSocialHub;

  /// No description provided for @legalResources.
  ///
  /// In en, this message translates to:
  /// **'Bookshop'**
  String get legalResources;

  /// No description provided for @browseLibrary.
  ///
  /// In en, this message translates to:
  /// **'Browse library'**
  String get browseLibrary;

  /// No description provided for @useLawInsights.
  ///
  /// In en, this message translates to:
  /// **'Use bottom navigation to access Law Insights'**
  String get useLawInsights;

  /// No description provided for @trendingLegalTopics.
  ///
  /// In en, this message translates to:
  /// **'Trending Legal Topics'**
  String get trendingLegalTopics;

  /// No description provided for @hot.
  ///
  /// In en, this message translates to:
  /// **'Hot'**
  String get hot;

  /// No description provided for @employmentLaw.
  ///
  /// In en, this message translates to:
  /// **'Employment Law'**
  String get employmentLaw;

  /// No description provided for @employmentLawDiscussions.
  ///
  /// In en, this message translates to:
  /// **'245 discussions'**
  String get employmentLawDiscussions;

  /// No description provided for @propertyRights.
  ///
  /// In en, this message translates to:
  /// **'Property Rights'**
  String get propertyRights;

  /// No description provided for @propertyRightsDiscussions.
  ///
  /// In en, this message translates to:
  /// **'189 discussions'**
  String get propertyRightsDiscussions;

  /// No description provided for @familyLaw.
  ///
  /// In en, this message translates to:
  /// **'Family Law'**
  String get familyLaw;

  /// No description provided for @familyLawDiscussions.
  ///
  /// In en, this message translates to:
  /// **'156 discussions'**
  String get familyLawDiscussions;

  /// No description provided for @businessLaw.
  ///
  /// In en, this message translates to:
  /// **'Business Law'**
  String get businessLaw;

  /// No description provided for @businessLawDiscussions.
  ///
  /// In en, this message translates to:
  /// **'134 discussions'**
  String get businessLawDiscussions;

  /// No description provided for @exploreDiscussions.
  ///
  /// In en, this message translates to:
  /// **'Explore {title} discussions'**
  String exploreDiscussions(Object title);

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @spanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get spanish;

  /// No description provided for @french.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get french;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get recentActivity;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @consultationScheduled.
  ///
  /// In en, this message translates to:
  /// **'Consultation Scheduled'**
  String get consultationScheduled;

  /// No description provided for @consultationScheduledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'With Adv. Sarah Johnson - Tomorrow 2:00 PM'**
  String get consultationScheduledSubtitle;

  /// No description provided for @twoHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'2 hours ago'**
  String get twoHoursAgo;

  /// No description provided for @newMessage.
  ///
  /// In en, this message translates to:
  /// **'New Message'**
  String get newMessage;

  /// No description provided for @newMessageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'From Legal Community Forum'**
  String get newMessageSubtitle;

  /// No description provided for @fiveHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'5 hours ago'**
  String get fiveHoursAgo;

  /// No description provided for @documentSaved.
  ///
  /// In en, this message translates to:
  /// **'Document Saved'**
  String get documentSaved;

  /// No description provided for @documentSavedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Contract Template - Employment Law'**
  String get documentSavedSubtitle;

  /// No description provided for @oneDayAgo.
  ///
  /// In en, this message translates to:
  /// **'1 day ago'**
  String get oneDayAgo;

  /// No description provided for @editButton.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editButton;

  /// No description provided for @saveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveButton;

  /// No description provided for @region.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get region;

  /// No description provided for @mobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Mobile Number'**
  String get mobileNumber;

  /// No description provided for @noEmail.
  ///
  /// In en, this message translates to:
  /// **'No email'**
  String get noEmail;

  /// No description provided for @noRegion.
  ///
  /// In en, this message translates to:
  /// **'No region'**
  String get noRegion;

  /// No description provided for @bookings.
  ///
  /// In en, this message translates to:
  /// **'Bookings'**
  String get bookings;

  /// No description provided for @referAClient.
  ///
  /// In en, this message translates to:
  /// **'Refer A Client'**
  String get referAClient;

  /// No description provided for @referrals.
  ///
  /// In en, this message translates to:
  /// **'Referrals'**
  String get referrals;

  /// No description provided for @blockedUsers.
  ///
  /// In en, this message translates to:
  /// **'Blocked Users'**
  String get blockedUsers;

  /// No description provided for @manageBlockedUsers.
  ///
  /// In en, this message translates to:
  /// **'Manage blocked users'**
  String get manageBlockedUsers;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to permanently delete your account? This action cannot be undone.'**
  String get deleteAccountConfirmation;

  /// No description provided for @cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButton;

  /// No description provided for @deleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteButton;

  /// No description provided for @deleteButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteButtonLabel;

  /// No description provided for @logoutButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logoutButtonLabel;

  /// No description provided for @logoutButton.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logoutButton;

  /// No description provided for @noUserLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'No user is currently logged in'**
  String get noUserLoggedIn;

  /// No description provided for @lawyerReauthRequired.
  ///
  /// In en, this message translates to:
  /// **'Lawyers must log out and log in again to delete their account'**
  String get lawyerReauthRequired;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @accessDenied.
  ///
  /// In en, this message translates to:
  /// **'Access Denied'**
  String get accessDenied;

  /// No description provided for @onlyLawyersAccess.
  ///
  /// In en, this message translates to:
  /// **'Only Lawyers can access {action}.'**
  String onlyLawyersAccess(Object action);

  /// No description provided for @referralForm.
  ///
  /// In en, this message translates to:
  /// **'Referral Form'**
  String get referralForm;

  /// No description provided for @okButton.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get okButton;

  /// No description provided for @accountDeletedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Account deleted successfully. You are now logged out'**
  String get accountDeletedSuccess;

  /// No description provided for @logoutFailed.
  ///
  /// In en, this message translates to:
  /// **'Logout failed: {error}'**
  String logoutFailed(Object error);

  /// No description provided for @legalChambers.
  ///
  /// In en, this message translates to:
  /// **'Legal Chambers'**
  String get legalChambers;

  /// No description provided for @aiAssistant.
  ///
  /// In en, this message translates to:
  /// **'AI Assistant'**
  String get aiAssistant;

  /// No description provided for @viewReferrals.
  ///
  /// In en, this message translates to:
  /// **'View Referrals'**
  String get viewReferrals;

  /// No description provided for @searchChambersPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search legal chambers & lawyers...'**
  String get searchChambersPlaceholder;

  /// No description provided for @resources.
  ///
  /// In en, this message translates to:
  /// **'Resources'**
  String get resources;

  /// No description provided for @searchByNameOrCity.
  ///
  /// In en, this message translates to:
  /// **'Search by name or city...'**
  String get searchByNameOrCity;

  /// No description provided for @backOnlineSyncing.
  ///
  /// In en, this message translates to:
  /// **'Back online, syncing data...'**
  String get backOnlineSyncing;

  /// No description provided for @loadingOffline.
  ///
  /// In en, this message translates to:
  /// **'Loading (Offline)...'**
  String get loadingOffline;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @unknownCity.
  ///
  /// In en, this message translates to:
  /// **'Unknown City'**
  String get unknownCity;

  /// No description provided for @noContactInfo.
  ///
  /// In en, this message translates to:
  /// **'No Contact Info'**
  String get noContactInfo;

  /// No description provided for @unknownChamber.
  ///
  /// In en, this message translates to:
  /// **'Unknown Chamber'**
  String get unknownChamber;

  /// No description provided for @reviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviews;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @getALawyer.
  ///
  /// In en, this message translates to:
  /// **'Get A Lawyer'**
  String get getALawyer;

  /// No description provided for @tapToExplore.
  ///
  /// In en, this message translates to:
  /// **'Tap to explore'**
  String get tapToExplore;

  /// No description provided for @chamberEvents.
  ///
  /// In en, this message translates to:
  /// **'Chamber Events'**
  String get chamberEvents;

  /// No description provided for @chamberPractices.
  ///
  /// In en, this message translates to:
  /// **'Chamber Practices'**
  String get chamberPractices;

  /// No description provided for @tap.
  ///
  /// In en, this message translates to:
  /// **'Tap'**
  String get tap;

  /// No description provided for @tapHereToAddHospital.
  ///
  /// In en, this message translates to:
  /// **'Tap Here To Add Hospital'**
  String get tapHereToAddHospital;

  /// No description provided for @loadingHospital.
  ///
  /// In en, this message translates to:
  /// **'Loading Hospital..'**
  String get loadingHospital;

  /// No description provided for @loadingDots.
  ///
  /// In en, this message translates to:
  /// **'Loading ..'**
  String get loadingDots;

  /// No description provided for @searchDocuments.
  ///
  /// In en, this message translates to:
  /// **'Search title, author, category...'**
  String get searchDocuments;

  /// No description provided for @continueReading.
  ///
  /// In en, this message translates to:
  /// **'Continue Reading'**
  String get continueReading;

  /// No description provided for @allDocuments.
  ///
  /// In en, this message translates to:
  /// **'All Documents'**
  String get allDocuments;

  /// No description provided for @items.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String items(Object count);

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @untitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get untitled;

  /// No description provided for @free.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get free;

  /// No description provided for @complete.
  ///
  /// In en, this message translates to:
  /// **'complete'**
  String get complete;

  /// No description provided for @myNotes.
  ///
  /// In en, this message translates to:
  /// **'My Notes'**
  String get myNotes;

  /// No description provided for @noNotesYet.
  ///
  /// In en, this message translates to:
  /// **'No notes yet'**
  String get noNotesYet;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'{count} notes'**
  String notes(Object count);

  /// No description provided for @page.
  ///
  /// In en, this message translates to:
  /// **'Page {number}'**
  String page(Object number);

  /// No description provided for @books.
  ///
  /// In en, this message translates to:
  /// **'{count} Books'**
  String books(Object count);

  /// No description provided for @streak.
  ///
  /// In en, this message translates to:
  /// **'Streak {days}d'**
  String streak(Object days);

  /// No description provided for @uploadDocument.
  ///
  /// In en, this message translates to:
  /// **'Upload Document'**
  String get uploadDocument;

  /// No description provided for @selectPdfOrWordFile.
  ///
  /// In en, this message translates to:
  /// **'Select PDF or Word File'**
  String get selectPdfOrWordFile;

  /// No description provided for @selected.
  ///
  /// In en, this message translates to:
  /// **'Selected: {extension}'**
  String selected(Object extension);

  /// No description provided for @fieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get fieldTitle;

  /// No description provided for @fieldAuthor.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get fieldAuthor;

  /// No description provided for @fieldCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get fieldCategory;

  /// No description provided for @fieldDescription.
  ///
  /// In en, this message translates to:
  /// **'Preface / Description'**
  String get fieldDescription;

  /// No description provided for @fieldPrice.
  ///
  /// In en, this message translates to:
  /// **'Price (GHS)'**
  String get fieldPrice;

  /// No description provided for @uploadButton.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get uploadButton;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @selectPdfOrWordDocument.
  ///
  /// In en, this message translates to:
  /// **'Please select a PDF or Word document'**
  String get selectPdfOrWordDocument;

  /// No description provided for @uploadedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Uploaded Successfully!'**
  String get uploadedSuccessfully;

  /// No description provided for @available.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get available;

  /// No description provided for @bar.
  ///
  /// In en, this message translates to:
  /// **'Bar'**
  String get bar;

  /// No description provided for @practice.
  ///
  /// In en, this message translates to:
  /// **'Practice'**
  String get practice;

  /// No description provided for @yearOfCall.
  ///
  /// In en, this message translates to:
  /// **'Year of Call'**
  String get yearOfCall;

  /// No description provided for @notAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get notAvailable;

  /// No description provided for @naValue.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get naValue;

  /// No description provided for @experience.
  ///
  /// In en, this message translates to:
  /// **'Experience'**
  String get experience;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @messageLawyer.
  ///
  /// In en, this message translates to:
  /// **'Message Lawyer'**
  String get messageLawyer;

  /// No description provided for @bookButton.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get bookButton;

  /// No description provided for @lawyerIdMissing.
  ///
  /// In en, this message translates to:
  /// **'Lawyer ID is missing'**
  String get lawyerIdMissing;

  /// No description provided for @chamberIdMissing.
  ///
  /// In en, this message translates to:
  /// **'Chamber ID is missing'**
  String get chamberIdMissing;
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
      <String>['en', 'es', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
