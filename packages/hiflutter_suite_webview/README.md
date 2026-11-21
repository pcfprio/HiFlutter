# hiflutter_suite_webview

[webview_flutter](https://pub.dev/packages/webview_flutter) adapter for
[HiFlutter](https://github.com/pcfprio/HiFlutter), providing `HiWebViewPage`
with Material 3 chrome, progress indicator, `HiErrorView` retry, and external
link handoff via `HiLinkOpener` without exposing third-party types.

## Features

- **Zero third-party type leakage**: `package:hiflutter_suite_webview/hiflutter_suite_webview.dart`
  exposes only `HiWebViewPage`.
- **Title and progress**: displays a fixed `title` or automatically tracks the
  loaded page title, and renders a top `LinearProgressIndicator` for progress
  values `0`–`99` (hidden at `100` or when `showProgress` is `false`).
- **History-aware back navigation**: both the app bar `BackButton` and
  `PopScope` check `canGoBack()` first and navigate inside the page when
  possible before popping the route.
- **External link handoff**: non-HTTP(S) URLs, as well as HTTP(S) URLs whose
  host is outside a non-empty `allowedHosts` set, are blocked in-page and
  forwarded to `HiLinkOpener`.
- **Error recovery**: main-frame web resource errors render `HiErrorView` with
  a retry button (or a custom `errorBuilder`).

## Usage

```dart
import 'package:hiflutter_nav/hiflutter_nav.dart';
import 'package:hiflutter_suite_webview/hiflutter_suite_webview.dart';
import 'package:material_ui/material_ui.dart';

Widget buildHelpPage(HiLinkOpener linkOpener) {
  return HiWebViewPage(
    initialUrl: Uri.parse('https://example.com/help'),
    allowedHosts: const {'example.com', 'docs.example.com'},
    linkOpener: linkOpener,
  );
}
```

See `example/main.dart` for a complete runnable Flutter example.

## License

MIT
