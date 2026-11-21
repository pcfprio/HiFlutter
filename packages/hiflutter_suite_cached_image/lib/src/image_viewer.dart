import 'package:flutter/gestures.dart';
import 'package:hiflutter_suite/hiflutter_suite.dart';
import 'package:material_ui/material_ui.dart';

import 'cached_image.dart';

/// Fullscreen swipeable and pinch-zoomable image viewer.
///
/// Supports single or multiple images in a [PageView], pinch-to-zoom via
/// [InteractiveViewer], page indicator text (such as `1 / 3`), and a close
/// button. Use [HiImageViewer.show] to present it as a fullscreen route.
class HiImageViewer extends StatefulWidget {
  /// Creates a fullscreen image viewer for [urls].
  const HiImageViewer({
    super.key,
    required this.urls,
    this.initialIndex = 0,
    this.headers,
    this.imageProviderBuilder,
    this.onClose,
  });

  /// Image URLs displayed in the viewer.
  final List<String> urls;

  /// Zero-based initial page index. Clamped to valid bounds when [urls] is
  /// non-empty.
  final int initialIndex;

  /// Optional HTTP headers forwarded to [HiCachedImage].
  final Map<String, String>? headers;

  /// Optional [ImageProvider] factory override for offline tests or custom
  /// image sources.
  final ImageProvider Function(String url)? imageProviderBuilder;

  /// Optional close callback; defaults to `Navigator.of(context).maybePop()`.
  final VoidCallback? onClose;

  /// Presents [HiImageViewer] as a fullscreen dialog route.
  static Future<void> show(
    BuildContext context, {
    required List<String> urls,
    int initialIndex = 0,
    Map<String, String>? headers,
    ImageProvider Function(String url)? imageProviderBuilder,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => HiImageViewer(
          urls: urls,
          initialIndex: initialIndex,
          headers: headers,
          imageProviderBuilder: imageProviderBuilder,
        ),
      ),
    );
  }

  @override
  State<HiImageViewer> createState() => _HiImageViewerState();
}

class _HiImageViewerState extends State<HiImageViewer> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = _clampIndex(widget.initialIndex, widget.urls.length);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void didUpdateWidget(HiImageViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.urls.length != oldWidget.urls.length) {
      _currentIndex = _clampIndex(_currentIndex, widget.urls.length);
      _isZoomed = false;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  static int _clampIndex(int index, int length) =>
      length == 0 ? 0 : index.clamp(0, length - 1);

  void _handleClose() {
    final customClose = widget.onClose;
    if (customClose != null) {
      customClose();
      return;
    }
    Navigator.of(context).maybePop();
  }

