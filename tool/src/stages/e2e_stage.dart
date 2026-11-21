import 'dart:io';

import 'package:path/path.dart' as p;

import '../stage.dart';
import '../workspace.dart';

/// Rehearses consumer integration modes (`source` and `pin`) end-to-end
/// against a temporary git clone of this workspace.
class E2eStage implements CheckStage {
  @override
  String get id => 'e2e';

  @override
  String get title => 'end-to-end integration mode rehearsal';

  @override
  Future<StageResult> run(CheckContext context) async {
    final members = {
      for (final pkg in loadWorkspace(context.root)) pkg.name: pkg,
    };
    final netPkg = members['hiflutter_net'];
    if (netPkg == null || netPkg.version == null) {
      return StageResult.fail([
        'Workspace lacks publishable hiflutter_net package for e2e rehearsal.',
      ]);
    }
    final toolPkg = members['hiflutter_tool'];
    if (toolPkg == null) {
      return StageResult.fail([
        'Workspace lacks hiflutter_tool package for e2e rehearsal.',
      ]);
    }

    final version = netPkg.version!;
    final e2eTag = 'v$version-e2e';
    final toolBin = p.join(toolPkg.dir, 'bin', 'hiflutter.dart');
    final packageConfig = p.join(
      context.root,
      '.dart_tool',
      'package_config.json',
    );
    if (!File(toolBin).existsSync()) {
      return StageResult.fail(['Missing hiflutter binary script at $toolBin.']);
    }

    final tmpDir = await Directory.systemTemp.createTemp('hiflutter_e2e_');
    try {
      final hiFlutterDir = p.join(tmpDir.path, 'HiFlutter');
      final consumerDir = p.join(tmpDir.path, 'consumer');

      if (await context.exec('git', [
            'clone',
            '--quiet',
            context.root,
            hiFlutterDir,
          ], workingDirectory: tmpDir.path) !=
          0) {
        return StageResult.fail([
          'Failed to clone workspace for e2e rehearsal.',
        ]);
      }

      for (final gitArgs in [
        ['config', 'user.name', 'HiFlutter E2E'],
        ['config', 'user.email', 'e2e@hiflutter.local'],
        ['tag', '-a', e2eTag, '-m', 'e2e'],
      ]) {
        if (await context.exec(
              'git',
              gitArgs,
              workingDirectory: hiFlutterDir,
            ) !=
            0) {
          return StageResult.fail([
            'Failed running `git ${gitArgs.join(' ')}` in temporary clone.',
          ]);
        }
      }

      _createConsumerProject(consumerDir, version);

      Future<int> runTool(List<String> args) => _execTool(
        context,
        consumerDir: consumerDir,
        toolBin: toolBin,
        packageConfig: packageConfig,
        args: args,
      );

      // 1. Source mode (defaults to sibling ../HiFlutter).
      if (await runTool(['mode', 'source']) != 0) {
        return StageResult.fail(['`hiflutter mode source` failed.']);
      }
      if (await context.exec('dart', [
            'pub',
            'get',
          ], workingDirectory: consumerDir) !=
          0) {
        return StageResult.fail(['`dart pub get` failed in source mode.']);
      }
      if (await context.exec('dart', [
            'analyze',
          ], workingDirectory: consumerDir) !=
          0) {
        return StageResult.fail(['`dart analyze` failed in source mode.']);
      }
      if (await runTool(['check']) != 0) {
        return StageResult.fail(['`hiflutter check` failed in source mode.']);
      }
      if (await runTool(['check', '--release']) == 0) {
        return StageResult.fail([
          '`hiflutter check --release` unexpectedly succeeded in source mode.',
        ]);
      }

      // 2. Pinned git tag mode.
      if (await runTool(['mode', 'pin', e2eTag, '--git-url', hiFlutterDir]) !=
          0) {
        return StageResult.fail(['`hiflutter mode pin` failed.']);
      }
      if (await context.exec('dart', [
            'pub',
            'get',
          ], workingDirectory: consumerDir) !=
          0) {
        return StageResult.fail(['`dart pub get` failed in pin mode.']);
      }
      if (await context.exec('dart', [
            'analyze',
          ], workingDirectory: consumerDir) !=
          0) {
        return StageResult.fail(['`dart analyze` failed in pin mode.']);
      }
      if (await runTool(['check', '--release']) != 0) {
        return StageResult.fail([
          '`hiflutter check --release` failed in pin mode.',
        ]);
      }

      return const StageResult.pass();
    } finally {
      if (tmpDir.existsSync()) {
        tmpDir.deleteSync(recursive: true);
      }
    }
  }

  void _createConsumerProject(String consumerDir, String netVersion) {
    Directory(p.join(consumerDir, 'lib')).createSync(recursive: true);
    File(p.join(consumerDir, 'pubspec.yaml')).writeAsStringSync('''
name: e2e_consumer
version: 1.0.0
publish_to: none

environment:
  sdk: ^3.14.0

dependencies:
  hiflutter_net: ^$netVersion
''');
    File(p.join(consumerDir, 'lib', 'main.dart')).writeAsStringSync('''
import 'package:hiflutter_net/hiflutter_net.dart';

/// Verifies that [HiHttpClient] resolves in the consumer project.
Type consumerProbe() => HiHttpClient;
''');
  }

  Future<int> _execTool(
    CheckContext context, {
    required String consumerDir,
    required String toolBin,
    required String packageConfig,
    required List<String> args,
  }) {
    if (File(packageConfig).existsSync()) {
      return context.exec('dart', [
        '--packages=$packageConfig',
        toolBin,
        ...args,
      ], workingDirectory: consumerDir);
    }
    return context.exec('dart', [
      'run',
      toolBin,
      ...args,
      '--project-dir',
      consumerDir,
    ], workingDirectory: context.root);
  }
}
