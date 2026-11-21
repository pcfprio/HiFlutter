import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'tool_failure.dart';

/// Whether [name] is a HiFlutter package name (`hiflutter` or `hiflutter_*`).
bool isHiFlutterPackageName(String name) =>
    name == 'hiflutter' || name.startsWith('hiflutter_');

/// Metadata for a HiFlutter package discovered inside a HiFlutter repository.
class HiRepoPackage {
  /// Creates package metadata.
  const HiRepoPackage({
    required this.name,
    required this.dir,
    required this.repoRelativePosixPath,
    required this.hiFlutterDependencies,
  });

  /// Package name from `pubspec.yaml`.
  final String name;

  /// Absolute directory path of this package.
  final String dir;

  /// Package directory path relative to the HiFlutter root using POSIX `/`.
  final String repoRelativePosixPath;

  /// Direct `dependencies` of this package that are HiFlutter packages.
  final List<String> hiFlutterDependencies;
}

/// Resolves the HiFlutter checkout directory for `source` mode and `check`.
///
/// Precedence: `--hiflutter-dir` > `environment['HIFLUTTER_DIR']` >
/// sibling `../HiFlutter` relative to [projectDir].
String resolveHiFlutterDir({
  String? flagDir,
  required Map<String, String> environment,
  required String workingDirectory,
  required String projectDir,
}) {
  final trimmedFlag = flagDir?.trim();
  if (trimmedFlag != null && trimmedFlag.isNotEmpty) {
    return p.normalize(p.absolute(workingDirectory, trimmedFlag));
  }
  final envDir = environment['HIFLUTTER_DIR']?.trim();
  if (envDir != null && envDir.isNotEmpty) {
    return p.normalize(p.absolute(workingDirectory, envDir));
  }
  return p.normalize(p.join(projectDir, '..', 'HiFlutter'));
}

/// Converts a platform-native path [path] into a POSIX path string using `/`.
String toPosixPath(String path) => p.posix.joinAll(p.split(path));

/// Reads direct `hiflutter` / `hiflutter_*` package names from the consumer's
/// `pubspec.yaml` (`dependencies` and `dev_dependencies`), sorted by name.
List<String> readConsumerHiFlutterDeps(String projectDir) {
  final pubspecFile = File(p.join(projectDir, 'pubspec.yaml'));
  if (!pubspecFile.existsSync()) {
    throw ToolFailure('Missing pubspec.yaml in $projectDir.');
  }
  final Object? parsed;
  try {
    parsed = loadYaml(pubspecFile.readAsStringSync());
  } on YamlException catch (e) {
    throw ToolFailure('Invalid pubspec.yaml in $projectDir: ${e.message}');
  }
  if (parsed is! YamlMap) {
    throw ToolFailure('Invalid pubspec.yaml in $projectDir: expected a map.');
  }

  final direct = <String>{};
  for (final section in const ['dependencies', 'dev_dependencies']) {
    final node = parsed[section];
    if (node is YamlMap) {
      for (final key in node.keys) {
        final name = key.toString();
        if (isHiFlutterPackageName(name)) {
          direct.add(name);
        }
      }
    }
  }
  final sorted = direct.toList()..sort();
  return sorted;
}

/// Recursively scans [repoDir] for HiFlutter packages by reading `pubspec.yaml`
/// files while skipping hidden and build directories.
Map<String, HiRepoPackage> scanHiFlutterPackages(String repoDir) {
  final root = Directory(repoDir);
  if (!root.existsSync()) {
    throw ToolFailure('HiFlutter directory does not exist: $repoDir');
  }

  final catalog = <String, HiRepoPackage>{};

  void walk(Directory dir) {
    final pubspecFile = File(p.join(dir.path, 'pubspec.yaml'));
    if (pubspecFile.existsSync()) {
      final pkg = _tryReadPackage(repoDir, dir.path, pubspecFile);
      if (pkg != null) {
        if (catalog.containsKey(pkg.name)) {
          throw ToolFailure(
            'Duplicate HiFlutter package "${pkg.name}" found at '
            '${catalog[pkg.name]!.dir} and ${pkg.dir}.',
          );
        }
        catalog[pkg.name] = pkg;
      }
    }

    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is! Directory) continue;
      final base = p.basename(entity.path);
      if (base.startsWith('.') || _ignoredDirs.contains(base)) continue;
      walk(entity);
    }
  }

  walk(root);
  return catalog;
}

const _ignoredDirs = {'build', 'ephemeral', 'Pods', 'node_modules'};

HiRepoPackage? _tryReadPackage(
  String repoRoot,
  String pkgDir,
  File pubspecFile,
) {
  final Object? parsed;
  try {
    parsed = loadYaml(pubspecFile.readAsStringSync());
  } on YamlException catch (e) {
    throw ToolFailure('Invalid ${pubspecFile.path}: ${e.message}');
  }
  if (parsed is! YamlMap) return null;

  final name = parsed['name']?.toString();
  if (name == null || !isHiFlutterPackageName(name)) return null;
  if (parsed['publish_to']?.toString() == 'none' &&
      parsed.containsKey('workspace')) {
    return null;
  }

  final deps = <String>[];
  final depsNode = parsed['dependencies'];
  if (depsNode is YamlMap) {
    for (final key in depsNode.keys) {
      final dep = key.toString();
      if (isHiFlutterPackageName(dep)) {
        deps.add(dep);
      }
    }
  }
  deps.sort();

  final rel = p.relative(pkgDir, from: repoRoot);
  final posixRel = rel == '.' ? '.' : toPosixPath(rel);
  return HiRepoPackage(
    name: name,
    dir: p.normalize(pkgDir),
    repoRelativePosixPath: posixRel,
    hiFlutterDependencies: deps,
  );
}

/// Computes the sorted transitive closure of HiFlutter packages starting from
/// [seeds] within [catalog].
List<HiRepoPackage> computeClosure(
  Map<String, HiRepoPackage> catalog,
  Iterable<String> seeds,
) {
  final visited = <String, HiRepoPackage>{};
  final queue = <String>[...seeds];

  while (queue.isNotEmpty) {
    final name = queue.removeAt(0);
    if (visited.containsKey(name)) continue;
    final pkg = catalog[name];
    if (pkg == null) {
      throw ToolFailure(
        'Package "$name" was not found in the HiFlutter repository.',
      );
    }
    visited[name] = pkg;
    for (final dep in pkg.hiFlutterDependencies) {
      if (!visited.containsKey(dep)) {
        queue.add(dep);
      }
    }
  }

  final result = visited.values.toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  return result;
}
