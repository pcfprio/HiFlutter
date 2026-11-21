import 'package:material_ui/material_ui.dart';

import '../metrics/suite_metrics.dart';

/// Corner shape variants supported by [HiPrimaryButton].
enum HiButtonShape {
  /// Rounded rectangle with [HiSuiteMetrics.buttonBorderRadius] (`12.0`).
  rounded,

  /// Full pill / stadium shape.
  capsule,
}

/// Primary solid action button aligned with `SuitePrimaryButtonStyle`.
///
/// Renders with [ColorScheme.primary] background and [ColorScheme.onPrimary]
/// foreground, uses a Material disabled surface when [onPressed] is `null`, and
/// displays a centered [HiSuiteMetrics.inlineLoadingIndicatorSize] spinner while
/// ignoring taps when [loading] is `true`.
class HiPrimaryButton extends StatelessWidget {
  /// Creates a primary action button displaying either [child] or [label].
  const HiPrimaryButton({
    super.key,
    this.label,
    this.child,
    required this.onPressed,
    this.loading = false,
    this.shape = HiButtonShape.rounded,
    this.expand = true,
    this.minHeight = HiSuiteMetrics.primaryButtonMinHeight,
  }) : assert(
         label != null || child != null,
         'Provide either label or child for HiPrimaryButton.',
       ),
       assert(minHeight >= 0, 'minHeight must be non-negative.');

  /// Text label rendered when [child] is `null`.
  final String? label;

  /// Custom content widget preferred over [label] when provided.
  final Widget? child;

  /// Callback invoked when the button is pressed and [loading] is `false`.
  ///
  /// Passing `null` renders the button in its disabled state.
  final VoidCallback? onPressed;

  /// Whether an inline progress indicator replaces the button content and
  /// intercepts taps.
  final bool loading;

  /// Outer border shape of the button. Defaults to [HiButtonShape.rounded].
  final HiButtonShape shape;

  /// Whether the button expands to fill available horizontal width when bounded.
  ///
  /// Defaults to `true`.
  final bool expand;

  /// Minimum height of the button.
  ///
  /// Defaults to [HiSuiteMetrics.primaryButtonMinHeight] (`48.0`).
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final buttonShape = switch (shape) {
      HiButtonShape.rounded => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HiSuiteMetrics.buttonBorderRadius),
      ),
      HiButtonShape.capsule => const StadiumBorder(),
    };

    final effectiveContent = loading
        ? CircularProgressIndicator(
            strokeWidth: 2.0,
            color: colorScheme.onPrimary,
            constraints: const BoxConstraints.tightFor(
              width: HiSuiteMetrics.inlineLoadingIndicatorSize,
              height: HiSuiteMetrics.inlineLoadingIndicatorSize,
            ),
          )
        : (child ?? Text(label!));

    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveMinWidth = expand && constraints.hasBoundedWidth
            ? double.infinity
            : 0.0;

        return FilledButton(
          onPressed: loading ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            disabledBackgroundColor: loading
                ? colorScheme.primary
                : colorScheme.onSurface.withValues(alpha: 0.12),
            disabledForegroundColor: loading
                ? colorScheme.onPrimary
                : colorScheme.onSurface.withValues(alpha: 0.38),
            minimumSize: Size(effectiveMinWidth, minHeight),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: buttonShape,
          ),
          child: effectiveContent,
        );
      },
    );
  }
}
