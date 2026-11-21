# hiflutter_core

Flutter foundation contracts and utilities of
[HiFlutter](https://github.com/pcfprio/HiFlutter). It depends only on
`hiflutter_base` and the Flutter SDK; plug in the platform device-info
implementation with `hiflutter_core_device`.

## Features

- **Global error capture**: `HiErrorCapture.install` forwards framework,
  platform dispatcher, and guarded-zone errors into `HiCrashReporter` and
  `HiLog`.
- **Dispose-safe value notifier**: `HiSafeValueNotifier` ignores post-dispose
  writes and defers frame-phase updates to a post-frame callback.
- **Formatting helpers**: `HiFormat.number`, `HiFormat.compact`, and
  `HiFormat.fileSize` provide locale-independent formatting.
- **Link detection**: `HiLinkDetector.split` breaks text into plain and
  linked `HiTextSegment`s while stripping unpaired trailing punctuation.
- **Color & context extensions**: `HiColor` parses hex strings,
  `HiColorExtension` exposes `toHex`, `onColor`, and `scaleAlpha`, and
  `HiContextExtension` provides fine-grained `MediaQuery` shortcuts.
- **App & device info contract**: `HiDeviceInfoSource`, `HiAppDeviceInfo`
  with `toUserAgent`, and `HiStaticDeviceInfoSource` for tests and previews.

## Usage

```dart
import 'package:hiflutter_core/hiflutter_core.dart';

void main() {
  final formatted = HiFormat.compact(999950); // '1M'
  final color = HiColor.parseHex('#2196F3');
  final onColor = color.onColor;
  final segments = HiLinkDetector.split('Docs: https://dart.dev.');

  const source = HiStaticDeviceInfoSource(
    HiAppDeviceInfo(
      appName: 'DemoApp',
      packageName: 'com.example.demo',
      version: '1.0.0',
      buildNumber: '1',
      deviceModel: 'Pixel 9',
      osName: 'Android',
      osVersion: '15',
    ),
  );
}
```

See `example/main.dart` for a complete runnable example.

## License

MIT
