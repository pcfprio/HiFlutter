import 'dart:io';

import 'package:path/path.dart' as p;

import '../stage.dart';
import '../workspace.dart';

/// Resolves the workspace and runs `flutter analyze` over all of it.
class AnalyzeStage implements CheckStage {
  @override
  String get id => 'analyze';

  @override
  String get title => 'flutter pub get + flutter analyze';

  @override
  Future<StageResult> run(CheckContext context) async {
    if (await context.exec('flutter', ['pub', 'get']) != 0) {
      return StageResult.fail(['`flutter pub get` failed']);
    }
    return await context.exec('flutter', ['analyze']) == 0
        ? const StageResult.pass()
        : StageResult.fail(['`flutter analyze` reported issues']);
  }
}

/// Runs every package's tests, plus the workspace root's own tool tests.
class TestStage implements CheckStage {
  @override
  String get id => 'test';

  @override
  String get title => 'tests of every package';

  @override
  Future<StageResult> run(CheckContext context) async {
    final problems = <String>[];
    if (Directory(p.join(context.root, 'test')).existsSync() &&
        await context.exec('dart', ['test']) != 0) {
      problems.add('workspace root tests failed');
    }
    for (final pkg in loadWorkspace(context.root)) {
      if (!Directory(p.join(pkg.dir, 'test')).existsSync()) continue;
      final tool = pkg.isFlutter ? 'flutter' : 'dart';
      if (await context.exec(tool, ['test'], workingDirectory: pkg.dir) != 0) {
        problems.add('${pkg.name} tests failed');
      }
    }
    return StageResult.of(problems);
  }
}

/// Runs `pub publish --dry-run` for every publishable package.
class PublishStage implements CheckStage {
  @override
  String get id => 'publish';

  @override
  String get title => 'pub publish --dry-run of every package';

  @override
  Future<StageResult> run(CheckContext context) async {
    final problems = <String>[];
    for (final pkg in loadWorkspace(context.root)) {
      if (!pkg.publishable) continue;
      final tool = pkg.isFlutter ? 'flutter' : 'dart';
      if (await context.exec(tool, [
            'pub',
            'publish',
            '--dry-run',
          ], workingDirectory: pkg.dir) !=
          0) {
        problems.add('${pkg.name}: publish dry-run reported problems');
      }
    }
    return StageResult.of(problems);
  }
}
