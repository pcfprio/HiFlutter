import 'package:flutter_test/flutter_test.dart';
import 'package:hiflutter_suite/hiflutter_suite.dart';

void main() {
  group('HiSuiteMetrics', () {
    test('exposes cross-platform SuiteCore constants', () {
      expect(HiSuiteMetrics.listRowMinHeight, 52.0);
      expect(HiSuiteMetrics.searchFieldHeight, 48.0);
      expect(HiSuiteMetrics.primaryButtonMinHeight, 48.0);
      expect(HiSuiteMetrics.minTouchTarget, 48.0);
      expect(HiSuiteMetrics.horizontalSafeMargin, 16.0);
      expect(HiSuiteMetrics.menuBorderRadius, 16.0);
      expect(HiSuiteMetrics.tooltipBorderRadius, 14.0);
      expect(HiSuiteMetrics.loadMoreFooterMinHeight, 52.0);
      expect(HiSuiteMetrics.loadMoreFooterVerticalPadding, 12.0);
      expect(HiSuiteMetrics.pageLoadingIndicatorSize, 48.0);
      expect(HiSuiteMetrics.inlineLoadingIndicatorSize, 18.0);
      expect(HiSuiteMetrics.stateViewPadding, 24.0);
      expect(HiSuiteMetrics.stateViewIconSpacing, 16.0);
      expect(HiSuiteMetrics.stateViewTextSpacing, 8.0);
      expect(HiSuiteMetrics.stateViewActionSpacing, 24.0);
      expect(HiSuiteMetrics.stateViewIconSize, 48.0);
      expect(HiSuiteMetrics.buttonBorderRadius, 12.0);
      expect(HiSuiteMetrics.spacingSmall, 8.0);
      expect(HiSuiteMetrics.spacingMedium, 12.0);
      expect(HiSuiteMetrics.spacingLarge, 16.0);
      expect(HiSuiteMetrics.spacingExtraLarge, 24.0);
    });
  });
}
