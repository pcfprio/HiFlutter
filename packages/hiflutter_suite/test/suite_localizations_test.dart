import 'package:flutter_test/flutter_test.dart';
import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_suite/hiflutter_suite.dart';
import 'package:material_ui/material_ui.dart';

class _CustomSuiteLocalizations extends HiSuiteLocalizations {
  _CustomSuiteLocalizations(super.locale);

  @override
  String get retryLabel => 'Try Again Now';

  @override
  String get errorNetworkTitle => 'Custom Offline';
}

class _CustomSuiteLocalizationsDelegate
    extends LocalizationsDelegate<HiSuiteLocalizations> {
  const _CustomSuiteLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<HiSuiteLocalizations> load(Locale locale) async =>
      _CustomSuiteLocalizations(locale);

  @override
  bool shouldReload(_CustomSuiteLocalizationsDelegate old) => false;
}

void main() {
  group('HiSuiteLocalizations', () {
    test('returns English and Chinese defaults for locales', () {
      final en = HiSuiteLocalizations.forLocale(const Locale('en'));
      expect(en.loadingLabel, 'Loading');
      expect(en.emptyTitle, 'Nothing here yet');
      expect(en.retryLabel, 'Retry');
      expect(en.loadMoreLoadingLabel, 'Loading more...');
      expect(en.loadMorePromptLabel, 'Load more');
      expect(en.loadMoreNoMoreLabel, 'No more items');
      expect(en.loadMoreFailedLabel, 'Failed to load more');

      final zh = HiSuiteLocalizations.forLocale(const Locale('zh'));
      expect(zh.loadingLabel, '正在加载');
      expect(zh.emptyTitle, '暂无内容');
      expect(zh.retryLabel, '重试');
      expect(zh.loadMoreLoadingLabel, '正在加载更多');
      expect(zh.loadMorePromptLabel, '加载更多');
      expect(zh.loadMoreNoMoreLabel, '没有更多了');
      expect(zh.loadMoreFailedLabel, '加载失败');

      final zhHans = HiSuiteLocalizations.forLocale(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      );
      expect(zhHans.retryLabel, '重试');

      final fallback = HiSuiteLocalizations.forLocale(const Locale('ja'));
      expect(fallback.retryLabel, 'Retry');
      expect(HiSuiteLocalizations.forLocale(null).retryLabel, 'Retry');
    });

    test(
      'describeError maps every HiError subtype and handles none safely',
      () {
        final en = HiSuiteLocalizations.forLocale(const Locale('en'));
        final zh = HiSuiteLocalizations.forLocale(const Locale('zh'));

        final cases = <(HiError, HiErrorIllustration)>[
          (const HiNetworkError(), HiErrorIllustration.network),
          (const HiTimeoutError(), HiErrorIllustration.timeout),
          (const HiUnauthorizedError(), HiErrorIllustration.unauthorized),
          (const HiForbiddenError(), HiErrorIllustration.forbidden),
          (const HiNotFoundError(), HiErrorIllustration.notFound),
          (const HiServerError(statusCode: 500), HiErrorIllustration.server),
          (const HiDecodeError(), HiErrorIllustration.data),
          (const HiStorageError(), HiErrorIllustration.generic),
          (const HiUnknownError(), HiErrorIllustration.generic),
        ];

        for (final (error, expectedIllustration) in cases) {
          final enMsg = en.describeError(error);
          expect(enMsg.shouldDisplay, isTrue);
          expect(enMsg.illustration, expectedIllustration);
          expect(enMsg.title, isNotEmpty);
          expect(enMsg.message, isNotEmpty);

          final zhMsg = zh.describeError(error);
          expect(zhMsg.shouldDisplay, isTrue);
          expect(zhMsg.illustration, expectedIllustration);
          expect(zhMsg.title, isNotEmpty);
          expect(zhMsg.message, isNotEmpty);
          expect(zhMsg.title, isNot(enMsg.title));
        }

        final customDetail = en.describeError(
          const HiServerError(statusCode: 503, message: 'Service maintenance'),
        );
        expect(customDetail.title, en.errorServerTitle);
        expect(customDetail.message, 'Service maintenance');
        expect(customDetail.illustration, HiErrorIllustration.server);
        expect(customDetail.shouldDisplay, isTrue);

        final blankDetail = en.describeError(
          const HiNetworkError(message: '   '),
        );
        expect(blankDetail.message, en.errorNetworkMessage);

        final cancelled = en.describeError(
          const HiCancelledError(message: 'User cancelled'),
        );
        expect(cancelled.shouldDisplay, isFalse);
        expect(cancelled.illustration, isNull);
        expect(cancelled.title, isEmpty);
        expect(cancelled.message, isEmpty);
      },
    );

    testWidgets(
      'of(context) falls back to EN without Localizations and ZH with locale',
      (tester) async {
        late HiSuiteLocalizations resolved;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Builder(
              builder: (context) {
                resolved = HiSuiteLocalizations.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        expect(resolved.retryLabel, 'Retry');

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh'),
            supportedLocales: const [Locale('en'), Locale('zh')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Builder(
              builder: (context) {
                resolved = HiSuiteLocalizations.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        expect(resolved.retryLabel, '重试');
      },
    );

    testWidgets(
      'of(context) prefers registered custom delegate over defaults',
      (tester) async {
        late HiSuiteLocalizations resolved;

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            supportedLocales: HiSuiteLocalizations.supportedLocales,
            localizationsDelegates: [
              const _CustomSuiteLocalizationsDelegate(),
              ...GlobalMaterialLocalizations.delegates,
            ],
            home: Builder(
              builder: (context) {
                resolved = HiSuiteLocalizations.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(resolved.retryLabel, 'Try Again Now');
        expect(resolved.loadingLabel, 'Loading');
        expect(
          resolved.describeError(const HiNetworkError()).title,
          'Custom Offline',
        );
      },
    );

    testWidgets('built-in delegate loads en and zh in MaterialApp', (
      tester,
    ) async {
      late HiSuiteLocalizations resolved;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          supportedLocales: HiSuiteLocalizations.supportedLocales,
          localizationsDelegates: HiSuiteLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) {
              resolved = HiSuiteLocalizations.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(resolved.emptyTitle, '暂无内容');
      expect(resolved.loadMoreNoMoreLabel, '没有更多了');
    });
  });
}
