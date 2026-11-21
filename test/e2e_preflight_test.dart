import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/stage.dart';
import '../tool/src/stages/e2e_stage.dart';
import 'support/fixture_repo.dart';

class _ExecCall {
  _ExecCall(this.executable, this.arguments, this.workingDirectory);

  final String executable;
  final List<String> arguments;
  final String? workingDirectory;
}

class _RecordingContext extends CheckContext {
  _RecordingContext({
    required super.root,
    required super.out,
    required this.onExec,
  });

  final Future<int> Function(_ExecCall call) onExec;
  final List<_ExecCall> calls = [];

  @override
  Future<int> exec(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) {
    final call = _ExecCall(executable, arguments, workingDirectory);
    calls.add(call);
    return onExec(call);
  }
}

void main() {
  group('isPackageConfigured', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('e2e_preflight_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('returns false when package_config.json does not exist', () {
      final path = p.join(tempDir.path, '.dart_tool', 'package_config.json');

      expect(isPackageConfigured(path, 'hiflutter_tool'), isFalse);
    });

    test('returns false when package_config.json has malformed JSON', () {
      final file = File(p.join(tempDir.path, 'package_config.json'))
        ..writeAsStringSync('{not valid json');

      expect(isPackageConfigured(file.path, 'hiflutter_tool'), isFalse);
    });

    test('returns false when JSON lacks a valid packages list', () {
      final listFile = File(p.join(tempDir.path, 'list.json'))
        ..writeAsStringSync('[]');
      final missingPackagesFile = File(p.join(tempDir.path, 'missing.json'))
        ..writeAsStringSync(jsonEncode({'configVersion': 2}));
      final badPackagesFile = File(p.join(tempDir.path, 'bad_packages.json'))
        ..writeAsStringSync(jsonEncode({'packages': 'not-a-list'}));

      expect(isPackageConfigured(listFile.path, 'hiflutter_tool'), isFalse);
      expect(
        isPackageConfigured(missingPackagesFile.path, 'hiflutter_tool'),
        isFalse,
      );
      expect(
        isPackageConfigured(badPackagesFile.path, 'hiflutter_tool'),
        isFalse,
      );
    });

    test('returns false when package_config.json omits the target package', () {
      final file = File(p.join(tempDir.path, 'package_config.json'))
        ..writeAsStringSync(
          jsonEncode({
            'configVersion': 2,
            'packages': [
              'unexpected-string-entry',
              {'rootUri': '../'},
              {
                'name': 'hiflutter_base',
                'rootUri': '../packages/hiflutter_base',
              },
              {'name': 'hiflutter_net', 'rootUri': '../packages/hiflutter_net'},
            ],
          }),
        );

      expect(isPackageConfigured(file.path, 'hiflutter_tool'), isFalse);
    });

    test('returns true when package_config.json lists the target package', () {
      final file = File(p.join(tempDir.path, 'package_config.json'))
        ..writeAsStringSync(
          jsonEncode({
            'configVersion': 2,
            'packages': [
              {
                'name': 'hiflutter_base',
                'rootUri': '../packages/hiflutter_base',
              },
              {
                'name': 'hiflutter_tool',
                'rootUri': '../packages/hiflutter_tool',
              },
            ],
          }),
        );

      expect(isPackageConfigured(file.path, 'hiflutter_tool'), isTrue);
    });
  });

  group('E2eStage preflight', () {
    late FixtureRepo repo;

    tearDown(() => repo.dispose());

    test(
      'runs dart pub get before rehearsal when package_config.json is missing',
      () async {
        repo = await FixtureRepo.create(
          packages: ['hiflutter_base', 'hiflutter_net', 'hiflutter_tool'],
        );
        repo.write(
          'packages/hiflutter_tool/bin/hiflutter.dart',
          'void main() {}\n',
        );

        final context = _RecordingContext(
          root: repo.root,
          out: StringBuffer(),
          onExec: (call) async => call.executable == 'dart' ? 0 : 1,
        );

        await E2eStage().run(context);

        expect(context.calls, hasLength(2));
        expect(context.calls.first.executable, 'dart');
        expect(context.calls.first.arguments, ['pub', 'get']);
        expect(context.calls.first.workingDirectory ?? repo.root, repo.root);
        expect(context.calls[1].executable, 'git');
        expect(context.calls[1].arguments.first, 'clone');
      },
    );

    test('runs flutter pub get when a workspace member depends on Flutter and '
        'package_config.json omits hiflutter_tool', () async {
      repo = await FixtureRepo.create(
        packages: ['hiflutter_core', 'hiflutter_net', 'hiflutter_tool'],
      );
      repo.addPackage(
        'hiflutter_core',
        dependencies: {'flutter': '\n    sdk: flutter'},
      );
      repo.write(
        'packages/hiflutter_tool/bin/hiflutter.dart',
        'void main() {}\n',
      );
      repo.write(
        '.dart_tool/package_config.json',
        jsonEncode({
          'configVersion': 2,
          'packages': [
            {'name': 'hiflutter_net', 'rootUri': '../packages/hiflutter_net'},
          ],
        }),
      );

      final context = _RecordingContext(
        root: repo.root,
        out: StringBuffer(),
        onExec: (call) async => call.executable == 'flutter' ? 0 : 1,
      );

      await E2eStage().run(context);

      expect(context.calls, hasLength(2));
      expect(context.calls.first.executable, 'flutter');
      expect(context.calls.first.arguments, ['pub', 'get']);
      expect(context.calls.first.workingDirectory ?? repo.root, repo.root);
      expect(context.calls[1].executable, 'git');
      expect(context.calls[1].arguments.first, 'clone');
    });

    test(
      'returns StageResult.fail immediately when preflight pub get fails',
      () async {
        repo = await FixtureRepo.create(
          packages: ['hiflutter_net', 'hiflutter_tool'],
        );
        repo.write(
          'packages/hiflutter_tool/bin/hiflutter.dart',
          'void main() {}\n',
        );
        repo.write('.dart_tool/package_config.json', '{corrupt json');

        final context = _RecordingContext(
          root: repo.root,
          out: StringBuffer(),
          onExec: (_) async => 1,
        );

        final result = await E2eStage().run(context);

        expect(result.passed, isFalse);
        expect(result.problems, isNotEmpty);
        expect(result.problems.single, contains('dart pub get'));
        expect(context.calls, hasLength(1));
        expect(context.calls.single.executable, 'dart');
        expect(context.calls.single.arguments, ['pub', 'get']);
      },
    );

    test(
      'skips preflight pub get when hiflutter_tool is already configured',
      () async {
        repo = await FixtureRepo.create(
          packages: ['hiflutter_net', 'hiflutter_tool'],
        );
        repo.write(
          'packages/hiflutter_tool/bin/hiflutter.dart',
          'void main() {}\n',
        );
        repo.write(
          '.dart_tool/package_config.json',
          jsonEncode({
            'configVersion': 2,
            'packages': [
              {'name': 'hiflutter_net', 'rootUri': '../packages/hiflutter_net'},
              {
                'name': 'hiflutter_tool',
                'rootUri': '../packages/hiflutter_tool',
              },
            ],
          }),
        );

        final context = _RecordingContext(
          root: repo.root,
          out: StringBuffer(),
          onExec: (_) async => 1,
        );

        await E2eStage().run(context);

        expect(context.calls, hasLength(1));
        expect(context.calls.single.executable, 'git');
        expect(context.calls.single.arguments.first, 'clone');
      },
    );
  });
}
