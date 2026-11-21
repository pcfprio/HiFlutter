import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:material_ui/material_ui.dart' show GlobalMaterialLocalizations;

import 'generated/generated_suite_localizations.dart';
import 'generated/generated_suite_localizations_en.dart';
import 'generated/generated_suite_localizations_zh.dart';

/// Semantic illustration category for presenting a [HiError].
///
/// UI views such as `HiErrorView` map each value to a Material icon or custom
/// artwork without leaking low-level error subtypes.
enum HiErrorIllustration {
  /// Network connectivity problem (offline, DNS failure, etc.).
  network,

  /// Request or operation timed out.
  timeout,

  /// Authentication required before continuing.
  unauthorized,

  /// Authenticated caller does not have permission.
  forbidden,

  /// Requested content could not be found.
  notFound,

  /// Server-side or backend failure.
  server,

  /// Response or stored data could not be decoded.
  data,

  /// Generic or storage failure.
  generic,
}

/// Localized title, description, and illustration category derived from a
/// [HiError].
///
/// When [shouldDisplay] is `false` (for [HiErrorDisplay.none]), [title] and
/// [message] are empty strings and [illustration] is `null`.
final class HiErrorMessage {
  /// Creates a localized error presentation descriptor.
  const HiErrorMessage({
    required this.title,
    required this.message,
    this.illustration,
    this.shouldDisplay = true,
  });

  /// Sentinel descriptor for [HiErrorDisplay.none], indicating that the error
  /// should not be shown to end users.
  const HiErrorMessage.none()
    : title = '',
      message = '',
      illustration = null,
      shouldDisplay = false;

  /// Short localized heading for the error.
  final String title;

  /// Localized explanation or detail message for the error.
  final String message;

  /// Illustration category associated with the error, or `null` when
  /// [shouldDisplay] is `false`.
  final HiErrorIllustration? illustration;

  /// Whether this error should be rendered in the UI.
  final bool shouldDisplay;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiErrorMessage &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          message == other.message &&
          illustration == other.illustration &&
          shouldDisplay == other.shouldDisplay;

  @override
  int get hashCode => Object.hash(title, message, illustration, shouldDisplay);

  @override
  String toString() =>
      'HiErrorMessage(shouldDisplay: $shouldDisplay, '
      'illustration: $illustration, title: $title, message: $message)';
}

/// Localized default strings and [HiError] display mappings for
/// `hiflutter_suite` components.
///
/// Use [HiSuiteLocalizations.of] inside widgets. When no
/// `LocalizationsDelegate<HiSuiteLocalizations>` is registered, [of] falls
/// back to built-in Chinese or English defaults based on
/// `Localizations.maybeLocaleOf(context)` without throwing.
///
/// To override specific strings across an app, subclass
/// [HiSuiteLocalizations] and register a custom
/// `LocalizationsDelegate<HiSuiteLocalizations>` in
/// `MaterialApp.localizationsDelegates`.
class HiSuiteLocalizations {
  /// Creates localized strings defaulting to [locale]'s built-in translations
  /// (Chinese when `locale.languageCode == 'zh'`, otherwise English).
  HiSuiteLocalizations([Locale locale = const Locale('en')])
    : _generated = _resolveGenerated(locale);

  static final HiSuiteLocalizations _en = HiSuiteLocalizations(
    const Locale('en'),
  );
  static final HiSuiteLocalizations _zh = HiSuiteLocalizations(
    const Locale('zh'),
  );

  final GeneratedSuiteLocalizations _generated;

  static GeneratedSuiteLocalizations _resolveGenerated(Locale? locale) =>
      locale?.languageCode == 'zh'
      ? GeneratedSuiteLocalizationsZh()
      : GeneratedSuiteLocalizationsEn();

  /// Localizations delegate providing the built-in English and Chinese strings.
  static const LocalizationsDelegate<HiSuiteLocalizations> delegate =
      _HiSuiteLocalizationsDelegate();

