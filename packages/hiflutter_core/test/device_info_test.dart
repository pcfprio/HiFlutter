import 'package:flutter_test/flutter_test.dart';
import 'package:hiflutter_core/hiflutter_core.dart';

void main() {
  group('HiAppDeviceInfo', () {
    const info = HiAppDeviceInfo(
      appName: 'DemoApp',
      packageName: 'com.example.demo',
      version: '1.2.3',
      buildNumber: '45',
      deviceModel: 'Pixel 9',
      osName: 'Android',
      osVersion: '15',
    );

    test('builds User-Agent with buildNumber and default product', () {
      expect(info.toUserAgent(), 'DemoApp/1.2.3+45 (Android 15; Pixel 9)');
    });

    test('overrides product name in User-Agent when provided', () {
      expect(
        info.toUserAgent(product: 'DemoClient'),
        'DemoClient/1.2.3+45 (Android 15; Pixel 9)',
      );
    });

    test('omits +buildNumber when buildNumber is empty', () {
      const withoutBuild = HiAppDeviceInfo(
        appName: 'DemoApp',
        packageName: 'com.example.demo',
        version: '1.2.3',
        deviceModel: 'iPhone 16',
        osName: 'iOS',
        osVersion: '18.0',
      );
      expect(withoutBuild.toUserAgent(), 'DemoApp/1.2.3 (iOS 18.0; iPhone 16)');
    });

    test(
      'handles empty optional OS or device fields cleanly in User-Agent',
      () {
        const partial = HiAppDeviceInfo(
          appName: 'DemoApp',
          packageName: 'com.example.demo',
          version: '1.0.0',
          buildNumber: '',
          deviceModel: 'Chrome',
          osName: 'Web',
          osVersion: '',
        );
        expect(partial.toUserAgent(), 'DemoApp/1.0.0 (Web; Chrome)');
      },
    );

    test('supports value equality', () {
      const copy = HiAppDeviceInfo(
        appName: 'DemoApp',
        packageName: 'com.example.demo',
        version: '1.2.3',
        buildNumber: '45',
        deviceModel: 'Pixel 9',
        osName: 'Android',
        osVersion: '15',
      );
      expect(info, equals(copy));
      expect(info.hashCode, equals(copy.hashCode));
    });
  });

  group('HiStaticDeviceInfoSource', () {
    test('returns the injected HiAppDeviceInfo', () async {
      const expected = HiAppDeviceInfo(
        appName: 'Preview',
        packageName: 'com.example.preview',
        version: '0.1.0',
        buildNumber: '1',
        deviceModel: 'Simulator',
        osName: 'iOS',
        osVersion: '18.2',
      );
      const HiDeviceInfoSource source = HiStaticDeviceInfoSource(expected);

      expect(await source.load(), equals(expected));
    });
  });
}
