import 'package:flutter_test/flutter_test.dart';
import 'package:hiflutter_suite/hiflutter_suite.dart';
import 'package:material_ui/material_ui.dart';

Widget _wrapButtonApp(Widget child, {ThemeData? theme}) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );
}

void main() {
  group('HiPrimaryButton', () {
    testWidgets(
      'renders label and child, triggers onPressed, and expands by default',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        var presses = 0;
        await tester.pumpWidget(
          _wrapButtonApp(
            HiPrimaryButton(label: 'Continue', onPressed: () => presses++),
          ),
        );

        expect(find.text('Continue'), findsOneWidget);
        final expandedSize = tester.getSize(find.byType(HiPrimaryButton));
        expect(expandedSize.height, HiSuiteMetrics.primaryButtonMinHeight);
        expect(expandedSize.width, 400.0 - 32.0);

        await tester.tap(find.byType(HiPrimaryButton));
        expect(presses, 1);

        await tester.pumpWidget(
          _wrapButtonApp(
            HiPrimaryButton(
              expand: false,
              minHeight: 56.0,
              onPressed: () => presses++,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [Icon(Icons.send), SizedBox(width: 8), Text('Send')],
              ),
            ),
          ),
        );

        final compactSize = tester.getSize(find.byType(HiPrimaryButton));
        expect(compactSize.height, 56.0);
        expect(compactSize.width, lessThan(400.0 - 32.0));

        await tester.tap(find.text('Send'));
        expect(presses, 2);
      },
    );

    testWidgets('supports rounded and capsule shapes and theme primary color', (
      tester,
    ) async {
      const primary = Color(0xFF6750A4);
      const onPrimary = Color(0xFFFFFFFF);
      final theme = ThemeData(
        colorScheme: const ColorScheme.light(
          primary: primary,
          onPrimary: onPrimary,
        ),
      );

      await tester.pumpWidget(
        _wrapButtonApp(
          HiPrimaryButton(label: 'Rounded', onPressed: () {}),
          theme: theme,
        ),
      );

      var button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.style?.backgroundColor?.resolve({}), primary);
      expect(button.style?.foregroundColor?.resolve({}), onPrimary);
      final roundedShape = button.style?.shape?.resolve({});
      expect(
        roundedShape,
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            HiSuiteMetrics.buttonBorderRadius,
          ),
        ),
      );

      await tester.pumpWidget(
        _wrapButtonApp(
          HiPrimaryButton(
            label: 'Capsule',
            shape: HiButtonShape.capsule,
            onPressed: () {},
          ),
          theme: theme,
        ),
      );

      button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.style?.shape?.resolve({}), const StadiumBorder());
    });

    testWidgets('shows disabled gray background when onPressed is null', (
      tester,
    ) async {
      const primary = Color(0xFF0061A4);
      final theme = ThemeData(
        colorScheme: const ColorScheme.light(primary: primary),
      );

      await tester.pumpWidget(
        _wrapButtonApp(
          const HiPrimaryButton(label: 'Disabled', onPressed: null),
          theme: theme,
        ),
      );

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      final resolvedBg = button.style?.backgroundColor?.resolve({
        WidgetState.disabled,
      });
      expect(resolvedBg, isNot(primary));
    });

    testWidgets(
      'displays inline loading indicator and blocks taps when loading',
      (tester) async {
        const primary = Color(0xFF0061A4);
        const onPrimary = Color(0xFFFFFFFF);
        final theme = ThemeData(
          colorScheme: const ColorScheme.light(
            primary: primary,
            onPrimary: onPrimary,
          ),
        );

        var presses = 0;
        await tester.pumpWidget(
          _wrapButtonApp(
            HiPrimaryButton(
              label: 'Submit',
              loading: true,
              onPressed: () => presses++,
            ),
            theme: theme,
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Submit'), findsNothing);

        final spinnerSize = tester.getSize(
          find.byType(CircularProgressIndicator),
        );
        expect(spinnerSize.width, HiSuiteMetrics.inlineLoadingIndicatorSize);
        expect(spinnerSize.height, HiSuiteMetrics.inlineLoadingIndicatorSize);

        final button = tester.widget<FilledButton>(find.byType(FilledButton));
        final resolvedBg = button.style?.backgroundColor?.resolve({
          WidgetState.disabled,
        });
        expect(resolvedBg, primary);

        await tester.tap(find.byType(HiPrimaryButton));
        expect(presses, 0);
      },
    );
  });
}
