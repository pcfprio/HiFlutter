import 'package:hiflutter/hiflutter.dart';
import 'package:hiflutter_riverpod/hiflutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'src/showcase_deps.dart';
import 'src/showcase_pages.dart';

export 'src/showcase_deps.dart';
export 'src/showcase_pages.dart';

/// Application entry point for the HiFlutter showcase app.
Future<void> main() async {
  final logSink = ShowcaseLogSink();
  final deferredFileSink = DeferredFileLogSink();
  final logger = HiLogger([
    const HiLogRoute(HiConsoleLogSink(), minLevel: HiLogLevel.debug),
    HiLogRoute(logSink, minLevel: HiLogLevel.info),
    HiLogRoute(deferredFileSink, minLevel: HiLogLevel.info),
  ]);
  final consent = HiConsent();
  final crashReporter = HiConsentGatedCrashReporter(
    const HiNoOpCrashReporter(),
    consent: consent,
  );

  late ShowcaseDependencies deps;
  late HiGoRouterNavigator navigator;

  await HiRiverpodBootstrap.run(
    logger: logger,
    reporter: crashReporter,
    beforeRunApp: () async {
      deps = await ShowcaseDependencies.live(
        logger: logger,
        logSink: logSink,
        fileSinkTarget: deferredFileSink,
        consent: consent,
        crashReporter: crashReporter,
      );
      navigator = createShowcaseNavigator(deps);
    },
    overridesBuilder: () => deps.toOverrides(navigator: navigator),
    builder: () => ShowcaseApp(navigator: navigator),
  );
}

/// Root widget of the HiFlutter showcase application.
class ShowcaseApp extends StatelessWidget {
  /// Creates the root application widget driven by [navigator].
  const ShowcaseApp({super.key, required this.navigator, this.locale});

  /// Configured [HiGoRouterNavigator] supplying router configuration.
  final HiGoRouterNavigator navigator;

  /// Optional locale override used in tests and language previews.
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'HiFlutter Showcase',
      locale: locale,
      supportedLocales: HiSuiteLocalizations.supportedLocales,
      localizationsDelegates: HiSuiteLocalizations.localizationsDelegates,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
      ),
      routerConfig: navigator.routerConfig,
    );
  }
}
