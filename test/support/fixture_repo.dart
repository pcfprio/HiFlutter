import 'dart:io';

import 'package:path/path.dart' as p;

import '../../tool/src/bump_version.dart';
import '../../tool/src/check.dart';
import '../../tool/src/stages/terms_stage.dart';

/// The real repository's business-term blacklist (tests run from its root).
List<String> businessTerms() => readBusinessTerms(Directory.current.path);

/// A throwaway HiFlutter-shaped workspace in a temp directory, used to drive
/// `tool/check.dart` stages against known-good and known-bad inputs.
class FixtureRepo {
  FixtureRepo._(this.root);

  /// Absolute path of the fixture workspace root.
  final String root;

  /// Creates a clean workspace containing the given packages, each at
  /// [version] with a matching CHANGELOG header.
  static Future<FixtureRepo> create({
    List<String> packages = const ['hiflutter_base'],
    String version = '0.1.0',
  }) async {
    final dir = await Directory.systemTemp.createTemp('hiflutter_fixture_');
    final repo = FixtureRepo._(dir.path);
    repo.write('pubspec.yaml', '''
name: fixture_workspace
publish_to: none
environment:
  sdk: ^3.14.0
workspace:
${packages.map((name) => '  - packages/$name').join('\n')}
''');
    repo.write(businessTermsPath, File(businessTermsPath).readAsStringSync());
    for (final name in packages) {
      repo.addPackage(name, version: version);
    }
    return repo;
  }

  /// Adds (or overwrites) a publishable package under `packages/[name]`.
  void addPackage(
    String name, {
    String version = '0.1.0',
    Map<String, String> dependencies = const {},
    String? changelog,
  }) {
    final deps = dependencies.isEmpty
        ? ''
        : 'dependencies:\n${dependencies.entries.map((e) => '  ${e.key}: ${e.value}').join('\n')}\n';
    write('packages/$name/pubspec.yaml', '''
name: $name
description: Fixture package $name used by the check command tests.
version: $version
environment:
  sdk: ^3.14.0
resolution: workspace
$deps''');
    write(
      'packages/$name/CHANGELOG.md',
      changelog ?? '## $version\n\n- Fixture.\n',
    );
    write('packages/$name/lib/$name.dart', 'int answer() => 42;\n');
  }

  /// Writes [contents] to [relativePath], creating parent directories.
  void write(String relativePath, String contents) {
    final file = File(p.join(root, relativePath));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(contents);
  }

  /// Runs the check command against this fixture with extra [args].
  Future<CheckRun> check(List<String> args) async {
    final out = StringBuffer();
    final code = await runCheck(['--root', root, ...args], out: out);
    return CheckRun(code, out.toString());
  }

  /// Reads [relativePath] as a string.
  String read(String relativePath) =>
      File(p.join(root, relativePath)).readAsStringSync();

  /// Runs `tool/bump_version.dart` against this fixture with [args].
  Future<CheckRun> bumpVersion(List<String> args) async {
    final out = StringBuffer();
    final code = await runBumpVersion(['--root', root, ...args], out: out);
    return CheckRun(code, out.toString());
  }

  /// Removes the fixture directory.
  void dispose() => Directory(root).deleteSync(recursive: true);
}

/// Exit code and captured output of one check run.
class CheckRun {
  /// Creates a run result.
  CheckRun(this.exitCode, this.output);

  /// Process-style exit code; zero means every selected stage passed.
  final int exitCode;

  /// Everything the check command printed.
  final String output;

  @override
  String toString() => 'exit $exitCode\n$output';
}
