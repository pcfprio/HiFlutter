import 'dart:async';

import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_nav/hiflutter_nav.dart';
import 'package:hiflutter_suite/hiflutter_suite.dart';
import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Material 3 WebView page backed by `webview_flutter`.
///
/// Handles initial page loading, optional linear loading progress (0–99),
/// automatic page title updates when [title] is omitted, history-aware back
/// navigation via both the app bar [BackButton] and [PopScope], external link
/// handoff through [HiLinkOpener], and main-frame error recovery via
/// [HiErrorView] without exposing any `webview_flutter` types.
class HiWebViewPage extends StatefulWidget {
  /// Creates a WebView page loading [initialUrl].
  const HiWebViewPage({
    super.key,
    required this.initialUrl,
    this.title,
    this.linkOpener,
    this.allowedHosts = const {},
    this.showProgress = true,
    this.errorBuilder,
  });

  /// Initial URL to load in the WebView.
  final Uri initialUrl;

  /// Optional fixed app bar title.
  ///
  /// When `null` or empty, the app bar displays the current web page title.
  final String? title;

  /// Optional link opener invoked when a navigation target is blocked from
  /// loading in-page.
  final HiLinkOpener? linkOpener;

  /// Optional host allow-list for in-page `http`/`https` navigation.
  ///
  /// When empty (default), any `http` or `https` URL loads inside the WebView
  /// while non-HTTP(S) schemes are prevented and handed off to [linkOpener].
  /// When non-empty, `http`/`https` URLs whose host is not in [allowedHosts]
  /// are also prevented and handed off to [linkOpener]. Entries may use a
  /// leading `*.` wildcard to match subdomains.
  final Set<String> allowedHosts;

  /// Whether to show the linear loading progress bar while loading (`0..99`).
  final bool showProgress;

  /// Optional custom error builder replacing the default [HiErrorView].
  final Widget Function(
    BuildContext context,
    HiError error,
    VoidCallback retry,
  )?
  errorBuilder;

  @override
  State<HiWebViewPage> createState() => _HiWebViewPageState();
}

class _HiWebViewPageState extends State<HiWebViewPage> {
  late final WebViewController _controller;
  late Set<String> _normalizedAllowedHosts;
  int _progress = 0;
  String? _pageTitle;
  HiError? _error;
  bool _handlingBack = false;

