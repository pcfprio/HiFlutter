/// Visual metrics and spacing constants for HiFlutter Suite UI components.
///
/// Values align with the cross-platform HiIOS and HiAndroid `SuiteCore`
/// design contracts on a Material 3 baseline.
abstract final class HiSuiteMetrics {
  /// Minimum height of a standard list row (`52.0`), matching the iOS and
  /// Android list row ergonomics.
  static const double listRowMinHeight = 52.0;

  /// Height of the persistent pill search field (`48.0`).
  static const double searchFieldHeight = 48.0;

  /// Minimum height of a primary action button (`48.0`).
  static const double primaryButtonMinHeight = 48.0;

  /// Minimum interactive touch target size (`48.0`).
  static const double minTouchTarget = 48.0;

  /// Horizontal safe margin from screen edges (`16.0`), shared by list
  /// content, snackbars, and section headers.
  static const double horizontalSafeMargin = 16.0;

  /// Corner radius of action menus (`16.0`).
  static const double menuBorderRadius = 16.0;

  /// Corner radius of anchored tooltips (`14.0`).
  static const double tooltipBorderRadius = 14.0;

  /// Minimum height of the pagination load-more footer (`52.0`).
  static const double loadMoreFooterMinHeight = 52.0;

  /// Vertical padding around the pagination load-more footer (`12.0`).
  static const double loadMoreFooterVerticalPadding = 12.0;

  /// Diameter of the primary page loading spinner (`48.0`), enlarged one step
  /// beyond the Material default (`36.0`).
  static const double pageLoadingIndicatorSize = 48.0;

  /// Diameter of the compact inline loading spinner (`18.0`), used inside
  /// load-more footers and compact controls.
  static const double inlineLoadingIndicatorSize = 18.0;

  /// Default padding around centered state views (`24.0`).
  static const double stateViewPadding = 24.0;

  /// Default vertical spacing between a state view icon or illustration and its
  /// title (`16.0`).
  static const double stateViewIconSpacing = 16.0;

  /// Default vertical spacing between a state view title and its description
  /// (`8.0`).
  static const double stateViewTextSpacing = 8.0;

  /// Default vertical spacing above the primary action in a state view
  /// (`24.0`).
  static const double stateViewActionSpacing = 24.0;

  /// Default icon size inside centered state views (`48.0`).
  static const double stateViewIconSize = 48.0;

  /// Corner radius of primary action buttons (`12.0`).
  static const double buttonBorderRadius = 12.0;

  /// Standard small spacing unit (`8.0`).
  static const double spacingSmall = 8.0;

  /// Standard medium spacing unit (`12.0`).
  static const double spacingMedium = 12.0;

  /// Standard large spacing unit (`16.0`).
  static const double spacingLarge = 16.0;

  /// Standard extra-large spacing unit (`24.0`).
  static const double spacingExtraLarge = 24.0;
}
