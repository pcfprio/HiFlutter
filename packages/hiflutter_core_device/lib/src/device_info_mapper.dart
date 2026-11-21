import 'package:device_info_plus/device_info_plus.dart';
import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_core/hiflutter_core.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Maps third-party [PackageInfo] and [BaseDeviceInfo] snapshots into the
/// contract [HiAppDeviceInfo] without exposing plugin types publicly.
HiAppDeviceInfo mapPlatformDeviceInfo(
  PackageInfo packageInfo,
  BaseDeviceInfo deviceInfo,
) {
  final (:deviceModel, :osName, :osVersion) = _extractDeviceFields(deviceInfo);
  final packageName = _firstNonEmpty([packageInfo.packageName]);
  final appName = _firstNonEmpty([
    packageInfo.appName,
    packageInfo.packageName,
  ]);
  final version = _firstNonEmpty([packageInfo.version], fallback: '0.0.0');

  return HiAppDeviceInfo(
    appName: appName,
    packageName: packageName,
    version: version,
    buildNumber: packageInfo.buildNumber.trim(),
    deviceModel: deviceModel,
    osName: osName,
    osVersion: osVersion,
  );
}

({String deviceModel, String osName, String osVersion}) _extractDeviceFields(
  BaseDeviceInfo info,
) {
  return switch (info) {
    AndroidDeviceInfo() => (
      deviceModel: _firstNonEmpty([info.model, info.device, info.brand]),
      osName: 'Android',
      osVersion: _firstNonEmpty([
        info.version.release,
        if (info.version.sdkInt > 0) 'API ${info.version.sdkInt}',
      ]),
    ),
    IosDeviceInfo() => (
      deviceModel: _firstNonEmpty([
        info.modelName,
        info.model,
        info.utsname.machine,
      ]),
      osName: _firstNonEmpty([info.systemName], fallback: 'iOS'),
      osVersion: _firstNonEmpty([info.systemVersion]),
    ),
    MacOsDeviceInfo() => (
      deviceModel: _firstNonEmpty([info.modelName, info.model]),
      osName: 'macOS',
      osVersion: _firstNonEmpty([
        if (info.majorVersion > 0)
          '${info.majorVersion}.${info.minorVersion}.${info.patchVersion}',
        info.osRelease,
      ]),
    ),
    LinuxDeviceInfo() => (
      deviceModel: _firstNonEmpty([
        info.prettyName,
        info.name,
      ], fallback: 'Linux'),
      osName: _firstNonEmpty([info.name], fallback: 'Linux'),
      osVersion: _firstNonEmpty([info.versionId, info.version]),
    ),
    WindowsDeviceInfo() => (
      deviceModel: _firstNonEmpty([
        info.productName,
        info.computerName,
      ], fallback: 'Windows'),
      osName: 'Windows',
      osVersion: _firstNonEmpty([
        if (info.majorVersion > 0)
          '${info.majorVersion}.${info.minorVersion}.${info.buildNumber}',
        info.displayVersion,
        info.releaseId,
      ]),
    ),
    WebBrowserInfo() => (
      deviceModel: _firstNonEmpty([
        if (info.browserName != BrowserName.unknown) info.browserName.name,
        info.platform,
      ], fallback: 'Browser'),
      osName: 'Web',
      osVersion: _firstNonEmpty([info.appVersion]),
    ),
    _ => _fromGenericMap(info.data),
  };
}

({String deviceModel, String osName, String osVersion}) _fromGenericMap(
  Map<String, dynamic> data,
) {
  final map = Map<String, Object?>.from(data);
  final nestedVersion = map.pickMap('version');
  return (
    deviceModel: _firstNonEmpty([
      map['modelName'],
      map['model'],
      map['deviceModel'],
      map['device'],
      map['productName'],
      map['computerName'],
      map['name'],
    ]),
    osName: _firstNonEmpty([
      map['osName'],
      map['systemName'],
      map['platform'],
      map['name'],
      map['id'],
    ]),
    osVersion: _firstNonEmpty([
      map['osVersion'],
      map['systemVersion'],
      map['versionId'],
      map['osRelease'],
      map['release'],
      map['displayVersion'],
      map['appVersion'],
      HiConvert.asString(map['version']),
      nestedVersion?['release'],
    ]),
  );
}

String _firstNonEmpty(
  Iterable<Object?> candidates, {
  String fallback = 'unknown',
}) {
  for (final candidate in candidates) {
    final text = HiConvert.asString(candidate)?.trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return fallback;
}
