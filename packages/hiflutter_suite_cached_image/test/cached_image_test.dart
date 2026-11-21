import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_suite/hiflutter_suite.dart';
import 'package:hiflutter_suite_cached_image/hiflutter_suite_cached_image.dart';
import 'package:material_ui/material_ui.dart';

/// Valid 1x1 transparent PNG bytes.
final Uint8List _kTransparentPng = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, //
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, //
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, //
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, //
  0x42, 0x60, 0x82,
]);

/// An [ImageProvider] whose image stream remains pending forever.
class _PendingImageProvider extends ImageProvider<_PendingImageProvider> {
  const _PendingImageProvider();

  @override
  Future<_PendingImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_PendingImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
    _PendingImageProvider key,
    ImageDecoderCallback decode,
  ) {
    final completer = Completer<ui.Codec>();
    return MultiFrameImageStreamCompleter(codec: completer.future, scale: 1.0);
  }
}

/// An [ImageProvider] that always fails with [error].
class _FailingImageProvider extends ImageProvider<_FailingImageProvider> {
  const _FailingImageProvider(this.error);

  final Object error;

  @override
  Future<_FailingImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_FailingImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
    _FailingImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: Future<ui.Codec>.error(error),
      scale: 1.0,
    );
  }
}

Widget _wrap(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: HiSuiteLocalizations.supportedLocales,
    localizationsDelegates: HiSuiteLocalizations.localizationsDelegates,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('HiCachedImage', () {
    testWidgets(
      'shows default error state immediately for empty or blank URL',
      (tester) async {
        await tester.pumpWidget(
          _wrap(const HiCachedImage(imageUrl: '', width: 120, height: 120)),
        );
        expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        HiError? receivedError;
        await tester.pumpWidget(
          _wrap(
            HiCachedImage(
              imageUrl: '   ',
              width: 120,
              height: 120,
              errorWidget: (context, error) {
                receivedError = error;
                return const Text('Empty URL error');
              },
            ),
          ),
        );
        expect(find.text('Empty URL error'), findsOneWidget);
        expect(receivedError, isA<HiError>());
      },
    );

    testWidgets(
      'renders compact loading placeholder by default and allows override',
      (tester) async {
        const pendingProvider = _PendingImageProvider();

        await tester.pumpWidget(
          _wrap(
            const HiCachedImage(
              imageUrl: 'https://example.com/pending.png',
              width: 100,
              height: 100,
              imageProviderOverride: pendingProvider,
            ),
          ),
        );

        final indicatorFinder = find.byType(CircularProgressIndicator);
        expect(indicatorFinder, findsOneWidget);
        final indicatorSize = tester.getSize(indicatorFinder);
        expect(indicatorSize.width, HiSuiteMetrics.inlineLoadingIndicatorSize);
        expect(indicatorSize.height, HiSuiteMetrics.inlineLoadingIndicatorSize);

        await tester.pumpWidget(
          _wrap(
            HiCachedImage(
              imageUrl: 'https://example.com/pending.png',
              width: 100,
              height: 100,
              imageProviderOverride: pendingProvider,
              placeholder: (context) =>
                  const Text('Custom loading', key: ValueKey('placeholder')),
            ),
          ),
        );

        expect(find.byKey(const ValueKey('placeholder')), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );

    testWidgets(
      'renders image from override with sizing, borderRadius, and onTap',
      (tester) async {
        var tapped = false;
        final provider = MemoryImage(_kTransparentPng);

        await tester.pumpWidget(
          _wrap(
            HiCachedImage(
              imageUrl: 'https://example.com/avatar.png',
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              borderRadius: BorderRadius.circular(12),
              onTap: () => tapped = true,
              imageProviderOverride: provider,
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(ClipRRect), findsOneWidget);
        expect(find.byType(Image), findsOneWidget);
        expect(tester.getSize(find.byType(HiCachedImage)), const Size(80, 80));

        await tester.tap(find.byType(HiCachedImage));
        expect(tapped, isTrue);
      },
    );

    testWidgets('shows error view when injected ImageProvider fails', (
      tester,
    ) async {
      final failing404 = _FailingImageProvider(
        NetworkImageLoadException(
          statusCode: 404,
          uri: Uri.parse('https://example.com/missing.png'),
        ),
      );

      await tester.pumpWidget(
        _wrap(
          HiCachedImage(
            imageUrl: 'https://example.com/missing.png',
            width: 160,
            height: 120,
            imageProviderOverride: failing404,
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);

      HiError? capturedError;
      await tester.pumpWidget(
        _wrap(
          HiCachedImage(
            imageUrl: 'https://example.com/missing.png',
            width: 160,
            height: 120,
            imageProviderOverride: failing404,
            errorWidget: (context, error) {
              capturedError = error;
              return const Text('Failed to load image');
            },
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Failed to load image'), findsOneWidget);
      expect(capturedError, isA<HiNotFoundError>());
    });

    testWidgets(
      'renders compact error icon in tight containers without overflow',
      (tester) async {
        await tester.pumpWidget(
          _wrap(const HiCachedImage(imageUrl: '', width: 32, height: 32)),
        );
        expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('HiImageViewer', () {
    testWidgets('opens fullscreen route, swipes between pages, and closes', (
      tester,
    ) async {
      final urls = [
        'https://example.com/1.png',
        'https://example.com/2.png',
        'https://example.com/3.png',
      ];

      await tester.pumpWidget(
        MaterialApp(
          supportedLocales: HiSuiteLocalizations.supportedLocales,
          localizationsDelegates: HiSuiteLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    HiImageViewer.show(
                      context,
                      urls: urls,
                      imageProviderBuilder: (_) =>
                          MemoryImage(_kTransparentPng),
                    );
                  },
                  child: const Text('Open viewer'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open viewer'));
      await tester.pumpAndSettle();

      expect(find.byType(HiImageViewer), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);

      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);

      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('3 / 3'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.byType(HiImageViewer), findsNothing);
      expect(find.text('Open viewer'), findsOneWidget);
    });

    testWidgets('supports pinch-to-zoom via InteractiveViewer', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HiImageViewer(
            urls: const ['https://example.com/zoom.png'],
            imageProviderBuilder: (_) => MemoryImage(_kTransparentPng),
          ),
        ),
      );
      await tester.pump();

      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      final controller = viewer.transformationController!;
      expect(controller.value.getMaxScaleOnAxis(), closeTo(1.0, 0.001));

      final center = tester.getCenter(find.byType(InteractiveViewer));
      final g1 = await tester.startGesture(center + const Offset(-40, 0));
      final g2 = await tester.startGesture(center + const Offset(40, 0));
      await tester.pump();

      await g1.moveBy(const Offset(-60, 0));
      await g2.moveBy(const Offset(60, 0));
      await tester.pump();

      await g1.up();
      await g2.up();
      await tester.pumpAndSettle();

      expect(controller.value.getMaxScaleOnAxis(), greaterThan(1.2));
    });

    testWidgets('respects initialIndex and supports single-image view', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          HiImageViewer(
            urls: const [
              'https://example.com/a.png',
              'https://example.com/b.png',
            ],
            initialIndex: 1,
            imageProviderBuilder: (_) => MemoryImage(_kTransparentPng),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('2 / 2'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(
          HiImageViewer(
            urls: const ['https://example.com/only.png'],
            imageProviderBuilder: (_) => MemoryImage(_kTransparentPng),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('1 / 1'), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
    });

    testWidgets('handles empty url list gracefully with close action', (
      tester,
    ) async {
      var closed = false;
      await tester.pumpWidget(
        _wrap(HiImageViewer(urls: const [], onClose: () => closed = true)),
      );
      await tester.pump();
      expect(find.byType(HiEmptyView), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      expect(closed, isTrue);
    });
  });
}
