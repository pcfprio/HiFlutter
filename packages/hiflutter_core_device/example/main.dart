// The example prints its results to the console.
// ignore_for_file: avoid_print

import 'package:flutter/widgets.dart';
import 'package:hiflutter_core/hiflutter_core.dart';
import 'package:hiflutter_core_device/hiflutter_core_device.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const HiDeviceInfoSource source = HiPlatformDeviceInfoSource();
  final info = await source.load();

  print('App: ${info.appName} (${info.packageName})');
  print('Version: ${info.version}+${info.buildNumber}');
  print('Device: ${info.osName} ${info.osVersion} / ${info.deviceModel}');
  print('User-Agent: ${info.toUserAgent()}');
}
