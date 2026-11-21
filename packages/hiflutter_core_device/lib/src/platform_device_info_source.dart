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
  Future<HiAppDeviceInfo> load() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final deviceInfo = await DeviceInfoPlugin().deviceInfo;
      return mapPlatformDeviceInfo(packageInfo, deviceInfo);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(HiError.from(error, stackTrace), stackTrace);
    }
  }
}
