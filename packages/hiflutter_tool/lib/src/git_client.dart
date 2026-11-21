import 'dart:io';

import 'package:path/path.dart' as p;

import 'tool_failure.dart';

const _gitEnv = <String, String>{'GIT_ALLOW_PROTOCOL': 'file:https:http:ssh'};

/// Resolves [rawUrl] to an absolute path when it points to an existing local
/// directory relative to [workingDirectory]; remote URLs are returned as-is.
String normalizeGitUrl(String rawUrl, String workingDirectory) {
  final trimmed = rawUrl.trim();
  if (trimmed.contains('://') || RegExp(r'^[^/\\]+@[^:]+:').hasMatch(trimmed)) {
    return trimmed;
  }
  final candidate = p.normalize(p.absolute(workingDirectory, trimmed));
  return Directory(candidate).existsSync() ? candidate : trimmed;
}

/// Shallow-clones [tag] from [url] into [destinationDir].
Future<void> shallowCloneTag({
  required String url,
  required String tag,
  required String destinationDir,
}) async {
  final result = await _runGit([
    'clone',
    '--quiet',
    '--depth',
    '1',
    '--branch',
    tag,
    url,
    destinationDir,
  ], environment: _gitEnv);
  if (result.exitCode != 0) {
    final detail = '${result.stderr}'.trim();
    throw ToolFailure(
      'Failed to clone tag "$tag" from "$url"'
      '${detail.isEmpty ? '.' : ': $detail'}',
    );
  }
}

/// Returns whether the git working tree at [repoDir] has uncommitted changes.
Future<bool> isWorkingTreeDirty(String repoDir) async {
  if (!Directory(repoDir).existsSync()) {
    throw ToolFailure('HiFlutter directory does not exist: $repoDir');
  }
  final result = await _runGit([
    'status',
    '--porcelain',
  ], workingDirectory: repoDir);
  if (result.exitCode != 0) {
    final detail = '${result.stderr}'.trim();
    throw ToolFailure(
      'Failed to inspect git status in $repoDir'
      '${detail.isEmpty ? '.' : ': $detail'}',
    );
  }
  return (result.stdout as String).trim().isNotEmpty;
}

/// Resolves the commit SHA that [tag] points to in [url] via `git ls-remote`.
///
/// Prefers the dereferenced annotated tag entry (`refs/tags/<tag>^{}`) over
/// the lightweight tag entry (`refs/tags/<tag>`).
Future<String> resolveRemoteTagSha({
  required String url,
  required String tag,
}) async {
  final tagRef = 'refs/tags/$tag';
  final peeledRef = '$tagRef^{}';
  final result = await _runGit([
    'ls-remote',
    url,
    tagRef,
    peeledRef,
  ], environment: _gitEnv);
  if (result.exitCode != 0) {
    final detail = '${result.stderr}'.trim();
    throw ToolFailure(
      'Failed to query remote tag "$tag" at "$url"'
      '${detail.isEmpty ? '.' : ': $detail'}',
    );
  }

  String? directSha;
  String? peeledSha;
  for (final rawLine in (result.stdout as String).split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    final parts = line.split(RegExp(r'\s+'));
    if (parts.length < 2) continue;
    final sha = parts[0];
    final ref = parts[1];
    if (ref == peeledRef) {
      peeledSha = sha;
    } else if (ref == tagRef) {
      directSha = sha;
    }
  }

  final resolved = peeledSha ?? directSha;
  if (resolved == null || resolved.isEmpty) {
    throw ToolFailure('Tag "$tag" was not found at "$url".');
  }
  return resolved;
}

Future<ProcessResult> _runGit(
  List<String> args, {
  String? workingDirectory,
  Map<String, String>? environment,
}) async {
  try {
    return await Process.run(
      'git',
      args,
      workingDirectory: workingDirectory,
      environment: environment,
    );
  } on ProcessException catch (e) {
    throw ToolFailure('Failed to invoke git: ${e.message}');
  }
}
