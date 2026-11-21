import 'package:hiflutter_nav/hiflutter_nav.dart';
import 'package:hiflutter_suite/hiflutter_suite.dart';
import 'package:hiflutter_suite_webview/hiflutter_suite_webview.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  runApp(const _WebViewExampleApp());
}

class _WebViewExampleApp extends StatelessWidget {
  const _WebViewExampleApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      supportedLocales: HiSuiteLocalizations.supportedLocales,
      localizationsDelegates: HiSuiteLocalizations.localizationsDelegates,
      home: HiWebViewPage(
        initialUrl: Uri.parse('https://example.com'),
        allowedHosts: const {'example.com'},
        linkOpener: const _NoopLinkOpener(),
      ),
    );
  }
}

class _NoopLinkOpener implements HiLinkOpener {
  const _NoopLinkOpener();

  @override
  Future<bool> canOpen(Uri uri) async => false;

  @override
  Future<bool> open(
    Uri uri, {
    HiLinkMode mode = HiLinkMode.platformDefault,
  }) async => false;
}
