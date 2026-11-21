import 'dart:io';

import 'package:hiflutter_tool/hiflutter_tool.dart';

/// CLI entry point for the `hiflutter` executable.
Future<void> main(List<String> args) async {
  exitCode = await HiToolRunner().run(args);
}
