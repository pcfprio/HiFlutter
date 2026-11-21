# hiflutter

Umbrella entry package for [HiFlutter](https://github.com/pcfprio/HiFlutter). Re-exports the HiFlutter-owned public APIs across the core families without exposing third-party types or performing any automatic initialization.

## Included Packages

- **Base**: `hiflutter_base`, `hiflutter_base_log_file`
- **Core**: `hiflutter_core`, `hiflutter_core_device`
- **Net**: `hiflutter_net`, `hiflutter_net_dio`
- **Nav**: `hiflutter_nav`, `hiflutter_nav_go_router`, `hiflutter_nav_url_launcher`
- **Store**: `hiflutter_store`, `hiflutter_store_prefs`, `hiflutter_store_secure`, `hiflutter_store_file`
- **Suite**: `hiflutter_suite`

Optional adapters (`hiflutter_net_connectivity`, `hiflutter_suite_cached_image`, `hiflutter_suite_webview`) and optional Riverpod integration (`hiflutter_riverpod`) are installed separately.

## Usage

```dart
import 'package:hiflutter/hiflutter.dart';

Future<void> main() async {
  HiLog.install(HiLogger([const HiLogRoute(HiConsoleLogSink())]));

  final client = HiHttpClient(
    transport: HiDioTransport(),
    baseUrl: Uri.parse('https://api.example.com'),
  );
  HiLog.info(() => 'Configured client: $client');
}
```
