import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_base_log_file/hiflutter_base_log_file.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

final class FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  FakePathProvider(this.supportPath);

  final String supportPath;

  @override
  Future<String?> getApplicationSupportPath() async => supportPath;
}

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('hi_log_support_test_');
    PathProviderPlatform.instance = FakePathProvider(dir.path);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('writes into a logs folder of the application support directory', () async {
    final sink = await HiFileLogSink.inApplicationSupport(
      now: () => DateTime(2026, 11, 21),
    );
    HiLogger([HiLogRoute(sink)]).info(() => 'hello');
    sink.close();

    final files = await sink.logFiles();
    expect(files.single.path, '${dir.path}/logs/hiflutter-2026-11-21.log');
    expect(files.single.readAsStringSync(), contains('INFO hello'));
  });

  test('passes the folder name and limits through', () async {
    final sink = await HiFileLogSink.inApplicationSupport(
      folder: 'diagnostics',
      maxFileBytes: 1024,
      retentionDays: 3,
    );
    expect(sink.directory.path, '${dir.path}/diagnostics');
    expect(sink.maxFileBytes, 1024);
    expect(sink.retentionDays, 3);
  });
}
