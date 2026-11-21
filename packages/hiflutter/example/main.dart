import 'package:flutter/widgets.dart';
import 'package:hiflutter/hiflutter.dart';

Future<void> main() async {
  HiLog.install(HiLogger([const HiLogRoute(HiConsoleLogSink())]));
  final capture = HiErrorCapture.install(reporter: const HiNoOpCrashReporter());

  final homeRoute = HiRoute<void>('/', encode: (_) => const {}, decode: (_) {});
  final navigator = HiGoRouterNavigator(
    table: HiRouteTable([homeRoute]),
    pages: [
      homeRoute.page((_, _) => const Center(child: Text('HiFlutter Umbrella'))),
    ],
    initialLocation: '/',
  );

  capture.runGuarded(
    () => runApp(
      WidgetsApp.router(
        color: const Color(0xFF1565C0),
        routerConfig: navigator.routerConfig,
      ),
    ),
  );
}
