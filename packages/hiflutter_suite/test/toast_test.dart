import 'package:flutter_test/flutter_test.dart';
import 'package:hiflutter_suite/hiflutter_suite.dart';
import 'package:material_ui/material_ui.dart';

Widget _wrapToastApp(
  Widget Function(BuildContext context) builder, {
  ThemeData? theme,
}) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(body: Builder(builder: builder)),
  );
}

void main() {
  group('HiToast', () {
    testWidgets('shows message and auto-dismisses after duration', (
      tester,
    ) async {
      late HiToastHandle handle;

      await tester.pumpWidget(
        _wrapToastApp(
          (context) => Center(
            child: FilledButton(
              onPressed: () {
                handle = HiToast.show(
                  context,
                  'Saved',
                  duration: const Duration(milliseconds: 500),
                );
              },
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      expect(handle.isShown, isTrue);

      await tester.pump();
      expect(find.text('Saved'), findsOneWidget);
      expect(handle.isShown, isTrue);

      await tester.pump(const Duration(milliseconds: 499));
      expect(find.text('Saved'), findsOneWidget);
      expect(handle.isShown, isTrue);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(find.text('Saved'), findsNothing);
      expect(handle.isShown, isFalse);
    });

    testWidgets('handle.dismiss and dismissCurrent dismiss immediately', (
      tester,
    ) async {
      late HiToastHandle handle;

      await tester.pumpWidget(
        _wrapToastApp(
          (context) => Center(
            child: FilledButton(
              onPressed: () {
                handle = HiToast.show(
                  context,
                  'Uploading...',
                  duration: const Duration(seconds: 5),
                );
              },
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump();
      expect(find.text('Uploading...'), findsOneWidget);
      expect(handle.isShown, isTrue);

      handle.dismiss();
      // Idempotent second dismiss.
      handle.dismiss();
      await tester.pump();
      expect(find.text('Uploading...'), findsNothing);
      expect(handle.isShown, isFalse);

      // Show again and dismiss via HiToast.dismissCurrent().
      await tester.tap(find.text('Show'));
      await tester.pump();
      expect(find.text('Uploading...'), findsOneWidget);
      expect(handle.isShown, isTrue);

      HiToast.dismissCurrent();
      HiToast.dismissCurrent();
      await tester.pump();
      expect(find.text('Uploading...'), findsNothing);
      expect(handle.isShown, isFalse);
    });

    testWidgets('replaces previous toast so only latest is visible', (
      tester,
    ) async {
      late HiToastHandle first;
      late HiToastHandle second;
      var count = 0;

      await tester.pumpWidget(
        _wrapToastApp(
          (context) => Center(
            child: FilledButton(
              onPressed: () {
                count++;
                if (count == 1) {
                  first = HiToast.show(context, 'First toast');
                } else {
                  second = HiToast.show(context, 'Second toast');
                }
              },
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump();
      expect(find.text('First toast'), findsOneWidget);
      expect(first.isShown, isTrue);

      await tester.tap(find.text('Show'));
      await tester.pump();
      expect(find.text('First toast'), findsNothing);
      expect(first.isShown, isFalse);
      expect(find.text('Second toast'), findsOneWidget);
      expect(second.isShown, isTrue);

      // Old handle.dismiss() does not close the newer toast.
      first.dismiss();
      await tester.pump();
      expect(find.text('Second toast'), findsOneWidget);
      expect(second.isShown, isTrue);

      second.dismiss();
      await tester.pump();
    });

    testWidgets(
      'shrinks and centers single-line toast, expands multi-line with 16dp safe margins',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        late BuildContext capturedContext;
        await tester.pumpWidget(
          _wrapToastApp((context) {
            capturedContext = context;
            return const SizedBox.shrink();
          }),
        );

        // Single-line short message: wraps content and centers horizontally.
        final shortHandle = HiToast.show(capturedContext, 'Copied');
        await tester.pump();

        final shortTextFinder = find.text('Copied');
        final shortMaterialFinder = find
            .ancestor(of: shortTextFinder, matching: find.byType(Material))
            .first;
        final shortRect = tester.getRect(shortMaterialFinder);
        expect(
          shortRect.width,
          lessThan(400.0 - 2 * HiSuiteMetrics.horizontalSafeMargin),
        );
        expect(shortRect.center.dx, closeTo(200.0, 1.0));
        expect(
          tester.widget<Text>(shortTextFinder).textAlign,
          TextAlign.center,
        );
        shortHandle.dismiss();
        await tester.pump();

        // Multi-line message: fills available width inside 16dp safe margins, left-aligned.
        const longMessage =
            'This is a deliberately long toast message that wraps across multiple lines inside the viewport.';
        final longHandle = HiToast.show(capturedContext, longMessage);
        await tester.pump();

        final longTextFinder = find.text(longMessage);
        final longMaterialFinder = find
            .ancestor(of: longTextFinder, matching: find.byType(Material))
            .first;
        final longRect = tester.getRect(longMaterialFinder);
        expect(
          longRect.left,
          closeTo(HiSuiteMetrics.horizontalSafeMargin, 0.5),
        );
        expect(
          longRect.right,
          closeTo(400.0 - HiSuiteMetrics.horizontalSafeMargin, 0.5),
        );
        final longText = tester.widget<Text>(longTextFinder);
        expect(longText.textAlign, TextAlign.start);
        expect(longText.maxLines, 5);
        expect(longText.overflow, TextOverflow.ellipsis);
        longHandle.dismiss();
        await tester.pump();
      },
    );

    testWidgets('cancels pending timer safely when widget tree is disposed', (
      tester,
    ) async {
      late HiToastHandle handle;

      await tester.pumpWidget(
        _wrapToastApp(
          (context) => Center(
            child: FilledButton(
              onPressed: () {
                handle = HiToast.show(
                  context,
                  'Long-lived toast',
                  duration: const Duration(seconds: 30),
                );
              },
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump();
      expect(handle.isShown, isTrue);

      // Disposing the entire widget tree must cancel the internal Timer cleanly.
      await tester.pumpWidget(const SizedBox.shrink());
      expect(handle.isShown, isFalse);
    });

    testWidgets(
      'treats explicit newline as multi-line, respects theme colors, and handles immediate replace',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        const inverseSurface = Color(0xFF223344);
        const onInverseSurface = Color(0xFFF0F4F8);
        final theme = ThemeData(
          colorScheme: const ColorScheme.light(
            inverseSurface: inverseSurface,
            onInverseSurface: onInverseSurface,
          ),
        );

        late BuildContext capturedContext;
        await tester.pumpWidget(
          _wrapToastApp((context) {
            capturedContext = context;
            return const SizedBox.shrink();
          }, theme: theme),
        );

        final first = HiToast.show(capturedContext, 'Unpumped');
        final second = HiToast.show(capturedContext, 'Line 1\nLine 2');
        expect(first.isShown, isFalse);
        expect(second.isShown, isTrue);

        await tester.pump();
        expect(find.text('Unpumped'), findsNothing);
        expect(find.text('Line 1\nLine 2'), findsOneWidget);

        final textFinder = find.text('Line 1\nLine 2');
        final materialFinder = find
            .ancestor(of: textFinder, matching: find.byType(Material))
            .first;
        final material = tester.widget<Material>(materialFinder);
        expect(material.color, inverseSurface);
        expect(tester.widget<Text>(textFinder).style?.color, onInverseSurface);

        final rect = tester.getRect(materialFinder);
        expect(rect.left, closeTo(HiSuiteMetrics.horizontalSafeMargin, 0.5));
        expect(
          rect.right,
          closeTo(400.0 - HiSuiteMetrics.horizontalSafeMargin, 0.5),
        );
      },
    );
  });
}
