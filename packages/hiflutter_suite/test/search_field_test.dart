import 'package:flutter_test/flutter_test.dart';
import 'package:hiflutter_suite/hiflutter_suite.dart';
import 'package:material_ui/material_ui.dart';

class _OverrideSearchLocalizations extends HiSuiteLocalizations {
  _OverrideSearchLocalizations(super.locale);

  @override
  String get searchHint => 'Find packages';

  @override
  String get clearLabel => 'Erase query';
}

class _OverrideSearchDelegate
    extends LocalizationsDelegate<HiSuiteLocalizations> {
  const _OverrideSearchDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<HiSuiteLocalizations> load(Locale locale) async =>
      _OverrideSearchLocalizations(locale);

  @override
  bool shouldReload(_OverrideSearchDelegate old) => false;
}

Widget _wrapSearchApp(
  Widget child, {
  Locale locale = const Locale('en'),
  List<LocalizationsDelegate<dynamic>>? delegates,
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: HiSuiteLocalizations.supportedLocales,
    localizationsDelegates:
        delegates ?? HiSuiteLocalizations.localizationsDelegates,
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );
}

void main() {
  group('HiSearchField', () {
    testWidgets(
      'has fixed 48.0 height, capsule shape, search icon, and localized hints',
      (tester) async {
        await tester.pumpWidget(_wrapSearchApp(const HiSearchField()));

        final size = tester.getSize(find.byType(HiSearchField));
        expect(size.height, HiSuiteMetrics.searchFieldHeight);
        expect(find.byIcon(Icons.search), findsOneWidget);
        expect(find.text('Search'), findsOneWidget);
        expect(find.bySemanticsLabel('Clear'), findsNothing);

        final material = tester.widget<Material>(
          find
              .descendant(
                of: find.byType(HiSearchField),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(material.shape, const StadiumBorder());

        // Chinese locale.
        await tester.pumpWidget(
          _wrapSearchApp(const HiSearchField(), locale: const Locale('zh')),
        );
        expect(find.text('搜索'), findsOneWidget);

        // Custom delegate override.
        await tester.pumpWidget(
          _wrapSearchApp(
            const HiSearchField(),
            delegates: [
              const _OverrideSearchDelegate(),
              ...GlobalMaterialLocalizations.delegates,
            ],
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Find packages'), findsOneWidget);

        // Parameter override beats delegate.
        await tester.pumpWidget(
          _wrapSearchApp(
            const HiSearchField(
              hintText: 'Search users...',
              clearLabel: 'Reset input',
            ),
            delegates: [
              const _OverrideSearchDelegate(),
              ...GlobalMaterialLocalizations.delegates,
            ],
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Search users...'), findsOneWidget);
        await tester.enterText(find.byType(HiSearchField), 'alice');
        await tester.pump();
        expect(find.bySemanticsLabel('Reset input'), findsOneWidget);
      },
    );

    testWidgets(
      'manages internal controller, shows clear button with localized semantics, and invokes callbacks',
      (tester) async {
        final changes = <String>[];
        var submittedValue = '';
        var clears = 0;

        await tester.pumpWidget(
          _wrapSearchApp(
            HiSearchField(
              onChanged: changes.add,
              onSubmitted: (value) => submittedValue = value,
              onClear: () => clears++,
            ),
          ),
        );

        await tester.enterText(find.byType(HiSearchField), 'flutter');
        await tester.pump();
        expect(changes, ['flutter']);
        expect(find.bySemanticsLabel('Clear'), findsOneWidget);

        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pump();
        expect(submittedValue, 'flutter');

        await tester.tap(find.bySemanticsLabel('Clear'));
        await tester.pump();
        expect(changes, ['flutter', '']);
        expect(clears, 1);
        expect(find.text('flutter'), findsNothing);
        expect(find.bySemanticsLabel('Clear'), findsNothing);

        // Chinese clear label semantics.
        await tester.pumpWidget(
          _wrapSearchApp(const HiSearchField(), locale: const Locale('zh')),
        );
        await tester.enterText(find.byType(HiSearchField), '你好');
        await tester.pump();
        expect(find.bySemanticsLabel('清除'), findsOneWidget);
      },
    );

    testWidgets(
      'respects external controller without disposing it on unmount',
      (tester) async {
        final controller = TextEditingController(text: 'initial');
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _wrapSearchApp(HiSearchField(controller: controller)),
        );

        expect(find.text('initial'), findsOneWidget);
        expect(find.bySemanticsLabel('Clear'), findsOneWidget);

        controller.clear();
        await tester.pump();
        expect(find.bySemanticsLabel('Clear'), findsNothing);

        controller.text = 'updated';
        await tester.pump();
        expect(find.text('updated'), findsOneWidget);
        expect(find.bySemanticsLabel('Clear'), findsOneWidget);

        // Unmounting HiSearchField must not dispose caller's controller.
        await tester.pumpWidget(_wrapSearchApp(const SizedBox.shrink()));
        expect(controller.text, 'updated');
      },
    );

    testWidgets(
      'blocks editing and clearing when disabled and honors autofocus',
      (tester) async {
        final controller = TextEditingController(text: 'locked');
        addTearDown(controller.dispose);

        var changedCalls = 0;
        var clearCalls = 0;

        await tester.pumpWidget(
          _wrapSearchApp(
            HiSearchField(
              controller: controller,
              enabled: false,
              onChanged: (_) => changedCalls++,
              onClear: () => clearCalls++,
            ),
          ),
        );

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.enabled, isFalse);

        await tester.tap(find.bySemanticsLabel('Clear'));
        await tester.pump();
        expect(controller.text, 'locked');
        expect(changedCalls, 0);
        expect(clearCalls, 0);

        // Autofocus requests focus on mount.
        await tester.pumpWidget(
          _wrapSearchApp(const HiSearchField(autofocus: true)),
        );
        await tester.pump();
        final focusedField = tester.widget<TextField>(find.byType(TextField));
        expect(focusedField.autofocus, isTrue);
        expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);
      },
    );
  });
}
