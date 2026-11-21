import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'tool_failure.dart';

/// File name of pub dependency overrides.
const overridesFileName = 'pubspec_overrides.yaml';

/// File name of pub lockfile.
const lockFileName = 'pubspec.lock';

/// Verifies every package in [managedPackages] against [expectedSha] inside
/// the consumer project's `pubspec.lock`.
///
/// Returns a list of human-readable problem descriptions; empty when valid.
List<String> verifyPinnedLockfile({
  required String projectDir,
  required String tag,
  required String expectedSha,
  required List<String> managedPackages,
}) {
  final lockFile = File(p.join(projectDir, lockFileName));
  if (!lockFile.existsSync()) {
    return [
      'Missing $lockFileName in $projectDir. '
          'Run "dart pub get" or "flutter pub get" first.',
    ];
  }

  final Object? parsed;
  try {
    parsed = loadYaml(lockFile.readAsStringSync());
  } on YamlException catch (e) {
    return ['Invalid $lockFileName in $projectDir: ${e.message}'];
  }
  if (parsed is! YamlMap) {
    return ['Invalid $lockFileName in $projectDir: expected a YAML mapping.'];
  }
  final packagesNode = parsed['packages'];
  if (packagesNode is! YamlMap) {
    return ['Invalid $lockFileName in $projectDir: missing "packages" map.'];
  }

  final problems = <String>[];
  final targetSha = expectedSha.trim().toLowerCase();

  for (final pkgName in managedPackages) {
    final entry = packagesNode[pkgName];
    if (entry is! YamlMap) {
      problems.add('Package "$pkgName" is missing from $lockFileName.');
      continue;
    }
    final source = entry['source']?.toString();
    if (source != 'git') {
      problems.add(
        'Package "$pkgName" in $lockFileName has source "$source", '
        'expected "git". Run pub get after pinning.',
      );
      continue;
    }
    final desc = entry['description'];
    final resolvedRef = desc is YamlMap
        ? desc['resolved-ref']?.toString().trim()
        : null;
    if (resolvedRef == null || resolvedRef.isEmpty) {
      problems.add(
        'Package "$pkgName" in $lockFileName has no description.resolved-ref.',
      );
      continue;
    }
    if (resolvedRef.toLowerCase() != targetSha) {
      problems.add(
        'Package "$pkgName" resolved-ref is "$resolvedRef", '
        'expected "$expectedSha" (tag "$tag").',
      );
    }
  }
  return problems;
}

/// Helper that throws [ToolFailure] if `pubspec.lock` checks fail.
void assertPinnedLockfile({
  required String projectDir,
  required String tag,
  required String expectedSha,
  required List<String> managedPackages,
}) {
  final problems = verifyPinnedLockfile(
    projectDir: projectDir,
    tag: tag,
    expectedSha: expectedSha,
    managedPackages: managedPackages,
  );
  if (problems.isNotEmpty) {
    throw ToolFailure(problems.join('\n'));
  }
}
