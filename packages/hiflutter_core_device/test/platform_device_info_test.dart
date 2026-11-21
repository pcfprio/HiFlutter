import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:device_info_plus_platform_interface/device_info_plus_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_core/hiflutter_core.dart';
import 'package:hiflutter_core_device/hiflutter_core_device.dart';
import 'package:hiflutter_core_device/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:package_info_plus_platform_interface/package_info_data.dart';
import 'package:package_info_plus_platform_interface/package_info_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePackageInfoPlatform extends PackageInfoPlatform
    with MockPlatformInterfaceMixin {
  _FakePackageInfoPlatform({this.data, this.error});

  final PackageInfoData? data;
  final Object? error;

  @override
  Future<PackageInfoData> getAll({String? baseUrl}) async {
    if (error case final failure?) throw failure;
    return data!;
  }
}

class _FakeDeviceInfoPlatform extends DeviceInfoPlatform
    with MockPlatformInterfaceMixin {
  _FakeDeviceInfoPlatform({this.info, this.error});

  final BaseDeviceInfo? info;
  final Object? error;

  @override
  Future<BaseDeviceInfo> deviceInfo() async {
    if (error case final failure?) throw failure;
    return info!;
  }
}

BaseDeviceInfo _hostFakeDeviceInfo() {
  if (Platform.isMacOS) {
    return MacOsDeviceInfo.setMockInitialValues(
      computerName: 'TestMac',
      hostName: 'test.local',
      arch: 'arm64',
      model: 'Mac15,3',
      modelName: 'MacBook Pro (14-inch, 2023)',
      kernelVersion: 'Darwin Kernel 24.1.0',
      osRelease: '24.1.0',
      majorVersion: 15,
      minorVersion: 1,
      patchVersion: 0,
      activeCPUs: 10,
      memorySize: 17179869184,
      cpuFrequency: 3200000000,
      systemGUID: 'guid',
    );
  }
  if (Platform.isLinux) {
    return LinuxDeviceInfo(
      name: 'Ubuntu',
      version: '24.04 LTS',
      id: 'ubuntu',
      versionId: '24.04',
      prettyName: 'Ubuntu 24.04 LTS',
      machineId: 'machine-id',
    );
  }
  if (Platform.isWindows) {
    return WindowsDeviceInfo(
      computerName: 'WIN-TEST',
      numberOfCores: 8,
      systemMemoryInMegabytes: 16384,
      userName: 'tester',
      majorVersion: 10,
      minorVersion: 0,
      buildNumber: 22631,
      platformId: 2,
      csdVersion: '',
      servicePackMajor: 0,
      servicePackMinor: 0,
      suitMask: 256,
      productType: 1,
      reserved: 0,
      buildLab: '22631.ni_release',
      buildLabEx: '22631.1.amd64fre',
      digitalProductId: Uint8List(0),
      displayVersion: '23H2',
      editionId: 'Pro',
      installDate: DateTime(2024),
      productId: '00000',
      productName: 'Windows 11 Pro',
      registeredOwner: 'tester',
      releaseId: '2009',
      deviceId: 'win-device',
    );
  }
  return BaseDeviceInfo({
    'model': 'HostDevice',
    'osName': 'HostOS',
    'osVersion': '1.0',
  });
}

