import 'package:material_ui/material_ui.dart';

import '../l10n/suite_localizations.dart';
import '../metrics/suite_metrics.dart';

/// Persistent capsule search field with a fixed height of
/// [HiSuiteMetrics.searchFieldHeight] (`48.0`).
///
/// Always displays a leading search icon and shows a localized clear button
/// whenever the query text is non-empty. Manages an internal
/// [TextEditingController] automatically when [controller] is omitted.
class HiSearchField extends StatefulWidget {
  /// Creates a persistent capsule search field.
  const HiSearchField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.clearLabel,
    this.enabled = true,
    this.autofocus = false,
    this.textInputAction = TextInputAction.search,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
  });

  /// Optional controller driving the search input text.
  ///
  /// When `null`, [HiSearchField] creates and disposes its own controller.
  final TextEditingController? controller;

  /// Optional focus node attached to the underlying [TextField].
  final FocusNode? focusNode;

  /// Placeholder hint displayed when the field is empty.
  ///
  /// Defaults to [HiSuiteLocalizations.searchHint] when `null`.
  final String? hintText;

  /// Semantic accessibility label for the trailing clear button.
  ///
  /// Defaults to [HiSuiteLocalizations.clearLabel] when `null`.
  final String? clearLabel;

  /// Whether the field accepts input and clear interactions.
  final bool enabled;

  /// Whether the field requests focus automatically when first mounted.
  final bool autofocus;

  /// Keyboard action button configured on the underlying [TextField].
  ///
  /// Defaults to [TextInputAction.search].
  final TextInputAction textInputAction;

  /// Called whenever the query text changes via typing or clearing.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits the search action on the keyboard.
  final ValueChanged<String>? onSubmitted;

  /// Called after the trailing clear button empties the input.
  final VoidCallback? onClear;

  @override
  State<HiSearchField> createState() => _HiSearchFieldState();
}

class _HiSearchFieldState extends State<HiSearchField> {
  TextEditingController? _ownedController;
  FocusNode? _ownedFocusNode;

  TextEditingController get _effectiveController =>
      widget.controller ?? (_ownedController ??= TextEditingController());

  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_ownedFocusNode ??= FocusNode());

  @override
  void didUpdateWidget(HiSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != null && _ownedController != null) {
      _ownedController!.dispose();
      _ownedController = null;
    }
    if (widget.focusNode != null && _ownedFocusNode != null) {
      _ownedFocusNode!.dispose();
      _ownedFocusNode = null;
    }
  }

  @override
  void dispose() {
    _ownedController?.dispose();
    _ownedFocusNode?.dispose();
    super.dispose();
  }

  void _handleClear() {
    if (!widget.enabled) return;
    _effectiveController.clear();
    widget.onChanged?.call('');
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = HiSuiteLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final effectiveHint = widget.hintText ?? l10n.searchHint;
    final effectiveClearLabel = widget.clearLabel ?? l10n.clearLabel;

    final controller = _effectiveController;
    final focusNode = _effectiveFocusNode;

    final foregroundColor = widget.enabled
        ? colorScheme.onSurface
        : colorScheme.onSurface.withValues(alpha: 0.38);
    final mutedColor = widget.enabled
        ? colorScheme.onSurfaceVariant
        : colorScheme.onSurface.withValues(alpha: 0.38);

    return SizedBox(
      height: HiSuiteMetrics.searchFieldHeight,
      child: Material(
        color: colorScheme.surfaceContainerHigh,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? focusNode.requestFocus : null,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: HiSuiteMetrics.horizontalSafeMargin,
                  end: HiSuiteMetrics.spacingSmall,
                ),
                child: Icon(Icons.search, size: 20.0, color: mutedColor),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: widget.enabled,
                  autofocus: widget.autofocus,
                  textInputAction: widget.textInputAction,
                  textAlignVertical: TextAlignVertical.center,
                  maxLines: 1,
                  style: (textTheme.bodyLarge ?? const TextStyle()).copyWith(
                    color: foregroundColor,
                  ),
                  decoration: InputDecoration(
                    hintText: effectiveHint,
                    hintStyle: (textTheme.bodyLarge ?? const TextStyle())
                        .copyWith(color: mutedColor),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  if (value.text.isEmpty) {
                    return const SizedBox(
                      width: HiSuiteMetrics.horizontalSafeMargin,
                    );
                  }
                  return IconButton(
                    onPressed: widget.enabled ? _handleClear : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: HiSuiteMetrics.minTouchTarget,
                      height: HiSuiteMetrics.searchFieldHeight,
                    ),
                    icon: Icon(
                      Icons.close,
                      size: 20.0,
                      color: mutedColor,
                      semanticLabel: effectiveClearLabel,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
