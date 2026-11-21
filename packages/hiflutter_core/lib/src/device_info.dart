/// Application and device metadata returned by [HiDeviceInfoSource].
final class HiAppDeviceInfo {
  /// Creates an application and device info snapshot.
  const HiAppDeviceInfo({
    required this.appName,
    required this.packageName,
    required this.version,
    this.buildNumber = '',
    required this.deviceModel,
    required this.osName,
    required this.osVersion,
  });

  /// Human-readable application name.
  final String appName;

  /// Platform package or bundle identifier (such as `com.example.app`).
  final String packageName;

  /// Semantic application version string (such as `1.2.3`).
  final String version;

  /// Platform build number or version code; empty when unavailable.
  final String buildNumber;

  /// Hardware or simulator model name (such as `Pixel 9` or `iPhone 16`).
  final String deviceModel;

  /// Operating system name (such as `Android`, `iOS`, `macOS`, or `Web`).
  final String osName;

  /// Operating system version string (such as `15` or `18.1`).
  final String osVersion;

  /// Formats a standard User-Agent header string:
  /// `<product ?? appName>/<version>+<buildNumber> (<osName> <osVersion>; <deviceModel>)`.
  ///
  /// When [buildNumber] is empty, `+<buildNumber>` is omitted.
  String toUserAgent({String? product}) {
    final name = product ?? appName;
    final versionTag = buildNumber.isEmpty ? version : '$version+$buildNumber';
    final os = [osName, osVersion].where((s) => s.isNotEmpty).join(' ');
    final details = [
      if (os.isNotEmpty) os,
      if (deviceModel.isNotEmpty) deviceModel,
    ].join('; ');
    return details.isEmpty
        ? '$name/$versionTag'
        : '$name/$versionTag ($details)';
  }

  @override
  bool operator ==(Object other) =>
      other is HiAppDeviceInfo &&
      other.appName == appName &&
      other.packageName == packageName &&
      other.version == version &&
      other.buildNumber == buildNumber &&
      other.deviceModel == deviceModel &&
      other.osName == osName &&
      other.osVersion == osVersion;

  @override
  int get hashCode => Object.hash(
    appName,
    packageName,
    version,
    buildNumber,
    deviceModel,
    osName,
    osVersion,
  );

  @override
  String toString() =>
      'HiAppDeviceInfo(appName: $appName, packageName: $packageName, '
      'version: $version, buildNumber: $buildNumber, '
      'deviceModel: $deviceModel, osName: $osName, osVersion: $osVersion)';
}

/// Contract for loading [HiAppDeviceInfo] from the runtime environment.
abstract interface class HiDeviceInfoSource {
  /// Loads the current application and device metadata.
  Future<HiAppDeviceInfo> load();
}

/// A [HiDeviceInfoSource] that always returns a fixed [HiAppDeviceInfo],
/// useful for tests, previews, and deterministic fixtures.
final class HiStaticDeviceInfoSource implements HiDeviceInfoSource {
  /// Creates a static source returning [info].
  const HiStaticDeviceInfoSource(this.info);

  /// The static snapshot returned by [load].
  final HiAppDeviceInfo info;

  @override
  Future<HiAppDeviceInfo> load() async => info;
}
