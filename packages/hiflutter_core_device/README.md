# hiflutter_core_device

[device_info_plus](https://pub.dev/packages/device_info_plus) and
[package_info_plus](https://pub.dev/packages/package_info_plus)
implementation of the `HiDeviceInfoSource` contract from `hiflutter_core`,
part of [HiFlutter](https://github.com/pcfprio/HiFlutter).

## Features

- Implements `HiDeviceInfoSource` via `HiPlatformDeviceInfoSource`,
  combining `PackageInfo.fromPlatform()` and `DeviceInfoPlugin().deviceInfo`.
- Reads device model and OS version across Android, iOS, desktop, web, and
  generic `BaseDeviceInfo.data` payloads with safe fallbacks for missing
  fields.
- Keeps all third-party plugin types internal and wraps platform errors into
  `HiError`.

## Usage

```dart
import 'package:hiflutter_core/hiflutter_core.dart';
import 'package:hiflutter_core_device/hiflutter_core_device.dart';

Future<void> main() async {
  const HiDeviceInfoSource source = HiPlatformDeviceInfoSource();
  final info = await source.load();
  final userAgent = info.toUserAgent();
}
```

See `example/main.dart` for a complete runnable example.

## License

MIT
