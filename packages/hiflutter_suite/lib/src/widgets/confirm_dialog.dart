import 'package:material_ui/material_ui.dart';

import '../l10n/suite_localizations.dart';
import '../metrics/suite_metrics.dart';

/// Modal confirmation dialog implemented directly with [showGeneralDialog].
///
/// Uses localized default button labels from [HiSuiteLocalizations] and
/// highlights destructive confirmations with [ColorScheme.error].
abstract final class HiConfirmDialog {
  /// Shows a modal confirmation dialog and returns `true` if confirmed or
  /// `false` if cancelled or dismissed via the barrier or system back action.
  ///
  /// [confirmLabel] and [cancelLabel] default to
  /// [HiSuiteLocalizations.confirmLabel] and [HiSuiteLocalizations.cancelLabel]
  /// resolved from [context]. When [isDestructive] is `true`, the confirm
  /// button uses [ColorScheme.error] and [ColorScheme.onError].
  static Future<bool> show(
    BuildContext context, {
    required String title,
    String? message,
    String? confirmLabel,
    String? cancelLabel,
    bool isDestructive = false,
    bool barrierDismissible = true,
  }) async {
    final l10n = HiSuiteLocalizations.of(context);
    final effectiveConfirmLabel = confirmLabel ?? l10n.confirmLabel;
    final effectiveCancelLabel = cancelLabel ?? l10n.cancelLabel;
    final barrierLabel =
        Localizations.of<MaterialLocalizations>(
          context,
          MaterialLocalizations,
        )?.modalBarrierDismissLabel ??
        effectiveCancelLabel;
    final navigator = Navigator.of(context, rootNavigator: true);
    final themes = InheritedTheme.capture(from: context, to: navigator.context);
    final scrimColor = Theme.of(context).colorScheme.scrim
        .withValues(alpha: 0.32);

    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: barrierDismissible ? barrierLabel : null,
      barrierColor: scrimColor,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return themes.wrap(
          _HiConfirmDialogSurface(
            title: title,
            message: message,
            confirmLabel: effectiveConfirmLabel,
            cancelLabel: effectiveCancelLabel,
            isDestructive: isDestructive,
            onCancel: () => Navigator.of(dialogContext).pop(false),
            onConfirm: () => Navigator.of(dialogContext).pop(true),
          ),
        );
      },
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );

    return result ?? false;
  }
}

class _HiConfirmDialogSurface extends StatelessWidget {
  const _HiConfirmDialogSurface({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.isDestructive,
    required this.onCancel,
    required this.onConfirm,
  });

  final String title;
  final String? message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final trimmedMessage = message?.trim();
    final hasMessage = trimmedMessage != null && trimmedMessage.isNotEmpty;

    final confirmStyle = isDestructive
        ? FilledButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
            minimumSize: const Size(0, HiSuiteMetrics.minTouchTarget),
          )
        : FilledButton.styleFrom(
            minimumSize: const Size(0, HiSuiteMetrics.minTouchTarget),
          );

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(HiSuiteMetrics.spacingExtraLarge),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 280, maxWidth: 400),
            child: Semantics(
              scopesRoute: true,
              explicitChildNodes: true,
              namesRoute: true,
              label: title,
              child: Material(
                color: colorScheme.surfaceContainerHigh,
                elevation: 6.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28.0),
                ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(
                    HiSuiteMetrics.spacingExtraLarge,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        style: textTheme.headlineSmall?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                      if (hasMessage) ...[
                        const SizedBox(height: HiSuiteMetrics.spacingLarge),
                        Flexible(
                          child: SingleChildScrollView(
                            child: Text(
                              trimmedMessage,
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: HiSuiteMetrics.spacingExtraLarge),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: HiSuiteMetrics.spacingSmall,
                        runSpacing: HiSuiteMetrics.spacingSmall,
                        children: [
                          TextButton(
                            onPressed: onCancel,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(
                                0,
                                HiSuiteMetrics.minTouchTarget,
                              ),
                            ),
                            child: Text(cancelLabel),
                          ),
                          FilledButton(
                            onPressed: onConfirm,
                            style: confirmStyle,
                            child: Text(confirmLabel),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
