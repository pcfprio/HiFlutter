// The example prints its results to the console.
// ignore_for_file: avoid_print

import 'package:hiflutter_core/hiflutter_core.dart';

Future<void> main() async {
  // Formatting numbers, compact counts, and file sizes.
  print(HiFormat.number(1234567.89, fractionDigits: 2));
  print(HiFormat.compact(999950));
  print(HiFormat.fileSize(1536));

  // Splitting text into plain and linked segments.
  for (final segment in HiLinkDetector.split('Visit (https://dart.dev).')) {
    print('${segment.isLink ? 'LINK' : 'TEXT'}: ${segment.text}');
  }

  // Color parsing and contrast helpers.
  final primary = HiColor.parseHex('#2196F3');
  print('Primary: ${primary.toHex()}, onColor: ${primary.onColor.toHex()}');

  // Static device info for previews and tests.
  const source = HiStaticDeviceInfoSource(
    HiAppDeviceInfo(
      appName: 'DemoApp',
      packageName: 'com.example.demo',
      version: '1.0.0',
      buildNumber: '42',
      deviceModel: 'Pixel 9',
      osName: 'Android',
      osVersion: '15',
    ),
  );
  final info = await source.load();
  print(info.toUserAgent());
}
