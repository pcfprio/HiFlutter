import 'package:device_info_plus/device_info_plus.dart';
import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_core/hiflutter_core.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'device_info_mapper.dart';

/// [HiDeviceInfoSource] backed by `package_info_plus` and `device_info_plus`.
///
/// Third-party plugin types never leak through the public API; any platform
/// failure is normalized into a [HiError] via [HiError.from].
final class HiPlatformDeviceInfoSource implements HiDeviceInfoSource {
  /// Creates a platform device info source.
  const HiPlatformDeviceInfoSource();

  @override
  Future<HiAppDeviceInfo> load() =>
      _loadWith(() => DeviceInfoPlugin().deviceInfo);
}

Future<HiAppDeviceInfo> _loadWith(
  Future<BaseDeviceInfo> Function() loadDeviceInfo,
) async {
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    final deviceInfo = await loadDeviceInfo();
    return mapPlatformDeviceInfo(packageInfo, deviceInfo);
  } catch (error, stackTrace) {
    Error.throwWithStackTrace(HiError.from(error, stackTrace), stackTrace);
  }
}

final class _CustomPlatformDeviceInfoSource implements HiDeviceInfoSource {
  const _CustomPlatformDeviceInfoSource(this._loadDeviceInfo);

  final Future<BaseDeviceInfo> Function() _loadDeviceInfo;

  @override
  Future<HiAppDeviceInfo> load() => _loadWith(_loadDeviceInfo);
}

/// Creates a [HiDeviceInfoSource] backed by `PackageInfo.fromPlatform()` and a
/// custom [loadDeviceInfo] callback for cross-platform adapter tests.
///
/// Exposed exclusively from `package:hiflutter_core_device/testing.dart` so
/// `package:hiflutter_core_device/hiflutter_core_device.dart` never leaks
/// `device_info_plus` types.
HiDeviceInfoSource hiDeviceInfoSourceWithLoader(
  Future<BaseDeviceInfo> Function() loadDeviceInfo,
) => _CustomPlatformDeviceInfoSource(loadDeviceInfo);
