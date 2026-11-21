import 'package:flutter_test/flutter_test.dart';
import 'package:hiflutter_suite/hiflutter_suite.dart';
import 'package:material_ui/material_ui.dart';

class _OverrideConfirmLocalizations extends HiSuiteLocalizations {
  _OverrideConfirmLocalizations(super.locale);

  @override
  String get confirmLabel => 'Proceed';

  @override
  String get cancelLabel => 'Back';
}

class _OverrideConfirmDelegate
    extends LocalizationsDelegate<HiSuiteLocalizations> {
  const _OverrideConfirmDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<HiSuiteLocalizations> load(Locale locale) async =>
      _OverrideConfirmLocalizations(locale);

  @override
  bool shouldReload(_OverrideConfirmDelegate old) => false;
}

Widget _wrapDialogApp({
  required Future<bool> Function(BuildContext context) onTrigger,
  required ValueChanged<bool> onResult,
  Locale locale = const Locale('en'),
  ThemeData? theme,
  List<LocalizationsDelegate<dynamic>>? delegates,
}) {
  return MaterialApp(
    locale: locale,
    theme: theme,
    supportedLocales: HiSuiteLocalizations.supportedLocales,
    localizationsDelegates:
        delegates ?? HiSuiteLocalizations.localizationsDelegates,
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: FilledButton(
            onPressed: () async {
              final result = await onTrigger(context);
              onResult(result);
            },
            child: const Text('Open Dialog'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('HiConfirmDialog', () {
    testWidgets('shows title, optional message, and returns true on confirm', (
      tester,
    ) async {
      bool? result;
      await tester.pumpWidget(
        _wrapDialogApp(
          onTrigger: (context) => HiConfirmDialog.show(
            context,
            title: 'Delete item?',
            message: 'This action cannot be undone.',
          ),
          onResult: (value) => result = value,
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Delete item?'), findsOneWidget);
      expect(find.text('This action cannot be undone.'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(find.text('Delete item?'), findsNothing);
    });

    testWidgets('returns false on cancel and omits empty message', (
      tester,
    ) async {
      bool? result;
      await tester.pumpWidget(
        _wrapDialogApp(
          onTrigger: (context) =>
              HiConfirmDialog.show(context, title: 'Log out'),
          onResult: (value) => result = value,
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Log out'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(find.text('Log out'), findsNothing);
    });

    testWidgets('respects barrierDismissible true and false', (tester) async {
      bool? dismissibleResult;
      await tester.pumpWidget(
        _wrapDialogApp(
          onTrigger: (context) =>
              HiConfirmDialog.show(context, title: 'Dismissible'),
          onResult: (value) => dismissibleResult = value,
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Dismissible'), findsOneWidget);

      // Tap outside the centered dialog card to dismiss via barrier.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(dismissibleResult, isFalse);
      expect(find.text('Dismissible'), findsNothing);

      bool? nonDismissibleResult;
      await tester.pumpWidget(
        _wrapDialogApp(
          onTrigger: (context) => HiConfirmDialog.show(
            context,
            title: 'Required choice',
            barrierDismissible: false,
          ),
          onResult: (value) => nonDismissibleResult = value,
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Required choice'), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(nonDismissibleResult, isNull);
      expect(find.text('Required choice'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(nonDismissibleResult, isFalse);
    });

    testWidgets(
      'uses Chinese defaults, delegate overrides, and explicit label overrides',
      (tester) async {
        // Chinese defaults.
        await tester.pumpWidget(
          _wrapDialogApp(
            locale: const Locale('zh'),
            onTrigger: (context) =>
                HiConfirmDialog.show(context, title: '确认提交'),
            onResult: (_) {},
          ),
        );
        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();
        expect(find.text('确定'), findsOneWidget);
        expect(find.text('取消'), findsOneWidget);
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();

        // Custom delegate override.
        await tester.pumpWidget(
          _wrapDialogApp(
            delegates: [
              const _OverrideConfirmDelegate(),
              ...GlobalMaterialLocalizations.delegates,
            ],
            onTrigger: (context) =>
                HiConfirmDialog.show(context, title: 'Delegate check'),
            onResult: (_) {},
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();
        expect(find.text('Proceed'), findsOneWidget);
        expect(find.text('Back'), findsOneWidget);
        await tester.tap(find.text('Back'));
        await tester.pumpAndSettle();

        // Explicit parameter overrides beat delegate.
        await tester.pumpWidget(
          _wrapDialogApp(
            delegates: [
              const _OverrideConfirmDelegate(),
              ...GlobalMaterialLocalizations.delegates,
            ],
            onTrigger: (context) => HiConfirmDialog.show(
              context,
              title: 'Explicit check',
              confirmLabel: 'Yes, Delete',
              cancelLabel: 'Keep',
            ),
            onResult: (_) {},
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();
        expect(find.text('Yes, Delete'), findsOneWidget);
        expect(find.text('Keep'), findsOneWidget);
        expect(find.text('Proceed'), findsNothing);
        await tester.tap(find.text('Yes, Delete'));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'highlights destructive confirm button with colorScheme.error',
      (tester) async {
        const primaryColor = Color(0xFF1565C0);
        const errorColor = Color(0xFFD32F2F);
        const onErrorColor = Color(0xFFFFFFFF);

        final theme = ThemeData(
          colorScheme: const ColorScheme.light(
            primary: primaryColor,
            error: errorColor,
            onError: onErrorColor,
          ),
        );

        await tester.pumpWidget(
          _wrapDialogApp(
            theme: theme,
            onTrigger: (context) => HiConfirmDialog.show(
              context,
              title: 'Remove account',
              confirmLabel: 'Remove',
              isDestructive: true,
            ),
            onResult: (_) {},
          ),
        );

        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        final confirmButtonFinder = find.widgetWithText(FilledButton, 'Remove');
        expect(confirmButtonFinder, findsOneWidget);

        final button = tester.widget<FilledButton>(confirmButtonFinder);
        final resolvedBg = button.style?.backgroundColor?.resolve({});
        final resolvedFg = button.style?.foregroundColor?.resolve({});
        expect(resolvedBg, errorColor);
        expect(resolvedFg, onErrorColor);

        await tester.tap(confirmButtonFinder);
        await tester.pumpAndSettle();

        // Non-destructive dialog does not apply error background.
        await tester.pumpWidget(
          _wrapDialogApp(
            theme: theme,
            onTrigger: (context) => HiConfirmDialog.show(
              context,
              title: 'Save changes',
              confirmLabel: 'Save',
            ),
            onResult: (_) {},
          ),
        );
        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        final normalFinder = find.widgetWithText(FilledButton, 'Save');
        final normalButton = tester.widget<FilledButton>(normalFinder);
        expect(
          normalButton.style?.backgroundColor?.resolve({}),
          isNot(errorColor),
        );

        await tester.tap(normalFinder);
        await tester.pumpAndSettle();
      },
    );
  });
}