void main() {
  const HiDeviceInfoSource source = HiPlatformDeviceInfoSource();

  group('HiPlatformDeviceInfoSource', () {
    // Keep the package_info failure test first so PackageInfo's static cache
    // remains uninitialized when the happy-path test exercises getAll().
    test('wraps package_info failures in HiError', () async {
      PackageInfoPlatform.instance = _FakePackageInfoPlatform(
        error: PlatformException(code: 'PKG_ERROR', message: 'boom'),
      );
      DeviceInfoPlatform.instance = _FakeDeviceInfoPlatform(
        info: _hostFakeDeviceInfo(),
      );

      await expectLater(source.load(), throwsA(isA<HiUnknownError>()));
    });

    test('loads app and host device info from platform interfaces', () async {
      PackageInfoPlatform.instance = _FakePackageInfoPlatform(
        data: PackageInfoData(
          appName: 'HiDemo',
          packageName: 'com.example.hidemo',
          version: '2.3.4',
          buildNumber: '88',
          buildSignature: '',
        ),
      );
      DeviceInfoPlatform.instance = _FakeDeviceInfoPlatform(
        info: _hostFakeDeviceInfo(),
      );

      final info = await source.load();

      expect(info.appName, 'HiDemo');
      expect(info.packageName, 'com.example.hidemo');
      expect(info.version, '2.3.4');
      expect(info.buildNumber, '88');
      expect(info.deviceModel, isNotEmpty);
      expect(info.osName, isNotEmpty);
      expect(info.osVersion, isNotEmpty);
      expect(info.toUserAgent(), startsWith('HiDemo/2.3.4+88 ('));
    });

    test('wraps device_info failures in HiError', () async {
      PackageInfo.setMockInitialValues(
        appName: 'HiDemo',
        packageName: 'com.example.hidemo',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '',
      );
      DeviceInfoPlatform.instance = _FakeDeviceInfoPlatform(
        error: StateError('device query failed'),
      );

      await expectLater(source.load(), throwsA(isA<HiUnknownError>()));
    });

    test('builds User-Agent without buildNumber when omitted', () async {
      PackageInfo.setMockInitialValues(
        appName: 'HiDemo',
        packageName: 'com.example.hidemo',
        version: '1.0.0',
        buildNumber: '',
        buildSignature: '',
      );
      DeviceInfoPlatform.instance = _FakeDeviceInfoPlatform(
        info: _hostFakeDeviceInfo(),
      );

      final info = await source.load();
      expect(info.buildNumber, isEmpty);
      expect(info.toUserAgent(), startsWith('HiDemo/1.0.0 ('));
      expect(info.toUserAgent(), isNot(contains('+')));
    });
  });

  group('platform device mapping through hiDeviceInfoSourceWithLoader', () {
    final mappedSource = hiDeviceInfoSourceWithLoader(
      () => DeviceInfoPlatform.instance.deviceInfo(),
    );

    void setDefaultPackage() {
      PackageInfo.setMockInitialValues(
        appName: 'Demo',
        packageName: 'com.example.demo',
        version: '1.2.3',
        buildNumber: '45',
        buildSignature: '',
      );
    }

    test('extracts AndroidDeviceInfo model and version', () async {
      setDefaultPackage();
      DeviceInfoPlatform.instance = _FakeDeviceInfoPlatform(
        info: AndroidDeviceInfo.setMockInitialValues(
          version: AndroidBuildVersion.setMockInitialValues(
            codename: 'REL',
            incremental: '1',
            previewSdkInt: 0,
            release: '15',
            sdkInt: 35,
          ),
          board: 'husky',
          bootloader: 'rip',
          brand: 'google',
          device: 'husky',
          display: 'AP3A',
          fingerprint: 'fp',
          hardware: 'husky',
          host: 'host',
          id: 'AP3A',
          manufacturer: 'Google',
          model: 'Pixel 9 Pro',
          product: 'husky',
          name: 'Pixel 9 Pro',
          supported32BitAbis: const [],
          supported64BitAbis: const ['arm64-v8a'],
          supportedAbis: const ['arm64-v8a'],
          tags: 'release-keys',
          time: 0,
          type: 'user',
          isPhysicalDevice: true,
          freeDiskSize: 1000,
          totalDiskSize: 2000,
          systemFeatures: const [],
          isLowRamDevice: false,
          physicalRamSize: 12288,
          availableRamSize: 6144,
        ),
      );

      final result = await mappedSource.load();
      expect(result.deviceModel, 'Pixel 9 Pro');
      expect(result.osName, 'Android');
      expect(result.osVersion, '15');
      expect(result.toUserAgent(), 'Demo/1.2.3+45 (Android 15; Pixel 9 Pro)');
    });

    test('extracts IosDeviceInfo modelName and systemVersion', () async {
      setDefaultPackage();
      DeviceInfoPlatform.instance = _FakeDeviceInfoPlatform(
        info: IosDeviceInfo.setMockInitialValues(
          name: 'My iPhone',
          systemName: 'iOS',
          systemVersion: '18.1',
          model: 'iPhone',
          modelName: 'iPhone 16 Pro',
          localizedModel: 'iPhone',
          freeDiskSize: 1000,
          totalDiskSize: 2000,
          isPhysicalDevice: true,
          isiOSAppOnMac: false,
          isiOSAppOnVision: false,
          physicalRamSize: 8192,
          availableRamSize: 4096,
          utsname: IosUtsname.setMockInitialValues(
            sysname: 'Darwin',
            nodename: 'localhost',
            release: '24.1.0',
            version: 'v1',
            machine: 'iPhone17,1',
          ),
        ),
      );

      final result = await mappedSource.load();
      expect(result.deviceModel, 'iPhone 16 Pro');
      expect(result.osName, 'iOS');
      expect(result.osVersion, '18.1');
      expect(result.toUserAgent(), 'Demo/1.2.3+45 (iOS 18.1; iPhone 16 Pro)');
    });

    test('extracts generic BaseDeviceInfo.data fields', () async {
      setDefaultPackage();
      DeviceInfoPlatform.instance = _FakeDeviceInfoPlatform(
        info: BaseDeviceInfo({
          'model': 'HarmonyDevice',
          'osName': 'OpenHarmony',
          'osVersion': '5.0',
        }),
      );

      final result = await mappedSource.load();
      expect(result.deviceModel, 'HarmonyDevice');
      expect(result.osName, 'OpenHarmony');
      expect(result.osVersion, '5.0');
      expect(
        result.toUserAgent(),
        'Demo/1.2.3+45 (OpenHarmony 5.0; HarmonyDevice)',
      );
    });

    test(
      'falls back cleanly when package or device fields are empty',
      () async {
        PackageInfo.setMockInitialValues(
          appName: '',
          packageName: 'com.example.fallback',
          version: '',
          buildNumber: '',
          buildSignature: '',
        );
        DeviceInfoPlatform.instance = _FakeDeviceInfoPlatform(
          info: BaseDeviceInfo({}),
        );

        final result = await mappedSource.load();
        expect(result.appName, 'com.example.fallback');
        expect(result.packageName, 'com.example.fallback');
        expect(result.version, '0.0.0');
        expect(result.buildNumber, '');
        expect(result.deviceModel, 'unknown');
        expect(result.osName, 'unknown');
        expect(result.osVersion, 'unknown');
        expect(
          result.toUserAgent(),
          'com.example.fallback/0.0.0 (unknown unknown; unknown)',
        );
      },
    );

    test(
      'falls back on Android/iOS when optional subfields are blank',
      () async {
        setDefaultPackage();
        DeviceInfoPlatform.instance = _FakeDeviceInfoPlatform(
          info: AndroidDeviceInfo.setMockInitialValues(
            version: AndroidBuildVersion.setMockInitialValues(
              codename: 'REL',
              incremental: '1',
              previewSdkInt: 0,
              release: '',
              sdkInt: 34,
            ),
            board: '',
            bootloader: '',
            brand: '',
            device: 'emulator',
            display: '',
            fingerprint: '',
            hardware: '',
            host: '',
            id: '',
            manufacturer: '',
            model: '',
            product: '',
            name: '',
            supported32BitAbis: const [],
            supported64BitAbis: const [],
            supportedAbis: const [],
            tags: '',
            time: 0,
            type: '',
            isPhysicalDevice: false,
            freeDiskSize: 0,
            totalDiskSize: 0,
            systemFeatures: const [],
            isLowRamDevice: false,
            physicalRamSize: 0,
            availableRamSize: 0,
          ),
        );

        final result = await mappedSource.load();
        expect(result.deviceModel, 'emulator');
        expect(result.osName, 'Android');
        expect(result.osVersion, 'API 34');

        DeviceInfoPlatform.instance = _FakeDeviceInfoPlatform(
          info: IosDeviceInfo.setMockInitialValues(
            name: '',
            systemName: '',
            systemVersion: '',
            model: '',
            modelName: '',
            localizedModel: '',
            freeDiskSize: 0,
            totalDiskSize: 0,
            isPhysicalDevice: false,
            isiOSAppOnMac: false,
            isiOSAppOnVision: false,
            physicalRamSize: 0,
            availableRamSize: 0,
            utsname: IosUtsname.setMockInitialValues(
              sysname: '',
              nodename: '',
              release: '',
              version: '',
              machine: 'arm64',
            ),
          ),
        );
        final iosFallback = await mappedSource.load();
        expect(iosFallback.deviceModel, 'arm64');
        expect(iosFallback.osName, 'iOS');
        expect(iosFallback.osVersion, 'unknown');
      },
    );

    test('extracts desktop, web, and nested map version fields', () async {
      setDefaultPackage();
      DeviceInfoPlatform.instance = _FakeDeviceInfoPlatform(
        info: MacOsDeviceInfo.setMockInitialValues(
          computerName: 'Mac',
          hostName: 'mac.local',
          arch: 'arm64',
          model: 'Mac15,3',
          modelName: 'MacBook Pro',
          kernelVersion: '24.1',
          osRelease: '24.1.0',
          majorVersion: 15,
          minorVersion: 2,
          patchVersion: 1,
          activeCPUs: 8,
          memorySize: 16,
          cpuFrequency: 3,
          systemGUID: 'id',
        ),
      );
      final mac = await mappedSource.load();
      expect(mac.deviceModel, 'MacBook Pro');
      expect(mac.osName, 'macOS');
      expect(mac.osVersion, '15.2.1');

      DeviceInfoPlatform.instance = _FakeDeviceInfoPlatform(
        info: LinuxDeviceInfo(
          name: 'Ubuntu',
          version: '24.04 LTS',
          id: 'ubuntu',
          versionId: '24.04',
          prettyName: 'Ubuntu 24.04 LTS',
          machineId: 'mid',
        ),
      );
      final linux = await mappedSource.load();
      expect(linux.deviceModel, 'Ubuntu 24.04 LTS');
      expect(linux.osName, 'Ubuntu');
      expect(linux.osVersion, '24.04');

      DeviceInfoPlatform.instance = _FakeDeviceInfoPlatform(
        info: WebBrowserInfo(
          appCodeName: 'Mozilla',
          appName: 'Netscape',
          appVersion: '5.0',
          deviceMemory: 8,
          language: 'en-US',
          languages: const ['en-US'],
          platform: 'MacIntel',
          product: 'Gecko',
          productSub: '20100101',
          userAgent: 'Mozilla/5.0 Chrome/130.0.0.0 Safari/537.36',
          vendor: 'Google Inc.',
          vendorSub: '',
          maxTouchPoints: 0,
          hardwareConcurrency: 8,
        ),
      );
      final web = await mappedSource.load();
      expect(web.deviceModel, 'chrome');
      expect(web.osName, 'Web');
      expect(web.osVersion, '5.0');

      DeviceInfoPlatform.instance = _FakeDeviceInfoPlatform(
        info: BaseDeviceInfo({
          'deviceModel': 'CustomBox',
          'platform': 'Embedded',
          'version': {'release': '3.1'},
        }),
      );
      final nested = await mappedSource.load();
      expect(nested.deviceModel, 'CustomBox');
      expect(nested.osName, 'Embedded');
      expect(nested.osVersion, '3.1');
    });
  });
}
