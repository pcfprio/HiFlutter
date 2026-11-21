import 'package:flutter_test/flutter_test.dart';
import 'package:hiflutter_nav/hiflutter_nav.dart';
import 'package:hiflutter_suite/hiflutter_suite.dart';
import 'package:hiflutter_suite_webview/hiflutter_suite_webview.dart';
import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

class _FakeWebViewPlatform extends WebViewPlatform {
  _FakeWebViewPlatform();

  _FakeWebViewController? lastController;
  _FakeNavigationDelegate? lastDelegate;

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    final controller = _FakeWebViewController(params);
    lastController = controller;
    return controller;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) {
    final delegate = _FakeNavigationDelegate(params);
    lastDelegate = delegate;
    return delegate;
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) {
    return _FakeWebViewWidget(params);
  }
}

class _FakeWebViewController extends PlatformWebViewController {
  _FakeWebViewController(super.params) : super.implementation();

  final List<LoadRequestParams> loadedRequests = [];
  String? currentPageUrl;
  String? pageTitle;
  bool backEnabled = false;
  int goBackCalls = 0;
  int reloadCalls = 0;
  JavaScriptMode? javaScriptMode;
  _FakeNavigationDelegate? navigationDelegate;

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {
    this.javaScriptMode = javaScriptMode;
  }

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {
    navigationDelegate = handler as _FakeNavigationDelegate;
  }

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    loadedRequests.add(params);
    currentPageUrl = params.uri.toString();
  }

  @override
  Future<String?> currentUrl() async => currentPageUrl;

  @override
  Future<String?> getTitle() async => pageTitle;

  @override
  Future<bool> canGoBack() async => backEnabled;

  @override
  Future<void> goBack() async {
    goBackCalls++;
  }

  @override
  Future<void> reload() async {
    reloadCalls++;
  }
}

class _FakeNavigationDelegate extends PlatformNavigationDelegate {
  _FakeNavigationDelegate(super.params) : super.implementation();

  NavigationRequestCallback? onNavigationRequest;
  PageEventCallback? onPageStarted;
  PageEventCallback? onPageFinished;
  ProgressCallback? onProgress;
  WebResourceErrorCallback? onWebResourceError;
  UrlChangeCallback? onUrlChange;

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback onNavigationRequest,
  ) async {
    this.onNavigationRequest = onNavigationRequest;
  }

  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) async {
    this.onPageStarted = onPageStarted;
  }

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async {
    this.onPageFinished = onPageFinished;
  }

  @override
  Future<void> setOnProgress(ProgressCallback onProgress) async {
    this.onProgress = onProgress;
  }

  @override
  Future<void> setOnWebResourceError(
    WebResourceErrorCallback onWebResourceError,
  ) async {
    this.onWebResourceError = onWebResourceError;
  }

  @override
  Future<void> setOnUrlChange(UrlChangeCallback onUrlChange) async {
    this.onUrlChange = onUrlChange;
  }

  @override
  Future<void> setOnHttpError(HttpResponseErrorCallback onHttpError) async {}

  @override
  Future<void> setOnHttpAuthRequest(
    HttpAuthRequestCallback onHttpAuthRequest,
  ) async {}

  @override
  Future<void> setOnSSlAuthError(SslAuthErrorCallback onSslAuthError) async {}
}

class _FakeWebViewWidget extends PlatformWebViewWidget {
  _FakeWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand(key: ValueKey('fake-webview'));
  }
}

class _FakeLinkOpener implements HiLinkOpener {
  final List<(Uri, HiLinkMode)> opened = [];
  bool nextResult = true;

  @override
  Future<bool> canOpen(Uri uri) async => nextResult;

  @override
  Future<bool> open(
    Uri uri, {
    HiLinkMode mode = HiLinkMode.platformDefault,
  }) async {
    opened.add((uri, mode));
    return nextResult;
  }
}

Widget _wrapApp(Widget home) {
  return MaterialApp(
    supportedLocales: HiSuiteLocalizations.supportedLocales,
    localizationsDelegates: HiSuiteLocalizations.localizationsDelegates,
    home: home,
  );
}

