import 'dart:io';

import 'src/check.dart';

/// Entry point of `dart run tool/check.dart`; see `tool/src/check.dart`.
Future<void> main(List<String> args) async {
  exitCode = await runCheck(args);
}