  void _handleZoomChanged(bool zoomed) {
    if (_isZoomed == zoomed) return;
    setState(() {
      _isZoomed = zoomed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;

    return Theme(
      data: ThemeData.dark(useMaterial3: true),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            if (urls.isEmpty)
              const Positioned.fill(child: HiEmptyView())
            else
              Positioned.fill(
                child: PageView.builder(
                  controller: _pageController,
                  physics: _isZoomed
                      ? const NeverScrollableScrollPhysics()
                      : null,
                  itemCount: urls.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                      _isZoomed = false;
                    });
                  },
                  itemBuilder: (context, index) {
                    final url = urls[index];
                    return _ZoomableImagePage(
                      url: url,
                      pageController: _pageController,
                      headers: widget.headers,
                      imageProviderOverride: widget.imageProviderBuilder?.call(
                        url,
                      ),
                      onZoomChanged: _handleZoomChanged,
                    );
                  },
                ),
              ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: HiSuiteMetrics.spacingSmall,
                    vertical: HiSuiteMetrics.spacingSmall,
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: HiSuiteMetrics.minTouchTarget),
                      Expanded(
                        child: Center(
                          child: urls.isEmpty
                              ? const SizedBox.shrink()
                              : DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: HiSuiteMetrics.spacingMedium,
                                      vertical: 6,
                                    ),
                                    child: Text(
                                      '${_currentIndex + 1} / ${urls.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        tooltip: MaterialLocalizations.of(context)
                            .closeButtonTooltip,
                        onPressed: _handleClose,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomableImagePage extends StatefulWidget {
  const _ZoomableImagePage({
    required this.url,
    required this.pageController,
    required this.onZoomChanged,
    this.headers,
    this.imageProviderOverride,
  });

  final String url;
  final PageController pageController;
  final Map<String, String>? headers;
  final ImageProvider? imageProviderOverride;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomableImagePage> createState() => _ZoomableImagePageState();
}

class _ZoomableImagePageState extends State<_ZoomableImagePage> {
  final TransformationController _transformationController =
      TransformationController();
  final Set<int> _downPointers = <int>{};
  bool _zoomed = false;
  ScrollHoldController? _hold;
  Drag? _drag;
  _SingleFingerHorizontalDragRecognizer? _dragRecognizer;

  @override
  void dispose() {
    _hold?.cancel();
    _drag?.cancel();
    _transformationController.dispose();
    super.dispose();
  }

  void _syncZoomState() {
    final zoomed = _transformationController.value.getMaxScaleOnAxis() > 1.01;
    if (_zoomed == zoomed) return;
    setState(() {
      _zoomed = zoomed;
    });
    widget.onZoomChanged(zoomed);
  }

  void _handleDragDown(DragDownDetails details) {
    if (_zoomed ||
        _downPointers.length > 1 ||
        !widget.pageController.hasClients) {
      return;
    }
    _hold = widget.pageController.position.hold(() => _hold = null);
  }

  void _handleDragStart(DragStartDetails details) {
    if (_zoomed ||
        _downPointers.length > 1 ||
        !widget.pageController.hasClients) {
      return;
    }
    _drag = widget.pageController.position.drag(details, () => _drag = null);
    _hold?.cancel();
    _hold = null;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    _drag?.update(details);
  }

  void _handleDragEnd(DragEndDetails details) {
    _drag?.end(details);
  }

  void _handleDragCancel() {
    _hold?.cancel();
    _drag?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        _downPointers.add(event.pointer);
        if (_downPointers.length > 1) {
          _dragRecognizer?.rejectPending();
        }
      },
      onPointerUp: (event) => _downPointers.remove(event.pointer),
      onPointerCancel: (event) => _downPointers.remove(event.pointer),
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 1.0,
        maxScale: 4.0,
        panEnabled: _zoomed,
        onInteractionUpdate: (_) => _syncZoomState(),
        onInteractionEnd: (_) => _syncZoomState(),
        child: RawGestureDetector(
          behavior: HitTestBehavior.translucent,
          gestures: <Type, GestureRecognizerFactory>{
            _SingleFingerHorizontalDragRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  _SingleFingerHorizontalDragRecognizer
                >(
                  () => _SingleFingerHorizontalDragRecognizer(debugOwner: this),
                  (instance) {
                    _dragRecognizer = instance;
                    instance
                      ..enabled = !_zoomed && _downPointers.length <= 1
                      ..onDown = _handleDragDown
                      ..onStart = _handleDragStart
                      ..onUpdate = _handleDragUpdate
                      ..onEnd = _handleDragEnd
                      ..onCancel = _handleDragCancel;
                  },
                ),
          },
          child: SizedBox.expand(
            child: Center(
              child: HiCachedImage(
                imageUrl: widget.url,
                headers: widget.headers,
                fit: BoxFit.contain,
                imageProviderOverride: widget.imageProviderOverride,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal drag recognizer active only when unzoomed and driven by a single
/// pointer so pinch gestures pass cleanly to the parent [InteractiveViewer].
class _SingleFingerHorizontalDragRecognizer
    extends HorizontalDragGestureRecognizer {
  _SingleFingerHorizontalDragRecognizer({super.debugOwner});

  bool enabled = true;

  @override
  void addPointer(PointerDownEvent event) {
    if (!enabled) return;
    super.addPointer(event);
  }

  void rejectPending() {
    resolve(GestureDisposition.rejected);
  }
}
