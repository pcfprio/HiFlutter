import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'stage.dart';
import 'stages.dart';

/// Runs the HiFlutter repository check and returns a process exit code.
///
/// Options:
/// - `--root <dir>`: workspace to check (defaults to this repository).
/// - `--only <id,...>`: run just the named stages, in their normal order.
Future<int> runCheck(
  List<String> args, {
  StringSink? out,
  List<CheckStage>? stages,
}) async {
  final sink = out ?? stdout;
  final parser = ArgParser()
    ..addOption('root', help: 'Workspace root to check.')
    ..addMultiOption('only', help: 'Run only these stage ids.')
    ..addFlag('help', abbr: 'h', negatable: false);
  final all = stages ?? defaultStages();

  final ArgResults options;
  try {
    options = parser.parse(args);
  } on FormatException catch (e) {
    sink.writeln('${e.message}\n\nUsage: dart run tool/check.dart [options]');
    sink.writeln(parser.usage);
    return 64;
  }
  if (options.flag('help')) {
    sink.writeln('Usage: dart run tool/check.dart [options]');
    sink.writeln(parser.usage);
    sink.writeln('\nStages: ${all.map((s) => s.id).join(', ')}');
    return 0;
  }

  final only = options.multiOption('only');
  final unknown = only.where((id) => !all.any((s) => s.id == id)).toList();
  if (unknown.isNotEmpty) {
    sink.writeln('Unknown stage(s): ${unknown.join(', ')}');
    sink.writeln('Stages: ${all.map((s) => s.id).join(', ')}');
    return 64;
  }
  final selected = only.isEmpty
      ? all
      : all.where((s) => only.contains(s.id)).toList();

  final root = p.normalize(
    p.absolute(options.option('root') ?? _defaultRoot()),
  );
  final context = CheckContext(root: root, out: sink);

  for (final (index, stage) in selected.indexed) {
    sink.writeln(
      '==> [${index + 1}/${selected.length}] ${stage.id}: '
      '${stage.title}',
    );
    final watch = Stopwatch()..start();
    final result = await stage.run(context);
    final elapsed = '${(watch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s';
    if (!result.passed) {
      sink.writeln('    FAIL ${stage.id} ($elapsed)');
      for (final problem in result.problems) {
        sink.writeln('      - $problem');
      }
      return 1;
    }
    sink.writeln('    PASS ${stage.id} ($elapsed)');
  }
  sink.writeln('All ${selected.length} stage(s) passed.');
  return 0;
}

/// The repository containing this script (`tool/..`).
String _defaultRoot() => p.dirname(p.dirname(p.fromUri(Platform.script)));
