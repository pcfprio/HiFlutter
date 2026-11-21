import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/suite_localizations.dart';
import '../metrics/suite_metrics.dart';

/// Display state rendered by [HiStateView].
enum HiViewState {
  /// Initial or blocking loading state.
  loading,

  /// Empty data state.
  empty,

  /// Failure state.
  error,

  /// Ready content state.
  content,
}

/// Centered page or section loading placeholder.
///
/// Uses an enlarged [CircularProgressIndicator] tinted by the current Material 3
/// [ColorScheme.primary] and intentionally omits visible text unless a non-empty
/// [message] is explicitly supplied. Localized accessibility semantics default
/// to [HiSuiteLocalizations.loadingLabel].
class HiLoadingView extends StatelessWidget {
  /// Creates a centered loading indicator view.
  const HiLoadingView({
    super.key,
    this.accessibilityLabel,
    this.message,
    this.color,
    this.indicatorSize = HiSuiteMetrics.pageLoadingIndicatorSize,
    this.strokeWidth = 4.0,
  });

  /// Semantic label read by screen readers.
  ///
  /// Defaults to [HiSuiteLocalizations.loadingLabel] when `null`.
  final String? accessibilityLabel;

  /// Optional visible status text shown beneath the spinner.
  ///
  /// Omitted by default to keep page loading clean, matching `SuiteCore`.
  final String? message;

  /// Optional spinner color. Defaults to the current Material 3 theme color.
  final Color? color;

  /// Diameter of the circular indicator. Defaults to
  /// [HiSuiteMetrics.pageLoadingIndicatorSize].
  final double indicatorSize;

  /// Stroke width of the circular indicator. Defaults to `4.0`.
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final l10n = HiSuiteLocalizations.of(context);
    final effectiveLabel = accessibilityLabel ?? l10n.loadingLabel;
    final detail = message?.trim();
    final hasMessage = detail != null && detail.isNotEmpty;

    final spinner = CircularProgressIndicator(
      color: color,
      strokeWidth: strokeWidth,
      constraints: BoxConstraints.tightFor(
        width: indicatorSize,
        height: indicatorSize,
      ),
      semanticsLabel: effectiveLabel,
    );

    if (!hasMessage) {
      return Center(child: spinner);
    }

    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HiSuiteMetrics.stateViewPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            spinner,
            const SizedBox(height: HiSuiteMetrics.stateViewIconSpacing),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Centered empty state view with optional description, icon slot, and action.
class HiEmptyView extends StatelessWidget {
  /// Creates an empty state view.
  const HiEmptyView({
    super.key,
    this.title,
    this.message,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.action,
    this.padding,
  });

  /// Heading text. Defaults to [HiSuiteLocalizations.emptyTitle] when `null`.
  final String? title;

  /// Optional supporting explanation rendered below [title].
  final String? message;

  /// Optional leading icon or illustration. Defaults to an outlined inbox icon.
  final Widget? icon;

  /// Label for the optional action button when [onAction] is provided and
  /// [action] is `null`.
  final String? actionLabel;

  /// Callback invoked when the action button is pressed.
  final VoidCallback? onAction;

  /// Custom action widget overriding the default [actionLabel] button.
  final Widget? action;

  /// Outer padding around the centered column. Defaults to
  /// [HiSuiteMetrics.stateViewPadding] on all sides.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final l10n = HiSuiteLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveTitle = title ?? l10n.emptyTitle;
    final resolvedAction = _buildAction(
      action: action,
      label: actionLabel,
      onPressed: onAction,
    );

    return _CenteredStateBody(
      title: effectiveTitle,
      message: message,
      padding: padding,
      icon:
          icon ??
          Icon(
            Icons.inbox_outlined,
            size: HiSuiteMetrics.stateViewIconSize,
            color: colorScheme.onSurfaceVariant,
          ),
      action: resolvedAction,
    );
  }
}

/// Centered error state view bound to a [HiError].
///
/// Maps [HiError.display] through [HiSuiteLocalizations.describeError] and
/// allows explicit [title], [message], and [retryLabel] overrides. Returns
/// `SizedBox.shrink()` when `error.display == HiErrorDisplay.none`. Displays a
/// retry button only when `error.retryable && onRetry != null`.
class HiErrorView extends StatelessWidget {
  /// Creates an error state view for [error].
  const HiErrorView({
    super.key,
    required this.error,
    this.onRetry,
    this.title,
    this.message,
    this.retryLabel,
    this.icon,
    this.padding,
  });

  /// Failure to present.
  final HiError error;

