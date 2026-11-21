import 'package:cached_network_image/cached_network_image.dart';
import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_suite/hiflutter_suite.dart';
import 'package:material_ui/material_ui.dart';

/// Material 3 cached network image widget backed by `cached_network_image`.
///
/// Wraps `CachedNetworkImage` without exposing any third-party types in its
/// public API. When [imageUrl] is empty or whitespace-only, renders the error
/// state directly without starting a network request.
class HiCachedImage extends StatelessWidget {
  /// Creates a cached network image widget.
  const HiCachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.borderRadius,
    this.headers,
    this.placeholder,
    this.errorWidget,
    this.onTap,
    this.imageProviderOverride,
  });

  /// URL of the image to load and cache.
  final String imageUrl;

  /// Optional target width.
  final double? width;

  /// Optional target height.
  final double? height;

  /// How the image should be inscribed into the space allocated during layout.
  final BoxFit? fit;

  /// Optional corner rounding applied around the image and fallback states.
  final BorderRadiusGeometry? borderRadius;

  /// Optional HTTP headers forwarded when fetching [imageUrl].
  final Map<String, String>? headers;

  /// Optional builder replacing the default centered compact indicator.
  final WidgetBuilder? placeholder;

  /// Optional builder replacing the default error state.
  ///
  /// Errors are normalized to [HiError] so no third-party exception types leak.
  final Widget Function(BuildContext context, HiError error)? errorWidget;

  /// Optional callback invoked when the widget is tapped.
  final VoidCallback? onTap;

  /// Optional [ImageProvider] override for offline tests or custom caching.
  final ImageProvider? imageProviderOverride;

  @override
  Widget build(BuildContext context) {
    final trimmedUrl = imageUrl.trim();
    Widget content;

    if (trimmedUrl.isEmpty) {
      content = _buildError(context, const HiDecodeError());
    } else if (imageProviderOverride != null) {
      content = Image(
        image: imageProviderOverride!,
        width: width,
        height: height,
        fit: fit,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) {
            return child;
          }
          return _buildPlaceholder(context);
        },
        errorBuilder: (context, error, stackTrace) =>
            _buildError(context, _mapImageError(error, stackTrace)),
      );
    } else {
      content = CachedNetworkImage(
        imageUrl: trimmedUrl,
        httpHeaders: headers,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, _) => _buildPlaceholder(context),
        errorWidget: (context, _, error) =>
            _buildError(context, _mapImageError(error)),
      );
    }

    if (width != null || height != null) {
      content = SizedBox(width: width, height: height, child: content);
    }
    if (borderRadius != null) {
      content = ClipRRect(borderRadius: borderRadius!, child: content);
    }
    if (onTap != null) {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: content,
      );
    }
    return content;
  }

  Widget _buildPlaceholder(BuildContext context) {
    final custom = placeholder;
    if (custom != null) {
      return custom(context);
    }
    return const _DefaultImagePlaceholder();
  }

  Widget _buildError(BuildContext context, HiError error) {
    final custom = errorWidget;
    if (custom != null) {
      return custom(context, error);
    }
    return _DefaultImageError(error: error);
  }

  static HiError _mapImageError(Object error, [StackTrace? stackTrace]) {
    if (error is HiError) return error;
    if (error is NetworkImageLoadException) {
      final status = error.statusCode;
      if (status == 401) {
        return HiUnauthorizedError(cause: error, stackTrace: stackTrace);
      }
      if (status == 403) {
        return HiForbiddenError(cause: error, stackTrace: stackTrace);
      }
      if (status == 404) {
        return HiNotFoundError(cause: error, stackTrace: stackTrace);
      }
      if (status >= 500 && status < 600) {
        return HiServerError(
          statusCode: status,
          cause: error,
          stackTrace: stackTrace,
        );
      }
      return HiNetworkError(cause: error, stackTrace: stackTrace);
    }
    return HiError.from(error, stackTrace);
  }
}

class _DefaultImagePlaceholder extends StatelessWidget {
  const _DefaultImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    final l10n = HiSuiteLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.0,
          semanticsLabel: l10n.loadingLabel,
          constraints: const BoxConstraints.tightFor(
            width: HiSuiteMetrics.inlineLoadingIndicatorSize,
            height: HiSuiteMetrics.inlineLoadingIndicatorSize,
          ),
        ),
      ),
    );
  }
}

class _DefaultImageError extends StatelessWidget {
  const _DefaultImageError({required this.error});

  final HiError error;

  @override
  Widget build(BuildContext context) {
    final l10n = HiSuiteLocalizations.of(context);
    final described = l10n.describeError(error);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return ColoredBox(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showText =
              constraints.maxHeight >= 72 && constraints.maxWidth >= 96;
          if (!showText) {
            return Semantics(
              label: described.title,
              child: Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(HiSuiteMetrics.spacingSmall),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.broken_image_outlined,
                    size: 24,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    described.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
