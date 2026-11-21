import 'dart:ui' show Tristate;

import 'package:flutter_test/flutter_test.dart';
import 'package:hiflutter_suite/hiflutter_suite.dart';
import 'package:material_ui/material_ui.dart';

Widget _wrapListApp(Widget child, {ThemeData? theme}) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(body: child),
  );
}

void main() {
  group('HiListSection', () {
    testWidgets(
      'renders header, footer, rounded card children, dividers, and margin',
      (tester) async {
        await tester.pumpWidget(
          _wrapListApp(
            ListView(
              children: [
                HiListSection(
                  header: const Text('Preferences'),
                  footer: const Text('Changes sync automatically.'),
                  margin: const EdgeInsets.all(16),
                  children: const [
                    HiListRow(title: Text('Theme')),
                    HiListRow(title: Text('Language')),
                    HiListRow(title: Text('Notifications')),
                  ],
                ),
              ],
            ),
          ),
        );

        expect(find.text('Preferences'), findsOneWidget);
        expect(find.text('Changes sync automatically.'), findsOneWidget);
        expect(find.text('Theme'), findsOneWidget);
        expect(find.text('Language'), findsOneWidget);
        expect(find.text('Notifications'), findsOneWidget);
        // 3 children -> 2 dividers.
        expect(find.byType(Divider), findsNWidgets(2));

        // Verify outer margin on the section.
        final paddingFinder = find.byWidgetPredicate(
          (widget) =>
              widget is Padding && widget.padding == const EdgeInsets.all(16),
        );
        expect(paddingFinder, findsOneWidget);
      },
    );

    testWidgets('omits dividers when showDividers is false', (tester) async {
      await tester.pumpWidget(
        _wrapListApp(
          const HiListSection(
            showDividers: false,
            children: [
              HiListRow(title: Text('First')),
              HiListRow(title: Text('Second')),
            ],
          ),
        ),
      );

      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('renders zero size when empty without header or footer', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapListApp(const Center(child: HiListSection(children: []))),
      );

      expect(tester.getSize(find.byType(HiListSection)), Size.zero);
    });
  });

  group('HiListRow', () {
    testWidgets(
      'enforces 52.0 min height, renders slots, padding, and handles tap',
      (tester) async {
        var taps = 0;

        await tester.pumpWidget(
          _wrapListApp(
            HiListRow(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profile'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => taps++,
            ),
          ),
        );

        final rowSize = tester.getSize(find.byType(HiListRow));
        expect(rowSize.height, HiSuiteMetrics.listRowMinHeight);
        expect(find.byIcon(Icons.person_outline), findsOneWidget);
        expect(find.text('Profile'), findsOneWidget);
        expect(find.byIcon(Icons.chevron_right), findsOneWidget);

        await tester.tap(find.byType(HiListRow));
        expect(taps, 1);

        // With subtitle and custom padding it expands cleanly past 52.0.
        await tester.pumpWidget(
          _wrapListApp(
            const HiListRow(
              title: Text('Account'),
              subtitle: Text('Manage sign-in methods and security settings'),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        );

        final expandedSize = tester.getSize(find.byType(HiListRow));
        expect(
          expandedSize.height,
          greaterThan(HiSuiteMetrics.listRowMinHeight),
        );
      },
    );

    testWidgets(
      'dims visually, disables tap, and reports disabled semantics when disabled',
      (tester) async {
        var taps = 0;

        await tester.pumpWidget(
          _wrapListApp(
            HiListRow(
              title: const Text('Locked option'),
              enabled: false,
              onTap: () => taps++,
            ),
          ),
        );

        await tester.tap(find.byType(HiListRow));
        expect(taps, 0);

        final opacityWidget = tester.widget<Opacity>(
          find.descendant(
            of: find.byType(HiListRow),
            matching: find.byType(Opacity),
          ),
        );
        expect(opacityWidget.opacity, lessThan(1.0));

        final semantics = tester.getSemantics(find.byType(HiListRow));
        expect(semantics.flagsCollection.isEnabled, Tristate.isFalse);
      },
    );

    testWidgets('works without Material ancestor', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: HiListRow(
            title: const Text('Standalone'),
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.text('Standalone'));
      expect(tapped, isTrue);
    });
  });

  group('HiSelectableListRow', () {
    testWidgets(
      'has 52.0 min height, shows primary checkmark when selected, and updates semantics',
      (tester) async {
        const primary = Color(0xFF006A6A);
        final theme = ThemeData(
          colorScheme: const ColorScheme.light(primary: primary),
        );

        var selected = true;
        var taps = 0;

        await tester.pumpWidget(
          _wrapListApp(
            StatefulBuilder(
              builder: (context, setState) => HiSelectableListRow(
                title: const Text('English'),
                subtitle: const Text('System default'),
                selected: selected,
                onTap: () {
                  taps++;
                  setState(() => selected = !selected);
                },
              ),
            ),
            theme: theme,
          ),
        );

        expect(
          tester.getSize(find.byType(HiSelectableListRow)).height,
          greaterThanOrEqualTo(HiSuiteMetrics.listRowMinHeight),
        );

        final checkIcon = tester.widget<Icon>(find.byIcon(Icons.check));
        expect(checkIcon.color, primary);

        var semantics = tester.getSemantics(find.byType(HiSelectableListRow));
        expect(semantics.flagsCollection.isSelected, Tristate.isTrue);
        expect(semantics.flagsCollection.isEnabled, Tristate.isTrue);

        // Toggle off.
        await tester.tap(find.byType(HiSelectableListRow));
        await tester.pump();
        expect(taps, 1);
        expect(find.byIcon(Icons.check), findsNothing);

        semantics = tester.getSemantics(find.byType(HiSelectableListRow));
        expect(semantics.flagsCollection.isSelected, Tristate.isFalse);
      },
    );

    testWidgets(
      'enforces exact 52.0 height for single line, supports custom trailing, and honors enabled=false',
      (tester) async {
        var taps = 0;

        await tester.pumpWidget(
          _wrapListApp(
            HiSelectableListRow(
              title: const Text('Compact'),
              selected: true,
              enabled: false,
              trailing: const Icon(Icons.star, key: ValueKey('custom-trail')),
              onTap: () => taps++,
            ),
          ),
        );

        expect(
          tester.getSize(find.byType(HiSelectableListRow)).height,
          HiSuiteMetrics.listRowMinHeight,
        );
        expect(find.byIcon(Icons.check), findsNothing);
        expect(find.byKey(const ValueKey('custom-trail')), findsOneWidget);

        await tester.tap(find.byType(HiSelectableListRow));
        expect(taps, 0);

        final semantics = tester.getSemantics(find.byType(HiSelectableListRow));
        expect(semantics.flagsCollection.isSelected, Tristate.isTrue);
        expect(semantics.flagsCollection.isEnabled, Tristate.isFalse);
      },
    );
  });
}
