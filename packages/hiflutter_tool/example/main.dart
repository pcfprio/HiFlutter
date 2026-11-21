import 'dart:io';

import 'package:hiflutter_tool/hiflutter_tool.dart';

/// Demonstrates running `hiflutter` commands programmatically via [HiToolRunner].
Future<void> main(List<String> args) async {
  final runner = HiToolRunner();
  exitCode = await runner.run(args.isEmpty ? ['--help'] : args);
}