void main() {
  late _FakeWebViewPlatform platform;

  setUp(() {
    platform = _FakeWebViewPlatform();
    WebViewPlatform.instance = platform;
  });

  group('HiWebViewPage', () {
    testWidgets('loads initialUrl and updates dynamic title', (tester) async {
      final initialUrl = Uri.parse('https://example.com/start');
      await tester.pumpWidget(_wrapApp(HiWebViewPage(initialUrl: initialUrl)));

      final controller = platform.lastController!;
      final delegate = controller.navigationDelegate!;
      expect(controller.loadedRequests.map((r) => r.uri), [initialUrl]);
      expect(find.byKey(const ValueKey('fake-webview')), findsOneWidget);

      controller.pageTitle = 'Dynamic Title';
      delegate.onPageFinished?.call(initialUrl.toString());
      await tester.pumpAndSettle();
      expect(find.text('Dynamic Title'), findsOneWidget);

      controller.pageTitle = 'Updated SPA Title';
      delegate.onUrlChange?.call(
        const UrlChange(url: 'https://example.com/next'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Updated SPA Title'), findsOneWidget);
    });

    testWidgets('keeps explicit title fixed even when page title changes', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapApp(
          HiWebViewPage(
            initialUrl: Uri.parse('https://example.com/terms'),
            title: 'Terms of Service',
          ),
        ),
      );

      final controller = platform.lastController!;
      controller.pageTitle = 'Ignored Page Title';
      controller.navigationDelegate!.onPageFinished?.call(
        'https://example.com/terms',
      );
      await tester.pumpAndSettle();

      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Ignored Page Title'), findsNothing);
    });

    testWidgets('shows progress indicator from 0 to 99 and hides at 100', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapApp(HiWebViewPage(initialUrl: Uri.parse('https://example.com'))),
      );

      final delegate = platform.lastController!.navigationDelegate!;
      delegate.onProgress?.call(0);
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      delegate.onProgress?.call(45);
      await tester.pump();
      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, closeTo(0.45, 0.001));

      delegate.onProgress?.call(100);
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('hides progress indicator when showProgress is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapApp(
          HiWebViewPage(
            initialUrl: Uri.parse('https://example.com'),
            showProgress: false,
          ),
        ),
      );

      platform.lastController!.navigationDelegate!.onProgress?.call(50);
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets(
      'navigates back inside webview when canGoBack is true, otherwise pops route',
      (tester) async {
        await tester.pumpWidget(
          _wrapApp(
            Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => HiWebViewPage(
                            initialUrl: Uri.parse('https://example.com'),
                          ),
                        ),
                      );
                    },
                    child: const Text('Open web'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open web'));
        await tester.pumpAndSettle();
        expect(find.byType(HiWebViewPage), findsOneWidget);

        final controller = platform.lastController!;
        controller.backEnabled = true;

        // AppBar back button navigates inside WebView history.
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(controller.goBackCalls, 1);
        expect(find.byType(HiWebViewPage), findsOneWidget);

        // System back (PopScope) also navigates inside WebView history.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(controller.goBackCalls, 2);
        expect(find.byType(HiWebViewPage), findsOneWidget);

        // Once history is exhausted, system back pops the route.
        controller.backEnabled = false;
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(controller.goBackCalls, 2);
        expect(find.byType(HiWebViewPage), findsNothing);
        expect(find.text('Open web'), findsOneWidget);

        // Re-open and verify AppBar back button pops route when no history.
        await tester.tap(find.text('Open web'));
        await tester.pumpAndSettle();
        platform.lastController!.backEnabled = false;
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.byType(HiWebViewPage), findsNothing);
        expect(find.text('Open web'), findsOneWidget);
      },
    );

    testWidgets(
      'intercepts external schemes and disallowed hosts via HiLinkOpener',
      (tester) async {
        final opener = _FakeLinkOpener();
        await tester.pumpWidget(
          _wrapApp(
            HiWebViewPage(
              initialUrl: Uri.parse('https://example.com/start'),
              linkOpener: opener,
              allowedHosts: const {'example.com', 'docs.example.com'},
            ),
          ),
        );

        final onRequest =
            platform.lastController!.navigationDelegate!.onNavigationRequest!;

        // Allowed host stays in WebView.
        expect(
          await onRequest(
            const NavigationRequest(
              url: 'https://docs.example.com/guide',
              isMainFrame: true,
            ),
          ),
          NavigationDecision.navigate,
        );
        expect(opener.opened, isEmpty);

        // Disallowed host is prevented and forwarded to HiLinkOpener.
        expect(
          await onRequest(
            const NavigationRequest(
              url: 'https://outside.org/page',
              isMainFrame: true,
            ),
          ),
          NavigationDecision.prevent,
        );
        expect(opener.opened.length, 1);
        expect(opener.opened.first.$1, Uri.parse('https://outside.org/page'));

        // Non-http(s) scheme is prevented and forwarded to HiLinkOpener.
        expect(
          await onRequest(
            const NavigationRequest(
              url: 'mailto:help@example.com',
              isMainFrame: true,
            ),
          ),
          NavigationDecision.prevent,
        );
        expect(opener.opened.length, 2);
        expect(opener.opened.last.$1, Uri.parse('mailto:help@example.com'));
      },
    );

    testWidgets('allows any http/https host when allowedHosts is empty', (
      tester,
    ) async {
      final opener = _FakeLinkOpener();
      await tester.pumpWidget(
        _wrapApp(
          HiWebViewPage(
            initialUrl: Uri.parse('https://example.com'),
            linkOpener: opener,
          ),
        ),
      );

      final onRequest =
          platform.lastController!.navigationDelegate!.onNavigationRequest!;

      expect(
        await onRequest(
          const NavigationRequest(
            url: 'https://another-site.org/article',
            isMainFrame: true,
          ),
        ),
        NavigationDecision.navigate,
      );
      expect(opener.opened, isEmpty);

      expect(
        await onRequest(
          const NavigationRequest(url: 'tel:10086', isMainFrame: true),
        ),
        NavigationDecision.prevent,
      );
      expect(opener.opened.map((e) => e.$1), [Uri.parse('tel:10086')]);
    });

    testWidgets('shows HiErrorView on main-frame error and supports retry', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapApp(
          HiWebViewPage(initialUrl: Uri.parse('https://example.com/fail')),
        ),
      );

      final controller = platform.lastController!;
      final delegate = controller.navigationDelegate!;

      // Subframe errors do not replace the page with HiErrorView.
      delegate.onWebResourceError?.call(
        const WebResourceError(
          errorCode: -1,
          description: 'Subframe failed',
          errorType: WebResourceErrorType.connect,
          isForMainFrame: false,
        ),
      );
      await tester.pump();
      expect(find.byType(HiErrorView), findsNothing);

      // Main-frame error displays HiErrorView with retry button.
      delegate.onWebResourceError?.call(
        const WebResourceError(
          errorCode: -2,
          description: 'Connection lost',
          errorType: WebResourceErrorType.hostLookup,
          isForMainFrame: true,
        ),
      );
      await tester.pump();
      expect(find.byType(HiErrorView), findsOneWidget);
      expect(find.text('Connection lost'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(find.byType(HiErrorView), findsNothing);
      expect(
        controller.reloadCalls + controller.loadedRequests.length,
        greaterThan(1),
      );
    });

    testWidgets('supports custom errorBuilder override', (tester) async {
      await tester.pumpWidget(
        _wrapApp(
          HiWebViewPage(
            initialUrl: Uri.parse('https://example.com/custom-error'),
            errorBuilder: (context, error, retry) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Custom error: ${error.kind.name}'),
                FilledButton(onPressed: retry, child: const Text('Try again')),
              ],
            ),
          ),
        ),
      );

      final controller = platform.lastController!;
      controller.navigationDelegate!.onWebResourceError?.call(
        const WebResourceError(
          errorCode: -8,
          description: 'Timed out',
          errorType: WebResourceErrorType.timeout,
          isForMainFrame: true,
        ),
      );
      await tester.pump();

      expect(find.text('Custom error: timeout'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(find.text('Custom error: timeout'), findsNothing);
    });

    testWidgets('reloads when initialUrl changes and matches wildcard hosts', (
      tester,
    ) async {
      final opener = _FakeLinkOpener();
      final firstUrl = Uri.parse('https://sub.example.com/one');
      final secondUrl = Uri.parse('https://sub.example.com/two');

      await tester.pumpWidget(
        _wrapApp(
          HiWebViewPage(
            initialUrl: firstUrl,
            allowedHosts: const {'*.Example.com'},
            linkOpener: opener,
          ),
        ),
      );

      final controller = platform.lastController!;
      final onRequest = controller.navigationDelegate!.onNavigationRequest!;
      expect(
        await onRequest(
          const NavigationRequest(
            url: 'https://API.EXAMPLE.COM/v1',
            isMainFrame: true,
          ),
        ),
        NavigationDecision.navigate,
      );
      expect(
        await onRequest(
          const NavigationRequest(
            url: 'https://example.com/root',
            isMainFrame: true,
          ),
        ),
        NavigationDecision.prevent,
      );
      expect(opener.opened.length, 1);

      await tester.pumpWidget(
        _wrapApp(
          HiWebViewPage(
            initialUrl: secondUrl,
            allowedHosts: const {'*.Example.com'},
            linkOpener: opener,
          ),
        ),
      );
      await tester.pump();

      expect(controller.loadedRequests.map((r) => r.uri), [
        firstUrl,
        secondUrl,
      ]);
    });
  });
}
