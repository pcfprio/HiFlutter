import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'generated_suite_localizations_en.dart';
import 'generated_suite_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of GeneratedSuiteLocalizations
/// returned by `GeneratedSuiteLocalizations.of(context)`.
///
/// Applications need to include `GeneratedSuiteLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/generated_suite_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: GeneratedSuiteLocalizations.localizationsDelegates,
///   supportedLocales: GeneratedSuiteLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the GeneratedSuiteLocalizations.supportedLocales
/// property.
abstract class GeneratedSuiteLocalizations {
  GeneratedSuiteLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static GeneratedSuiteLocalizations of(BuildContext context) {
    return Localizations.of<GeneratedSuiteLocalizations>(
      context,
      GeneratedSuiteLocalizations,
    )!;
  }

  static const LocalizationsDelegate<GeneratedSuiteLocalizations> delegate =
      _GeneratedSuiteLocalizationsDelegate();

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
    Locale('zh'),
  ];

  /// No description provided for @loadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loadingLabel;

  /// No description provided for @emptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get emptyTitle;

  /// No description provided for @retryLabel.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryLabel;

  /// No description provided for @loadMoreLoadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Loading more...'**
  String get loadMoreLoadingLabel;

  /// No description provided for @loadMorePromptLabel.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMorePromptLabel;

  /// No description provided for @loadMoreNoMoreLabel.
  ///
  /// In en, this message translates to:
  /// **'No more items'**
  String get loadMoreNoMoreLabel;

  /// No description provided for @loadMoreFailedLabel.
  ///
  /// In en, this message translates to:
  /// **'Failed to load more'**
  String get loadMoreFailedLabel;

  /// No description provided for @errorNetworkTitle.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get errorNetworkTitle;

  /// No description provided for @errorNetworkMessage.
  ///
  /// In en, this message translates to:
  /// **'Check your network connection and try again.'**
  String get errorNetworkMessage;

  /// No description provided for @errorTimeoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Request timed out'**
  String get errorTimeoutTitle;

  /// No description provided for @errorTimeoutMessage.
  ///
  /// In en, this message translates to:
  /// **'The operation took too long. Please try again.'**
  String get errorTimeoutMessage;

  /// No description provided for @errorUnauthorizedTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in required'**
  String get errorUnauthorizedTitle;

  /// No description provided for @errorUnauthorizedMessage.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to continue.'**
  String get errorUnauthorizedMessage;

  /// No description provided for @errorForbiddenTitle.
  ///
  /// In en, this message translates to:
  /// **'Access denied'**
  String get errorForbiddenTitle;

  /// No description provided for @errorForbiddenMessage.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to view this content.'**
  String get errorForbiddenMessage;

  /// No description provided for @errorNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get errorNotFoundTitle;

  /// No description provided for @errorNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'The requested content could not be found.'**
  String get errorNotFoundMessage;

  /// No description provided for @errorServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Server error'**
  String get errorServerTitle;

  /// No description provided for @errorServerMessage.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong on the server. Please try again later.'**
  String get errorServerMessage;

  /// No description provided for @errorDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Unable to load data'**
  String get errorDataTitle;

  /// No description provided for @errorDataMessage.
  ///
  /// In en, this message translates to:
  /// **'The data format could not be read.'**
  String get errorDataMessage;

  /// No description provided for @errorGenericTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorGenericTitle;

  /// No description provided for @errorGenericMessage.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred. Please try again.'**
  String get errorGenericMessage;
}

class _GeneratedSuiteLocalizationsDelegate
    extends LocalizationsDelegate<GeneratedSuiteLocalizations> {
  const _GeneratedSuiteLocalizationsDelegate();

  @override
  Future<GeneratedSuiteLocalizations> load(Locale locale) {
    return SynchronousFuture<GeneratedSuiteLocalizations>(
      lookupGeneratedSuiteLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_GeneratedSuiteLocalizationsDelegate old) => false;
}

GeneratedSuiteLocalizations lookupGeneratedSuiteLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return GeneratedSuiteLocalizationsEn();
    case 'zh':
      return GeneratedSuiteLocalizationsZh();
  }

  throw FlutterError(
    'GeneratedSuiteLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
