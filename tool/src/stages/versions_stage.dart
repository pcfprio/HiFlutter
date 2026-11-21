import 'dart:io';

import 'package:path/path.dart' as p;

import '../stage.dart';
import '../workspace.dart';

/// Enforces the single shared version of all publishable packages.
class VersionsStage implements CheckStage {
  @override
  String get id => 'versions';

  @override
  String get title => 'version consistency';

  @override
  Future<StageResult> run(CheckContext context) async {
    final allPackages = loadWorkspace(context.root);
    final packages = allPackages.where((pkg) => pkg.publishable).toList();
    final problems = <String>[];

    final byVersion = <String?, List<String>>{};
    for (final pkg in packages) {
      (byVersion[pkg.version] ??= []).add(pkg.name);
    }
    if (byVersion.length > 1) {
      problems.add(
        'Packages must share one version, found: '
        '${byVersion.entries.map((e) => '${e.key} (${e.value.join(', ')})').join('; ')}',
      );
    }

    final names = {for (final pkg in packages) pkg.name};
    String? sharedVersion;
    for (final pkg in packages) {
      final version = pkg.version;
      if (version == null) {
        problems.add('${pkg.name} has no version');
        continue;
      }
      sharedVersion ??= version;
      _checkInterPackageConstraints(pkg, names, '^$version', problems);

      final changelog = File(p.join(pkg.dir, 'CHANGELOG.md'));
      final header = RegExp(
        '^## ${RegExp.escape(version)}\\s*\$',
        multiLine: true,
      );
      if (!changelog.existsSync()) {
        problems.add('${pkg.name} has no CHANGELOG.md');
      } else if (!header.hasMatch(changelog.readAsStringSync())) {
        problems.add('${pkg.name} CHANGELOG.md lacks a "## $version" header');
      }
    }

    if (byVersion.length <= 1 && sharedVersion != null) {
      final expected = '^$sharedVersion';
      for (final pkg in allPackages.where((pkg) => !pkg.publishable)) {
        _checkInterPackageConstraints(pkg, names, expected, problems);
      }
    }
    return StageResult.of(problems);
  }

  void _checkInterPackageConstraints(
    WorkspacePackage pkg,
    Set<String> names,
    String expected,
    List<String> problems,
  ) {
    for (final MapEntry(key: dep, value: spec) in {
      ...pkg.dependencies,
      ...pkg.devDependencies,
    }.entries) {
      if (names.contains(dep) && spec != expected) {
        problems.add(
          '${pkg.name} -> $dep must be constrained to "$expected", '
          'found "$spec"',
        );
      }
    }
  }
}