  /// Optional retry callback, enabled only when [HiError.retryable] is `true`.
  final VoidCallback? onRetry;

  /// Optional title overriding [HiErrorMessage.title].
  final String? title;

  /// Optional description overriding [HiErrorMessage.message].
  final String? message;

  /// Optional retry button label overriding [HiSuiteLocalizations.retryLabel].
  final String? retryLabel;

  /// Optional icon or illustration overriding the default mapped icon.
  final Widget? icon;

  /// Outer padding around the centered column. Defaults to
  /// [HiSuiteMetrics.stateViewPadding] on all sides.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    if (error.display == HiErrorDisplay.none) {
      return const SizedBox.shrink();
    }

    final l10n = HiSuiteLocalizations.of(context);
    final described = l10n.describeError(error);
    final colorScheme = Theme.of(context).colorScheme;

    final effectiveTitle = title ?? described.title;
    final effectiveMessage = message ?? described.message;
    final effectiveRetryLabel = retryLabel ?? l10n.retryLabel;

    final resolvedAction = error.retryable && onRetry != null
        ? FilledButton.tonal(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, HiSuiteMetrics.primaryButtonMinHeight),
            ),
            child: Text(effectiveRetryLabel),
          )
        : null;

    return _CenteredStateBody(
      title: effectiveTitle,
      message: effectiveMessage,
      messageMaxLines: 3,
      padding: padding,
      icon:
          icon ??
          Icon(
            _iconForIllustration(described.illustration),
            size: HiSuiteMetrics.stateViewIconSize,
            color: colorScheme.error,
          ),
      action: resolvedAction,
    );
  }

  static IconData _iconForIllustration(HiErrorIllustration? illustration) =>
      switch (illustration) {
        HiErrorIllustration.network => Icons.wifi_off_rounded,
        HiErrorIllustration.timeout => Icons.timer_off_outlined,
        HiErrorIllustration.unauthorized => Icons.lock_outline,
        HiErrorIllustration.forbidden => Icons.block_outlined,
        HiErrorIllustration.notFound => Icons.search_off_outlined,
        HiErrorIllustration.server => Icons.cloud_off_outlined,
        HiErrorIllustration.data => Icons.broken_image_outlined,
        HiErrorIllustration.generic || null => Icons.error_outline,
      };
}

/// Switches uniformly between loading, empty, error, and content views.
class HiStateView extends StatelessWidget {
  /// Creates a state view driven by an explicit [state].
  const HiStateView({
    super.key,
    required HiViewState state,
    this.child,
    this.builder,
    this.error,
    this.onRetry,
    this.loadingAccessibilityLabel,
    this.loadingMessage,
    this.emptyTitle,
    this.emptyMessage,
    this.emptyIcon,
    this.emptyActionLabel,
    this.onEmptyAction,
    this.errorTitle,
    this.errorMessage,
    this.retryLabel,
    this.errorIcon,
    this.loadingBuilder,
    this.emptyBuilder,
    this.errorBuilder,
  }) : _explicitState = state,
       _autoEmpty = false,
       _autoLoading = false,
       assert(
         child != null || builder != null || state != HiViewState.content,
         'Provide either child or builder when state is HiViewState.content.',
       );

  /// Creates a state view whose [HiViewState] is derived from [isEmpty],
  /// [isLoading], and [error] using [resolveState].
  const HiStateView.auto({
    super.key,
    required bool isEmpty,
    bool isLoading = false,
    this.error,
    this.child,
    this.builder,
    this.onRetry,
    this.loadingAccessibilityLabel,
    this.loadingMessage,
    this.emptyTitle,
    this.emptyMessage,
    this.emptyIcon,
    this.emptyActionLabel,
    this.onEmptyAction,
    this.errorTitle,
    this.errorMessage,
    this.retryLabel,
    this.errorIcon,
    this.loadingBuilder,
    this.emptyBuilder,
    this.errorBuilder,
  }) : _explicitState = null,
       _autoEmpty = isEmpty,
       _autoLoading = isLoading,
       assert(
         child != null || builder != null || isEmpty,
         'Provide either child or builder when content may be displayed.',
       );

  final HiViewState? _explicitState;
  final bool _autoEmpty;
  final bool _autoLoading;

  /// Content widget shown when resolved state is [HiViewState.content].
  final Widget? child;

  /// Lazy content builder preferred over [child] when provided.
  final WidgetBuilder? builder;

  /// Failure presented when resolved state is [HiViewState.error].
  final HiError? error;

  /// Retry callback passed to [HiErrorView].
  final VoidCallback? onRetry;

