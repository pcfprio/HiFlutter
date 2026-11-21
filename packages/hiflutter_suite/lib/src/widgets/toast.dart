import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../metrics/suite_metrics.dart';

/// Handle to a toast overlay shown via [HiToast.show].
///
/// Callers can check [isShown] or dismiss the toast early via [dismiss].
final class HiToastHandle {
  HiToastHandle._(this._overlay, this._onDismissed);

  final OverlayState _overlay;
  final VoidCallback _onDismissed;
  late final OverlayEntry _entry;

  Timer? _timer;
  bool _isShown = true;
  bool _removed = false;
  bool _disposed = false;

  /// Whether this toast is currently displayed in the overlay.
  bool get isShown => _isShown;

  void _attachEntry(OverlayEntry entry) {
    _entry = entry;
  }

  void _startTimer(Duration duration) {
    _timer?.cancel();
    if (duration > Duration.zero) {
      _timer = Timer(duration, dismiss);
    }
  }

  /// Dismisses this toast immediately if it is still shown.
  ///
  /// Calling [dismiss] more than once or after the toast has already closed is
  /// a safe no-op.
  void dismiss() {
    if (!_isShown) return;
    _isShown = false;
    _timer?.cancel();
    _timer = null;
    if (!_removed) {
      _removed = true;
      _entry.remove();
    }
    if (!_disposed) {
      _disposed = true;
      _entry.dispose();
    }
    _onDismissed();
  }

  void _onWidgetDisposed() {
    _timer?.cancel();
    _timer = null;
    _isShown = false;
    if (!_removed) {
      if (!_overlay.mounted) {
        // The parent OverlayState is tearing down and disposes its own subtree.
        _removed = true;
        _disposed = true;
      } else {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (!_removed && _overlay.mounted) {
            _removed = true;
            _entry.remove();
          }
          if (!_disposed && _removed) {
            _disposed = true;
            _entry.dispose();
          }
        });
      }
    }
    _onDismissed();
  }
}

/// Lightweight bottom overlay toast aligned with `SuiteSnackbarHost` metrics.
///
/// Only one toast is shown at a time; calling [show] dismisses any previous
/// toast before inserting the new one.
abstract final class HiToast {
  static HiToastHandle? _current;

  /// Shows a non-blocking toast [message] in the nearest [Overlay] above
  /// [context].
  ///
  /// Single-line messages shrink-wrap their content and center horizontally at
  /// the bottom of the screen. Multi-line messages expand to fill the available
  /// width inside [HiSuiteMetrics.horizontalSafeMargin] on both sides, left-align
  /// their text, and cap at five lines with ellipsis truncation.
  ///
  /// If [duration] is positive, the toast dismisses automatically after
  /// [duration]. Returns a [HiToastHandle] that can dismiss the toast early.
  static HiToastHandle show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    dismissCurrent();

    final overlay = Overlay.of(context);
    late final HiToastHandle handle;
    handle = HiToastHandle._(overlay, () {
      if (identical(_current, handle)) {
        _current = null;
      }
    });

    final entry = OverlayEntry(
      builder: (entryContext) =>
          _HiToastOverlay(message: message, duration: duration, handle: handle),
    );
    handle._attachEntry(entry);
    _current = handle;
    overlay.insert(entry);
    return handle;
  }

  /// Dismisses the currently displayed toast, if any.
  static void dismissCurrent() {
    final active = _current;
    _current = null;
    active?.dismiss();
  }
}

class _HiToastOverlay extends StatefulWidget {
  const _HiToastOverlay({
    required this.message,
    required this.duration,
    required this.handle,
  });

  final String message;
  final Duration duration;
  final HiToastHandle handle;

  @override
  State<_HiToastOverlay> createState() => _HiToastOverlayState();
}

class _HiToastOverlayState extends State<_HiToastOverlay> {
  @override
  void initState() {
    super.initState();
    widget.handle._startTimer(widget.duration);
  }

  @override
  void dispose() {
    widget.handle._onWidgetDisposed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bubblePadding = EdgeInsets.symmetric(
      horizontal: HiSuiteMetrics.horizontalSafeMargin,
      vertical: HiSuiteMetrics.spacingMedium,
    );

    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              HiSuiteMetrics.horizontalSafeMargin,
              HiSuiteMetrics.horizontalSafeMargin,
              HiSuiteMetrics.horizontalSafeMargin,
              HiSuiteMetrics.spacingExtraLarge,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final theme = Theme.of(context);
                final colorScheme = theme.colorScheme;
                final textStyle =
                    (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
                      color: colorScheme.onInverseSurface,
                    );
                final maxTextWidth = math.max(
                  0.0,
                  constraints.maxWidth - bubblePadding.horizontal,
                );
                final painter = TextPainter(
                  text: TextSpan(text: widget.message, style: textStyle),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                  maxLines: 1,
                )..layout(maxWidth: maxTextWidth);
                final isMultiLine =
                    widget.message.contains('\n') || painter.didExceedMaxLines;
                painter.dispose();

                final bubble = Material(
                  color: colorScheme.inverseSurface,
                  elevation: 4.0,
                  borderRadius: BorderRadius.circular(
                    HiSuiteMetrics.buttonBorderRadius,
                  ),
                  child: Padding(
                    padding: bubblePadding,
                    child: Text(
                      widget.message,
                      style: textStyle,
                      textAlign: isMultiLine
                          ? TextAlign.start
                          : TextAlign.center,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );

                return Semantics(
                  liveRegion: true,
                  container: true,
                  child: isMultiLine
                      ? SizedBox(width: double.infinity, child: bubble)
                      : bubble,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
