import 'dart:io';

import 'src/deps_report.dart';

/// Entry point of `dart run tool/deps_report.dart`; see
/// `tool/src/deps_report.dart`.
Future<void> main(List<String> args) async {
  exitCode = await runDepsReport(args);
}