  @override
  void initState() {
    super.initState();
    _normalizedAllowedHosts = _normalizeHosts(widget.allowedHosts);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _handleNavigationRequest,
          onPageStarted: _handlePageStarted,
          onPageFinished: _handlePageFinished,
          onProgress: _handleProgress,
          onWebResourceError: _handleWebResourceError,
          onUrlChange: _handleUrlChange,
        ),
      );
    unawaited(_loadInitialUrl());
  }

  @override
  void didUpdateWidget(HiWebViewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.allowedHosts != oldWidget.allowedHosts) {
      _normalizedAllowedHosts = _normalizeHosts(widget.allowedHosts);
    }
    if (widget.initialUrl != oldWidget.initialUrl) {
      setState(() {
        _error = null;
        _progress = 0;
        _pageTitle = null;
      });
      unawaited(_loadInitialUrl());
    }
  }

  Future<void> _loadInitialUrl() async {
    try {
      await _controller.loadRequest(widget.initialUrl);
    } catch (e, s) {
      if (!mounted) return;
      setState(() {
        _error = HiError.from(e, s);
        _progress = 100;
      });
    }
  }

  static Set<String> _normalizeHosts(Set<String> hosts) => {
    for (final host in hosts)
      if (host.trim().isNotEmpty) host.trim().toLowerCase(),
  };

  NavigationDecision _handleNavigationRequest(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null || !uri.hasScheme) {
      return NavigationDecision.prevent;
    }

    final scheme = uri.scheme.toLowerCase();
    final isHttp = scheme == 'http' || scheme == 'https';
    if (!isHttp) {
      _handoffExternalLink(uri);
      return NavigationDecision.prevent;
    }

    if (_normalizedAllowedHosts.isNotEmpty && !_isHostAllowed(uri.host)) {
      _handoffExternalLink(uri);
      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  bool _isHostAllowed(String rawHost) {
    final host = rawHost.toLowerCase();
    if (host.isEmpty) return false;
    return _normalizedAllowedHosts.any(
      (allowed) => allowed.startsWith('*.')
          ? host.endsWith(allowed.substring(1))
          : host == allowed,
    );
  }

  void _handoffExternalLink(Uri uri) {
    final opener = widget.linkOpener;
    if (opener == null) return;
    unawaited(opener.open(uri).then((_) {}, onError: (Object _) {}));
  }

  void _handlePageStarted(String url) {
    if (!mounted) return;
    setState(() {
      _error = null;
      _progress = 0;
    });
  }

  void _handlePageFinished(String url) {
    if (!mounted) return;
    setState(() {
      _progress = 100;
    });
    unawaited(_syncTitle());
  }

  void _handleProgress(int progress) {
    if (!mounted) return;
    final clamped = progress.clamp(0, 100);
    if (_progress == clamped) return;
    setState(() {
      _progress = clamped;
    });
  }

  void _handleWebResourceError(WebResourceError error) {
    if (error.isForMainFrame == false) return;
    if (!mounted) return;
    setState(() {
      _error = _mapWebResourceError(error);
      _progress = 100;
    });
  }

  void _handleUrlChange(UrlChange change) {
    unawaited(_syncTitle());
  }

  Future<void> _syncTitle() async {
    final fixed = widget.title?.trim();
    if (fixed != null && fixed.isNotEmpty) return;
    try {
      final fetched = await _controller.getTitle();
      if (!mounted) return;
      final normalized = fetched?.trim();
      if (normalized != null &&
          normalized.isNotEmpty &&
          normalized != _pageTitle) {
        setState(() {
          _pageTitle = normalized;
        });
      }
    } catch (_) {
      // Ignore platform title read failures during page transitions.
    }
  }

  Future<void> _retry() async {
    if (!mounted) return;
    setState(() {
      _error = null;
      _progress = 0;
    });
    try {
      final current = await _controller.currentUrl();
      if (current != null && current.isNotEmpty) {
        await _controller.reload();
      } else {
        await _controller.loadRequest(widget.initialUrl);
      }
    } catch (e, s) {
      if (!mounted) return;
      setState(() {
        _error = HiError.from(e, s);
        _progress = 100;
      });
    }
  }

  Future<void> _handleBack([Object? popResult]) async {
    if (_handlingBack) return;
    _handlingBack = true;
    try {
      if (await _controller.canGoBack()) {
        if (mounted && _error != null) {
          setState(() {
            _error = null;
          });
        }
        await _controller.goBack();
        return;
      }
      if (!mounted) return;
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop(popResult);
      }
    } finally {
      _handlingBack = false;
    }
  }

  static HiError _mapWebResourceError(WebResourceError error) {
    final description = error.description.trim();
    final message = description.isEmpty ? null : description;
    return switch (error.errorType) {
      WebResourceErrorType.timeout => HiTimeoutError(
        message: message,
        cause: error,
        retryable: true,
      ),
      WebResourceErrorType.authentication ||
      WebResourceErrorType.proxyAuthentication => HiUnauthorizedError(
        message: message,
        cause: error,
        retryable: true,
      ),
      WebResourceErrorType.unsafeResource => HiForbiddenError(
        message: message,
        cause: error,
        retryable: true,
      ),
      WebResourceErrorType.fileNotFound => HiNotFoundError(
        message: message,
        cause: error,
        retryable: true,
      ),
      WebResourceErrorType.badUrl ||
      WebResourceErrorType.unsupportedScheme ||
      WebResourceErrorType.unsupportedAuthScheme => HiDecodeError(
        message: message,
        cause: error,
        retryable: true,
      ),
      WebResourceErrorType.connect ||
      WebResourceErrorType.hostLookup ||
      WebResourceErrorType.failedSslHandshake ||
      WebResourceErrorType.io ||
      WebResourceErrorType.redirectLoop ||
      WebResourceErrorType.tooManyRequests ||
      _ => HiNetworkError(message: message, cause: error, retryable: true),
    };
  }

  @override
  Widget build(BuildContext context) {
    final fixedTitle = widget.title?.trim();
    final displayTitle = (fixedTitle != null && fixedTitle.isNotEmpty)
        ? fixedTitle
        : (_pageTitle ?? '');
    final error = _error;
    final showProgressBar =
        widget.showProgress && error == null && _progress < 100;
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_handleBack(result));
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _handleBack),
          title: Text(
            displayTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (error != null)
              Positioned.fill(
                child: ColoredBox(
                  color: colorScheme.surface,
                  child:
                      widget.errorBuilder?.call(context, error, _retry) ??
                      HiErrorView(error: error, onRetry: _retry),
                ),
              ),
            if (showProgressBar)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(value: _progress / 100.0),
              ),
          ],
        ),
      ),
    );
  }
}