  /// Semantic label passed to [HiLoadingView].
  final String? loadingAccessibilityLabel;

  /// Optional status text passed to [HiLoadingView].
  final String? loadingMessage;

  /// Optional title override passed to [HiEmptyView].
  final String? emptyTitle;

  /// Optional message passed to [HiEmptyView].
  final String? emptyMessage;

  /// Optional icon slot passed to [HiEmptyView].
  final Widget? emptyIcon;

  /// Optional action label passed to [HiEmptyView].
  final String? emptyActionLabel;

  /// Optional action callback passed to [HiEmptyView].
  final VoidCallback? onEmptyAction;

  /// Optional title override passed to [HiErrorView].
  final String? errorTitle;

  /// Optional message override passed to [HiErrorView].
  final String? errorMessage;

  /// Optional retry label override passed to [HiErrorView].
  final String? retryLabel;

  /// Optional icon override passed to [HiErrorView].
  final Widget? errorIcon;

  /// Custom builder replacing the default [HiLoadingView].
  final WidgetBuilder? loadingBuilder;

  /// Custom builder replacing the default [HiEmptyView].
  final WidgetBuilder? emptyBuilder;

  /// Custom builder replacing the default [HiErrorView].
  final Widget Function(BuildContext context, HiError error)? errorBuilder;

  /// Derives a [HiViewState] from typical async screen flags.
  ///
  /// When [isEmpty] is `false`, returns [HiViewState.content] so existing items
  /// stay visible during background refreshes. When [isEmpty] is `true`,
  /// checks [isLoading] first, then a displayable [error] (`display != none`),
  /// and finally falls back to [HiViewState.empty].
  static HiViewState resolveState({
    required bool isEmpty,
    bool isLoading = false,
    HiError? error,
  }) {
    if (!isEmpty) return HiViewState.content;
    if (isLoading) return HiViewState.loading;
    if (error != null && error.display != HiErrorDisplay.none) {
      return HiViewState.error;
    }
    return HiViewState.empty;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveState =
        _explicitState ??
        resolveState(
          isEmpty: _autoEmpty,
          isLoading: _autoLoading,
          error: error,
        );

    return switch (effectiveState) {
      HiViewState.loading =>
        loadingBuilder?.call(context) ??
            HiLoadingView(
              accessibilityLabel: loadingAccessibilityLabel,
              message: loadingMessage,
            ),
      HiViewState.empty =>
        emptyBuilder?.call(context) ??
            HiEmptyView(
              title: emptyTitle,
              message: emptyMessage,
              icon: emptyIcon,
              actionLabel: emptyActionLabel,
              onAction: onEmptyAction,
            ),
      HiViewState.error => _buildError(context),
      HiViewState.content =>
        builder?.call(context) ?? child ?? const SizedBox.shrink(),
    };
  }

  Widget _buildError(BuildContext context) {
    final resolvedError = error ?? HiUnknownError(retryable: onRetry != null);
    final customBuilder = errorBuilder;
    if (customBuilder != null) {
      return customBuilder(context, resolvedError);
    }
    return HiErrorView(
      error: resolvedError,
      onRetry: onRetry,
      title: errorTitle,
      message: errorMessage,
      retryLabel: retryLabel,
      icon: errorIcon,
    );
  }
}

Widget? _buildAction({
  required Widget? action,
  required String? label,
  required VoidCallback? onPressed,
}) {
  if (action != null) return action;
  final trimmed = label?.trim();
  if (trimmed != null && trimmed.isNotEmpty && onPressed != null) {
    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, HiSuiteMetrics.primaryButtonMinHeight),
      ),
      child: Text(trimmed),
    );
  }
  return null;
}

class _CenteredStateBody extends StatelessWidget {
  const _CenteredStateBody({
    required this.title,
    required this.icon,
    this.message,
    this.messageMaxLines,
    this.action,
    this.padding,
  });

  final String title;
  final String? message;
  final int? messageMaxLines;
  final Widget icon;
  final Widget? action;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final detail = message?.trim();
    final hasDetail = detail != null && detail.isNotEmpty;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding:
              padding ?? const EdgeInsets.all(HiSuiteMetrics.stateViewPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(height: HiSuiteMetrics.stateViewIconSpacing),
              Text(
                title,
                textAlign: TextAlign.center,
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              if (hasDetail) ...[
                const SizedBox(height: HiSuiteMetrics.stateViewTextSpacing),
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  maxLines: messageMaxLines,
                  overflow: messageMaxLines != null
                      ? TextOverflow.ellipsis
                      : null,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: HiSuiteMetrics.stateViewActionSpacing),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