  /// Convenience list combining [delegate] and
  /// `GlobalMaterialLocalizations.delegates`.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        ...GlobalMaterialLocalizations.delegates,
      ];

  /// Locales supported by the built-in translations (`en` and `zh`).
  static const List<Locale> supportedLocales =
      GeneratedSuiteLocalizations.supportedLocales;

  /// Returns the built-in [HiSuiteLocalizations] for [locale], defaulting to
  /// English when [locale] is `null` or unsupported.
  static HiSuiteLocalizations forLocale(Locale? locale) =>
      locale?.languageCode == 'zh' ? _zh : _en;

  /// Resolves the active [HiSuiteLocalizations] from [context].
  ///
  /// Prefers a registered `LocalizationsDelegate<HiSuiteLocalizations>`, and
  /// otherwise falls back to built-in Chinese or English defaults based on
  /// `Localizations.maybeLocaleOf(context)`. Never throws when no localization
  /// widgets exist above [context].
  static HiSuiteLocalizations of(BuildContext context) {
    final registered = Localizations.of<HiSuiteLocalizations>(
      context,
      HiSuiteLocalizations,
    );
    if (registered != null) return registered;
    return forLocale(Localizations.maybeLocaleOf(context));
  }

  /// Semantic accessibility label for `HiLoadingView`.
  String get loadingLabel => _generated.loadingLabel;

  /// Default title shown by `HiEmptyView`.
  String get emptyTitle => _generated.emptyTitle;

  /// Default label for retry action buttons.
  String get retryLabel => _generated.retryLabel;

  /// Label shown in `HiLoadMoreFooter` while loading the next page.
  String get loadMoreLoadingLabel => _generated.loadMoreLoadingLabel;

  /// Label shown in `HiLoadMoreFooter` when more items can be loaded.
  String get loadMorePromptLabel => _generated.loadMorePromptLabel;

  /// Label shown in `HiLoadMoreFooter` when all items have been loaded.
  String get loadMoreNoMoreLabel => _generated.loadMoreNoMoreLabel;

  /// Label shown in `HiLoadMoreFooter` when loading the next page fails.
  String get loadMoreFailedLabel => _generated.loadMoreFailedLabel;

  /// Default title for [HiErrorDisplay.network].
  String get errorNetworkTitle => _generated.errorNetworkTitle;

  /// Default description for [HiErrorDisplay.network].
  String get errorNetworkMessage => _generated.errorNetworkMessage;

  /// Default title for [HiErrorDisplay.timeout].
  String get errorTimeoutTitle => _generated.errorTimeoutTitle;

  /// Default description for [HiErrorDisplay.timeout].
  String get errorTimeoutMessage => _generated.errorTimeoutMessage;

  /// Default title for [HiErrorDisplay.unauthorized].
  String get errorUnauthorizedTitle => _generated.errorUnauthorizedTitle;

  /// Default description for [HiErrorDisplay.unauthorized].
  String get errorUnauthorizedMessage => _generated.errorUnauthorizedMessage;

  /// Default title for [HiErrorDisplay.forbidden].
  String get errorForbiddenTitle => _generated.errorForbiddenTitle;

  /// Default description for [HiErrorDisplay.forbidden].
  String get errorForbiddenMessage => _generated.errorForbiddenMessage;

  /// Default title for [HiErrorDisplay.notFound].
  String get errorNotFoundTitle => _generated.errorNotFoundTitle;

  /// Default description for [HiErrorDisplay.notFound].
  String get errorNotFoundMessage => _generated.errorNotFoundMessage;

  /// Default title for [HiErrorDisplay.server].
  String get errorServerTitle => _generated.errorServerTitle;

  /// Default description for [HiErrorDisplay.server].
  String get errorServerMessage => _generated.errorServerMessage;

  /// Default title for [HiErrorDisplay.data].
  String get errorDataTitle => _generated.errorDataTitle;

  /// Default description for [HiErrorDisplay.data].
  String get errorDataMessage => _generated.errorDataMessage;

  /// Default title for [HiErrorDisplay.generic].
  String get errorGenericTitle => _generated.errorGenericTitle;

  /// Default description for [HiErrorDisplay.generic].
  String get errorGenericMessage => _generated.errorGenericMessage;

  /// Maps [error] into a localized [HiErrorMessage] according to its
  /// [HiError.display] category.
  ///
  /// Uses a non-blank [HiError.message] as the description when present. For
  /// [HiErrorDisplay.none], returns [HiErrorMessage.none] so callers do not
  /// display cancelled or silent errors.
  HiErrorMessage describeError(HiError error) {
    final display = error.display;
    if (display == HiErrorDisplay.none) {
      return const HiErrorMessage.none();
    }
    final detail = error.message?.trim();
    final hasDetail = detail != null && detail.isNotEmpty;

    return switch (display) {
      HiErrorDisplay.network => HiErrorMessage(
        title: errorNetworkTitle,
        message: hasDetail ? detail : errorNetworkMessage,
        illustration: HiErrorIllustration.network,
      ),
      HiErrorDisplay.timeout => HiErrorMessage(
        title: errorTimeoutTitle,
        message: hasDetail ? detail : errorTimeoutMessage,
        illustration: HiErrorIllustration.timeout,
      ),
      HiErrorDisplay.unauthorized => HiErrorMessage(
        title: errorUnauthorizedTitle,
        message: hasDetail ? detail : errorUnauthorizedMessage,
        illustration: HiErrorIllustration.unauthorized,
      ),
      HiErrorDisplay.forbidden => HiErrorMessage(
        title: errorForbiddenTitle,
        message: hasDetail ? detail : errorForbiddenMessage,
        illustration: HiErrorIllustration.forbidden,
      ),
      HiErrorDisplay.notFound => HiErrorMessage(
        title: errorNotFoundTitle,
        message: hasDetail ? detail : errorNotFoundMessage,
        illustration: HiErrorIllustration.notFound,
      ),
      HiErrorDisplay.server => HiErrorMessage(
        title: errorServerTitle,
        message: hasDetail ? detail : errorServerMessage,
        illustration: HiErrorIllustration.server,
      ),
      HiErrorDisplay.data => HiErrorMessage(
        title: errorDataTitle,
        message: hasDetail ? detail : errorDataMessage,
        illustration: HiErrorIllustration.data,
      ),
      HiErrorDisplay.generic => HiErrorMessage(
        title: errorGenericTitle,
        message: hasDetail ? detail : errorGenericMessage,
        illustration: HiErrorIllustration.generic,
      ),
      HiErrorDisplay.none => const HiErrorMessage.none(),
    };
  }
}

class _HiSuiteLocalizationsDelegate
    extends LocalizationsDelegate<HiSuiteLocalizations> {
  const _HiSuiteLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      GeneratedSuiteLocalizations.delegate.isSupported(locale);

  @override
  Future<HiSuiteLocalizations> load(Locale locale) =>
      SynchronousFuture<HiSuiteLocalizations>(
        HiSuiteLocalizations.forLocale(locale),
      );

  @override
  bool shouldReload(_HiSuiteLocalizationsDelegate old) => false;
}
