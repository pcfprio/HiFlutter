import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../stage.dart';

/// Workspace-relative path of the business-term blacklist.
const businessTermsPath = 'tool/business_terms.txt';

/// Reads the blacklist at [root]/[businessTermsPath].
List<String> readBusinessTerms(String root) => [
  for (final line in File(p.join(root, businessTermsPath)).readAsLinesSync())
    if (line.trim() case final term
        when term.isNotEmpty && !term.startsWith('#'))
      term,
];

/// Fails when a business term appears in any repository file or file path.
class TermsStage implements CheckStage {
  @override
  String get id => 'terms';

  @override
  String get title => 'business term scan';

  @override
  Future<StageResult> run(CheckContext context) async {
    if (!File(p.join(context.root, businessTermsPath)).existsSync()) {
      return StageResult.fail(['Missing $businessTermsPath']);
    }
    final terms = readBusinessTerms(context.root);
    final pattern = RegExp(
      terms.map(RegExp.escape).join('|'),
      caseSensitive: false,
    );
    final problems = <String>[];
    for (final path in await _files(context.root)) {
      if (path == businessTermsPath) continue;
      if (pattern.firstMatch(path) case final match?) {
        problems.add('$path: path contains "${match[0]}"');
      }
      final String text;
      try {
        text = File(p.join(context.root, path)).readAsStringSync();
      } on FileSystemException {
        continue; // Binary or unreadable file.
      }
      for (final (index, line) in const LineSplitter().convert(text).indexed) {
        if (pattern.firstMatch(line) case final match?) {
          problems.add('$path:${index + 1}: contains "${match[0]}"');
        }
      }
    }
    return StageResult.of(problems);
  }

  /// Workspace-relative paths (with `/` separators) of the files to scan:
  /// tracked plus untracked-but-not-ignored files in a git checkout, or
  /// every non-hidden file outside `build/` otherwise.
  Future<List<String>> _files(String root) async {
    if (FileSystemEntity.typeSync(p.join(root, '.git')) !=
        FileSystemEntityType.notFound) {
      final result = await Process.run('git', [
        'ls-files',
        '-z',
        '--cached',
        '--others',
        '--exclude-standard',
      ], workingDirectory: root);
      if (result.exitCode != 0) {
        throw StateError('git ls-files failed: ${result.stderr}');
      }
      return [
        for (final path in (result.stdout as String).split('\x00'))
          // Nested repositories are listed as directories; skip them.
          if (path.isNotEmpty &&
              !path.endsWith('/') &&
              File(p.join(root, path)).existsSync())
            path,
      ];
    }
    return [
      for (final entity in Directory(root).listSync(recursive: true))
        if (entity is File)
          if (p.split(p.relative(entity.path, from: root)) case final parts
              when !parts.any(
                (part) => part.startsWith('.') || part == 'build',
              ))
            parts.join('/'),
    ];
  }
}
