import 'package:material_ui/material_ui.dart';

import '../l10n/suite_localizations.dart';
import '../metrics/suite_metrics.dart';

/// State of the trailing load-more footer inside a paginated list.
enum HiLoadMoreStatus {
  /// Currently loading the next page.
  loading,

  /// Additional pages are available and may be loaded.
  canLoadMore,

  /// All pages have been loaded.
  noMore,

  /// Loading the next page failed; tapping retries.
  failed,
}

/// Four-state pagination footer: loading, load more, no more items, or failed.
class HiLoadMoreFooter extends StatelessWidget {
  /// Creates a load-more footer for [status].
  const HiLoadMoreFooter({
    super.key,
    required this.status,
    this.onLoadMore,
    this.onRetry,
    this.loadingLabel,
    this.canLoadMoreLabel,
    this.noMoreLabel,
    this.failedLabel,
    this.retryLabel,
    this.padding,
  });

  /// Current footer status.
  final HiLoadMoreStatus status;

  /// Callback invoked when the user taps the footer in
  /// [HiLoadMoreStatus.canLoadMore].
  final VoidCallback? onLoadMore;

  /// Callback invoked when the user taps to retry in [HiLoadMoreStatus.failed].
  final VoidCallback? onRetry;

  /// Optional override for [HiSuiteLocalizations.loadMoreLoadingLabel].
  final String? loadingLabel;

  /// Optional override for [HiSuiteLocalizations.loadMorePromptLabel].
  final String? canLoadMoreLabel;

  /// Optional override for [HiSuiteLocalizations.loadMoreNoMoreLabel].
  ///
  /// Pass an empty string (`''`) to render nothing in [HiLoadMoreStatus.noMore].
  final String? noMoreLabel;

  /// Optional override for [HiSuiteLocalizations.loadMoreFailedLabel].
  final String? failedLabel;

  /// Optional override for [HiSuiteLocalizations.retryLabel].
  final String? retryLabel;

  /// Inner padding around the footer content.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final l10n = HiSuiteLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final mutedStyle = textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    final effectivePadding =
        padding ??
        const EdgeInsets.symmetric(
          horizontal: HiSuiteMetrics.horizontalSafeMargin,
          vertical: HiSuiteMetrics.loadMoreFooterVerticalPadding,
        );

    final Widget content = switch (status) {
      HiLoadMoreStatus.loading => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            strokeWidth: 2.0,
            constraints: BoxConstraints.tightFor(
              width: HiSuiteMetrics.inlineLoadingIndicatorSize,
              height: HiSuiteMetrics.inlineLoadingIndicatorSize,
            ),
          ),
          const SizedBox(width: 10),
          Text(loadingLabel ?? l10n.loadMoreLoadingLabel, style: mutedStyle),
        ],
      ),
      HiLoadMoreStatus.canLoadMore =>
        onLoadMore != null
            ? TextButton(
                onPressed: onLoadMore,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, HiSuiteMetrics.minTouchTarget),
                ),
                child: Text(canLoadMoreLabel ?? l10n.loadMorePromptLabel),
              )
            : Text(
                canLoadMoreLabel ?? l10n.loadMorePromptLabel,
                style: mutedStyle,
              ),
      HiLoadMoreStatus.noMore => () {
        final text = noMoreLabel ?? l10n.loadMoreNoMoreLabel;
        if (text.isEmpty) return const SizedBox.shrink();
        return Text(text, style: mutedStyle);
      }(),
      HiLoadMoreStatus.failed => _FailedFooterContent(
        failedText: failedLabel ?? l10n.loadMoreFailedLabel,
        retryText: retryLabel ?? l10n.retryLabel,
        mutedStyle: mutedStyle,
        primaryStyle: textTheme.labelLarge?.copyWith(
          color: colorScheme.primary,
        ),
        errorColor: colorScheme.error,
        onRetry: onRetry,
        padding: effectivePadding,
      ),
    };

    if (status == HiLoadMoreStatus.noMore &&
        (noMoreLabel ?? l10n.loadMoreNoMoreLabel).isEmpty) {
      return const SizedBox.shrink();
    }

    if (status == HiLoadMoreStatus.failed) {
      return ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: HiSuiteMetrics.loadMoreFooterMinHeight,
        ),
        child: content,
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: HiSuiteMetrics.loadMoreFooterMinHeight,
      ),
      child: Padding(
        padding: effectivePadding,
        child: Center(child: content),
      ),
    );
  }
}

class _FailedFooterContent extends StatelessWidget {
  const _FailedFooterContent({
    required this.failedText,
    required this.retryText,
    required this.mutedStyle,
    required this.primaryStyle,
    required this.errorColor,
    required this.onRetry,
    required this.padding,
  });

  final String failedText;
  final String retryText;
  final TextStyle? mutedStyle;
  final TextStyle? primaryStyle;
  final Color errorColor;
  final VoidCallback? onRetry;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onRetry,
        child: Padding(
          padding: padding,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: HiSuiteMetrics.inlineLoadingIndicatorSize,
                  color: errorColor,
                ),
                const SizedBox(width: HiSuiteMetrics.spacingSmall),
                Text(failedText, style: mutedStyle),
                const SizedBox(width: HiSuiteMetrics.spacingSmall),
                Text(retryText, style: primaryStyle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
