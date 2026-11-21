import 'dart:io';

import 'package:path/path.dart' as p;

import '../stage.dart';

/// Runs Android debug and macOS iOS simulator smoke builds for `apps/showcase`.
class BuildStage implements CheckStage {
  @override
  String get id => 'build';

  @override
  String get title => 'showcase app smoke build';

  @override
  Future<StageResult> run(CheckContext context) async {
    final showcaseDir = p.join(context.root, 'apps', 'showcase');
    if (!File(p.join(showcaseDir, 'pubspec.yaml')).existsSync()) {
      return StageResult.fail(['Missing showcase app at apps/showcase.']);
    }

    final problems = <String>[];
    if (await context.exec('flutter', [
          'build',
          'apk',
          '--debug',
        ], workingDirectory: showcaseDir) !=
        0) {
      problems.add('apps/showcase: `flutter build apk --debug` failed.');
    }

    if (Platform.isMacOS) {
      if (await context.exec('flutter', [
            'build',
            'ios',
            '--simulator',
            '--no-codesign',
          ], workingDirectory: showcaseDir) !=
          0) {
        problems.add(
          'apps/showcase: `flutter build ios --simulator --no-codesign` '
          'failed.',
        );
      }
    } else {
      context.out.writeln(
        '    Skipping iOS simulator smoke build (macOS host required).',
      );
    }

    return StageResult.of(problems);
  }
}
