import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// One member of the pub workspace, as declared in its `pubspec.yaml`.
class WorkspacePackage {
  WorkspacePackage._({
    required this.name,
    required this.dir,
    required this.relativeDir,
    required this.version,
    required this.publishable,
    required this.dependencies,
    required this.devDependencies,
  });

  /// Reads the package whose `pubspec.yaml` lives in [dir].
  factory WorkspacePackage.load(String root, String dir) {
    final pubspec = loadYaml(
      File(p.join(dir, 'pubspec.yaml')).readAsStringSync(),
    );
    if (pubspec is! YamlMap) {
      throw FormatException('Invalid pubspec.yaml in $dir');
    }
    return WorkspacePackage._(
      name: pubspec['name'] as String,
      dir: dir,
      relativeDir: p.relative(dir, from: root),
      version: pubspec['version'] as String?,
      publishable: pubspec['publish_to']?.toString() != 'none',
      dependencies: _deps(pubspec['dependencies']),
      devDependencies: _deps(pubspec['dev_dependencies']),
    );
  }

  /// Package name.
  final String name;

  /// Absolute package directory.
  final String dir;

  /// Package directory relative to the workspace root.
  final String relativeDir;

  /// Declared version, or `null` when absent.
  final String? version;

  /// Whether the package may be published (no `publish_to: none`).
  final bool publishable;

  /// `dependencies`, keyed by package name.
  final Map<String, Object?> dependencies;

  /// `dev_dependencies`, keyed by package name.
  final Map<String, Object?> devDependencies;

  /// Whether the package depends on the Flutter SDK.
  bool get isFlutter => isSdkDependency(dependencies['flutter']);

  /// Whether a dependency spec is `sdk: flutter`.
  static bool isSdkDependency(Object? spec) =>
      spec is Map && spec['sdk']?.toString() == 'flutter';

  static Map<String, Object?> _deps(Object? node) => node is Map
      ? {for (final e in node.entries) e.key.toString(): e.value}
      : const {};
}

/// The workspace rooted at [root]: its members, in declaration order.
List<WorkspacePackage> loadWorkspace(String root) {
  final pubspec = loadYaml(
    File(p.join(root, 'pubspec.yaml')).readAsStringSync(),
  );
  final members = pubspec is YamlMap ? pubspec['workspace'] : null;
  if (members is! YamlList) return const [];
  return [
    for (final member in members)
      WorkspacePackage.load(root, p.normalize(p.join(root, member.toString()))),
  ];
}
