import 'package:flutter_test/flutter_test.dart';
import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_suite/hiflutter_suite.dart';
import 'package:material_ui/material_ui.dart';

class _OverrideLocalizations extends HiSuiteLocalizations {
  _OverrideLocalizations(super.locale);

  @override
  String get loadingLabel => 'Loading data';

  @override
  String get retryLabel => 'Retry from delegate';

  @override
  String get emptyTitle => 'Delegate empty';
}

class _OverrideDelegate extends LocalizationsDelegate<HiSuiteLocalizations> {
  const _OverrideDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<HiSuiteLocalizations> load(Locale locale) async =>
      _OverrideLocalizations(locale);

  @override
  bool shouldReload(_OverrideDelegate old) => false;
}

Widget _wrap(
  Widget child, {
  Locale locale = const Locale('en'),
  List<LocalizationsDelegate<dynamic>>? delegates,
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: HiSuiteLocalizations.supportedLocales,
    localizationsDelegates: delegates ?? GlobalMaterialLocalizations.delegates,
    home: Scaffold(body: child),
  );
}

void main() {
  group('HiLoadingView', () {
    testWidgets(
      'renders enlarged spinner with localized semantics and no text by default',
      (tester) async {
        await tester.pumpWidget(_wrap(const HiLoadingView()));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(Text), findsNothing);
        expect(find.bySemanticsLabel('Loading'), findsOneWidget);

        final size = tester.getSize(find.byType(CircularProgressIndicator));
        expect(size.width, HiSuiteMetrics.pageLoadingIndicatorSize);
        expect(size.height, HiSuiteMetrics.pageLoadingIndicatorSize);
      },
    );

    testWidgets(
      'uses Chinese semantics, delegate override, and optional message',
      (tester) async {
        await tester.pumpWidget(
          _wrap(const HiLoadingView(), locale: const Locale('zh')),
        );
        expect(find.bySemanticsLabel('正在加载'), findsOneWidget);
        expect(find.byType(Text), findsNothing);

        await tester.pumpWidget(
          _wrap(
            const HiLoadingView(),
            delegates: [
              const _OverrideDelegate(),
              ...GlobalMaterialLocalizations.delegates,
            ],
          ),
        );
        await tester.pump();
        expect(find.bySemanticsLabel('Loading data'), findsOneWidget);

        await tester.pumpWidget(
          _wrap(
            const HiLoadingView(
              accessibilityLabel: 'Fetching items',
              message: 'Please wait...',
            ),
          ),
        );
        expect(find.bySemanticsLabel('Fetching items'), findsOneWidget);
        expect(find.text('Please wait...'), findsOneWidget);
      },
    );
  });

  group('HiEmptyView', () {
    testWidgets('renders localized default title and supports overrides', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const HiEmptyView()));
      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);

      await tester.pumpWidget(
        _wrap(const HiEmptyView(), locale: const Locale('zh')),
      );
      expect(find.text('暂无内容'), findsOneWidget);

      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          HiEmptyView(
            title: 'No favorites',
            message: 'Items you star will appear here.',
            icon: const Icon(Icons.star_border, key: ValueKey('custom-icon')),
            actionLabel: 'Browse',
            onAction: () => tapped = true,
          ),
        ),
      );
      expect(find.text('No favorites'), findsOneWidget);
      expect(find.text('Items you star will appear here.'), findsOneWidget);
      expect(find.byKey(const ValueKey('custom-icon')), findsOneWidget);
      await tester.tap(find.text('Browse'));
      expect(tapped, isTrue);
    });
  });

  group('HiErrorView', () {
    testWidgets(
      'renders localized error and retry button only when retryable with callback',
      (tester) async {
        var retried = false;
        await tester.pumpWidget(
          _wrap(
            HiErrorView(
              error: const HiNetworkError(),
              onRetry: () => retried = true,
            ),
          ),
        );

        expect(find.text('No internet connection'), findsOneWidget);
        expect(
          find.text('Check your network connection and try again.'),
          findsOneWidget,
        );
        expect(find.text('Retry'), findsOneWidget);

        await tester.tap(find.text('Retry'));
        expect(retried, isTrue);

        // Non-retryable error hides the retry button even when onRetry is passed.
        await tester.pumpWidget(
          _wrap(
            HiErrorView(error: const HiForbiddenError(), onRetry: () {}),
            locale: const Locale('zh'),
          ),
        );
        expect(find.text('无权限访问'), findsOneWidget);
        expect(find.text('重试'), findsNothing);

        // Retryable error without onRetry hides the retry button.
        await tester.pumpWidget(
          _wrap(const HiErrorView(error: HiTimeoutError())),
        );
        expect(find.text('Request timed out'), findsOneWidget);
        expect(find.text('Retry'), findsNothing);
      },
    );

    testWidgets('returns SizedBox.shrink for HiErrorDisplay.none', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          HiErrorView(
            error: const HiCancelledError(message: 'Cancelled'),
            title: 'Should not appear',
            onRetry: () {},
          ),
        ),
      );

      expect(find.byType(Text), findsNothing);
      expect(find.byType(Icon), findsNothing);
      expect(find.text('Should not appear'), findsNothing);
      expect(tester.getSize(find.byType(HiErrorView)), Size.zero);
    });

    testWidgets('supports delegate and widget parameter overrides', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          HiErrorView(error: const HiNetworkError(), onRetry: () {}),
          delegates: [
            const _OverrideDelegate(),
            ...GlobalMaterialLocalizations.delegates,
          ],
        ),
      );
      await tester.pump();
      expect(find.text('Retry from delegate'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(
          HiErrorView(
            error: const HiServerError(statusCode: 500),
            title: 'Custom Title',
            message: 'Custom Message',
            retryLabel: 'Custom Retry',
            onRetry: () {},
          ),
          delegates: [
            const _OverrideDelegate(),
            ...GlobalMaterialLocalizations.delegates,
          ],
        ),
      );
      await tester.pump();
      expect(find.text('Custom Title'), findsOneWidget);
      expect(find.text('Custom Message'), findsOneWidget);
      expect(find.text('Custom Retry'), findsOneWidget);
      expect(find.text('Retry from delegate'), findsNothing);
    });
  });

  group('HiStateView', () {
    testWidgets('switches between loading, empty, error, and content states', (
      tester,
    ) async {
      var retried = false;

      await tester.pumpWidget(
        _wrap(
          HiStateView(state: HiViewState.loading, child: const Text('Content')),
        ),
      );
      expect(find.byType(HiLoadingView), findsOneWidget);
      expect(find.text('Content'), findsNothing);

      await tester.pumpWidget(
        _wrap(
          HiStateView(
            state: HiViewState.empty,
            emptyTitle: 'Nothing found',
            child: const Text('Content'),
          ),
        ),
      );
      expect(find.byType(HiEmptyView), findsOneWidget);
      expect(find.text('Nothing found'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(
          HiStateView(
            state: HiViewState.error,
            error: const HiNetworkError(),
            onRetry: () => retried = true,
            child: const Text('Content'),
          ),
        ),
      );
      expect(find.byType(HiErrorView), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);

      await tester.pumpWidget(
        _wrap(
          HiStateView(state: HiViewState.content, child: const Text('Content')),
        ),
      );
      expect(find.text('Content'), findsOneWidget);
      expect(find.byType(HiLoadingView), findsNothing);
    });

    testWidgets(
      'auto constructor resolves state from loading, error, isEmpty',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const HiStateView.auto(
              isLoading: true,
              isEmpty: true,
              child: Text('Body'),
            ),
          ),
        );
        expect(find.byType(HiLoadingView), findsOneWidget);

        await tester.pumpWidget(
          _wrap(
            const HiStateView.auto(
              isLoading: false,
              isEmpty: true,
              error: HiTimeoutError(),
              child: Text('Body'),
            ),
          ),
        );
        expect(find.byType(HiErrorView), findsOneWidget);

        // Cancelled errors resolve to empty when there are no items.
        await tester.pumpWidget(
          _wrap(
            const HiStateView.auto(
              isLoading: false,
              isEmpty: true,
              error: HiCancelledError(),
              child: Text('Body'),
            ),
          ),
        );
        expect(find.byType(HiEmptyView), findsOneWidget);

        // Existing content remains visible while refreshing or on non-empty error.
        await tester.pumpWidget(
          _wrap(
            const HiStateView.auto(
              isLoading: true,
              isEmpty: false,
              error: HiNetworkError(),
              child: Text('Body'),
            ),
          ),
        );
        expect(find.text('Body'), findsOneWidget);
      },
    );
  });
}
