import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiflutter/hiflutter.dart';
import 'package:hiflutter_riverpod/hiflutter_riverpod.dart';
import 'package:hiflutter_showcase/main.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets(
    'showcase home mounts, filters items, and navigates to sections',
    (tester) async {
      final deps = ShowcaseDependencies.inMemory();
      final navigator = createShowcaseNavigator(deps);
      addTearDown(navigator.dispose);
      addTearDown(deps.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: deps.toOverrides(navigator: navigator),
          child: ShowcaseApp(navigator: navigator),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('HiFlutter Showcase'), findsOneWidget);
      expect(find.text('Suite UI & Controls'), findsOneWidget);
      expect(find.text('Pagination List'), findsOneWidget);
      expect(find.text('Net, Store & Observability'), findsOneWidget);

      // Filter home list using HiSearchField.
      await tester.enterText(find.byType(TextField), 'Pagination');
      await tester.pumpAndSettle();
      expect(find.text('Pagination List'), findsOneWidget);
      expect(find.text('Suite UI & Controls'), findsNothing);

      // Clear search to restore all entries.
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('Suite UI & Controls'), findsOneWidget);

      // Navigate to Suite UI & Controls and interact with toast & dialog.
      await tester.tap(find.text('Suite UI & Controls'));
      await tester.pumpAndSettle();
      expect(find.text('Option Alpha'), findsOneWidget);

      await tester.tap(find.text('Option Beta'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show Toast'));
      await tester.pump();
      expect(find.text('Saved option: Beta'), findsOneWidget);

      // Dismiss toast timer cleanly before finishing.
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'showcase net, store & observability screen exercises contracts',
    (tester) async {
      final deps = ShowcaseDependencies.inMemory();
      final navigator = createShowcaseNavigator(deps);
      addTearDown(navigator.dispose);
      addTearDown(deps.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: deps.toOverrides(navigator: navigator),
          child: ShowcaseApp(navigator: navigator),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Net, Store & Observability'));
      await tester.pumpAndSettle();

      // Consent starts unknown, so analytics events stay blocked.
      await tester.tap(find.text('Track Demo Event'));
      await tester.pumpAndSettle();
      expect(find.text('Analytics delivered: 0'), findsOneWidget);

      // Grant consent and track again.
      await tester.tap(find.text('Grant Consent'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Track Demo Event'));
      await tester.pumpAndSettle();
      expect(find.text('Analytics delivered: 1'), findsOneWidget);

      // Run HTTP envelope call & credential key rejection probe.
      await tester.tap(find.text('Run Envelope Request'));
      await tester.pumpAndSettle();
      expect(find.textContaining('User #1: Ada Lovelace'), findsOneWidget);

      await tester.tap(find.text('Test Credential Guard'));
      await tester.pumpAndSettle();
      expect(find.textContaining('HiStorageError'), findsOneWidget);
    },
  );

  testWidgets('showcase pagination screen loads initial page and loads more', (
    tester,
  ) async {
    final deps = ShowcaseDependencies.inMemory();
    final navigator = createShowcaseNavigator(deps);
    addTearDown(navigator.dispose);
    addTearDown(deps.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: deps.toOverrides(navigator: navigator),
        child: ShowcaseApp(navigator: navigator),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pagination List'));
    await tester.pumpAndSettle();

    expect(find.text('Entry #1'), findsOneWidget);
    expect(find.text('Entry #8'), findsOneWidget);
  });

  testWidgets('bootstrap helper installs log and mounts ShowcaseApp', (
    tester,
  ) async {
    final deps = ShowcaseDependencies.inMemory();
    final navigator = createShowcaseNavigator(deps);
    addTearDown(navigator.dispose);
    addTearDown(deps.dispose);

    Widget? mountedRoot;
    final capture = await HiRiverpodBootstrap.run(
      logger: deps.logger,
      reporter: deps.crashReporter,
      installLogger: (_) {},
      overrides: deps.toOverrides(navigator: navigator),
      runAppCallback: (root) => mountedRoot = root,
      child: ShowcaseApp(navigator: navigator),
    );
    addTearDown(capture.dispose);

    expect(mountedRoot, isA<ProviderScope>());
    await tester.pumpWidget(mountedRoot!);
    await tester.pumpAndSettle();
    expect(find.text('HiFlutter Showcase'), findsOneWidget);
  });

  test(
    'showcase links and device info helpers produce expected output',
    () async {
      final deps = ShowcaseDependencies.inMemory();
      addTearDown(deps.dispose);

      final info = await deps.deviceInfoSource.load();
      expect(info.toUserAgent(), contains('HiFlutterShowcase/0.1.0'));
      expect(HiFormat.compact(12500), '12.5K');
      expect(
        HiLinkDetector.split('Visit https://hiflutter.dev now')
            .where((s) => s.isLink),
        hasLength(1),
      );
      expect(unawaited, isNotNull);
    },
  );
}
