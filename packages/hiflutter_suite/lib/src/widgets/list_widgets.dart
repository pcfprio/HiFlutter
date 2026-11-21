import 'package:material_ui/material_ui.dart';

import '../metrics/suite_metrics.dart';

/// Rounded card container grouping related [HiListRow] or
/// [HiSelectableListRow] entries with optional [header], [footer], dividers,
/// and [margin].
class HiListSection extends StatelessWidget {
  /// Creates a grouped list section card.
  const HiListSection({
    super.key,
    this.header,
    this.footer,
    required this.children,
    this.showDividers = true,
    this.dividerIndent,
    this.margin,
    this.borderRadius,
    this.backgroundColor,
  });

  /// Optional header widget displayed above the rounded card.
  final Widget? header;

  /// Optional footer widget displayed below the rounded card.
  final Widget? footer;

  /// Child rows rendered vertically inside the rounded card.
  final List<Widget> children;

  /// Whether horizontal dividers are inserted between adjacent [children].
  ///
  /// Defaults to `true`.
  final bool showDividers;

  /// Leading indent of each divider in logical pixels.
  ///
  /// Defaults to [HiSuiteMetrics.horizontalSafeMargin].
  final double? dividerIndent;

  /// Optional outer margin around the entire section (including [header] and
  /// [footer]).
  final EdgeInsetsGeometry? margin;

  /// Corner radius of the card container.
  ///
  /// Defaults to [HiSuiteMetrics.menuBorderRadius] on all corners.
  final BorderRadiusGeometry? borderRadius;

  /// Background color of the card container.
  ///
  /// Defaults to [ColorScheme.surfaceContainerLow].
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty && header == null && footer == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final headerStyle = (textTheme.labelLarge ?? const TextStyle()).copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    final footerStyle = (textTheme.bodySmall ?? const TextStyle()).copyWith(
      color: colorScheme.onSurfaceVariant,
    );

    final effectiveRadius =
        borderRadius ?? BorderRadius.circular(HiSuiteMetrics.menuBorderRadius);
    final effectiveBackground =
        backgroundColor ?? colorScheme.surfaceContainerLow;
    final effectiveIndent =
        dividerIndent ?? HiSuiteMetrics.horizontalSafeMargin;

    final cardChildren = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0 && showDividers) {
        cardChildren.add(
          Divider(
            height: 1.0,
            thickness: 1.0,
            indent: effectiveIndent,
            color: colorScheme.outlineVariant,
          ),
        );
      }
      cardChildren.add(children[i]);
    }

    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.only(
              left: HiSuiteMetrics.horizontalSafeMargin,
              right: HiSuiteMetrics.horizontalSafeMargin,
              bottom: HiSuiteMetrics.spacingSmall,
            ),
            child: DefaultTextStyle.merge(style: headerStyle, child: header!),
          ),
        if (children.isNotEmpty)
          Material(
            color: effectiveBackground,
            shape: RoundedRectangleBorder(borderRadius: effectiveRadius),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: cardChildren,
            ),
          ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.only(
              left: HiSuiteMetrics.horizontalSafeMargin,
              right: HiSuiteMetrics.horizontalSafeMargin,
              top: HiSuiteMetrics.spacingSmall,
            ),
            child: DefaultTextStyle.merge(style: footerStyle, child: footer!),
          ),
      ],
    );

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }
    return content;
  }
}

/// Standard interactive list row with a minimum height of
/// [HiSuiteMetrics.listRowMinHeight] (`52.0`).
class HiListRow extends StatelessWidget {
  /// Creates a list row displaying [title] and optional slots.
  const HiListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.padding,
  });

  /// Primary row content.
  final Widget title;

  /// Optional secondary content displayed below [title].
  final Widget? subtitle;

  /// Optional widget displayed before [title].
  final Widget? leading;

  /// Optional widget displayed after [title].
  final Widget? trailing;

  /// Callback invoked when the row is tapped while [enabled] is `true`.
  final VoidCallback? onTap;

  /// Whether the row responds to taps.
  ///
  /// When `false`, the row is dimmed visually and ignores tap interactions.
  final bool enabled;

  /// Inner padding around the row content.
  ///
  /// Defaults to `EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0)`.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      enabled: enabled,
      button: onTap != null,
      child: _HiListRowBody(
        title: title,
        subtitle: subtitle,
        leading: leading,
        trailing: trailing,
        onTap: onTap,
        enabled: enabled,
        padding: padding,
      ),
    );
  }
}

/// Selectable list row matching [HiListRow] appearance and minimum height
/// (`52.0`), showing a themed primary checkmark when [selected] is `true`.
class HiSelectableListRow extends StatelessWidget {
  /// Creates a selectable list row.
  const HiSelectableListRow({
    super.key,
    required this.title,
    required this.selected,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.padding,
  });

  /// Primary row content.
  final Widget title;

  /// Whether this row is currently selected.
  final bool selected;

  /// Optional secondary content displayed below [title].
  final Widget? subtitle;

  /// Optional widget displayed before [title].
  final Widget? leading;

  /// Optional custom trailing widget overriding the default selection
  /// checkmark.
  final Widget? trailing;

  /// Callback invoked when the row is tapped while [enabled] is `true`.
  final VoidCallback? onTap;

  /// Whether the row responds to taps.
  final bool enabled;

  /// Inner padding around the row content.
  ///
  /// Defaults to `EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0)`.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final effectiveTrailing =
        trailing ??
        (selected
            ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
            : null);

    return Semantics(
      container: true,
      selected: selected,
      enabled: enabled,
      button: onTap != null,
      child: _HiListRowBody(
        title: title,
        subtitle: subtitle,
        leading: leading,
        trailing: effectiveTrailing,
        onTap: onTap,
        enabled: enabled,
        padding: padding,
      ),
    );
  }
}

class _HiListRowBody extends StatelessWidget {
  const _HiListRowBody({
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.trailing,
    required this.onTap,
    required this.enabled,
    required this.padding,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final titleStyle = (textTheme.bodyLarge ?? const TextStyle()).copyWith(
      color: colorScheme.onSurface,
    );
    final subtitleStyle = (textTheme.bodyMedium ?? const TextStyle()).copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    final effectivePadding =
        padding ??
        const EdgeInsets.symmetric(
          horizontal: HiSuiteMetrics.horizontalSafeMargin,
          vertical: HiSuiteMetrics.spacingSmall,
        );

    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: HiSuiteMetrics.listRowMinHeight,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Opacity(
            opacity: enabled ? 1.0 : 0.38,
            child: Padding(
              padding: effectivePadding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (leading != null) ...[
                    IconTheme.merge(
                      data: IconThemeData(color: colorScheme.onSurfaceVariant),
                      child: leading!,
                    ),
                    const SizedBox(width: HiSuiteMetrics.spacingMedium),
                  ],
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DefaultTextStyle.merge(style: titleStyle, child: title),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2.0),
                          DefaultTextStyle.merge(
                            style: subtitleStyle,
                            child: subtitle!,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: HiSuiteMetrics.spacingMedium),
                    IconTheme.merge(
                      data: IconThemeData(color: colorScheme.onSurfaceVariant),
                      child: trailing!,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
