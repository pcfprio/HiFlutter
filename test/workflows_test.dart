import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// The repository's GitHub Actions workflows (tests run from its root).
final workflowsDir = p.join(Directory.current.path, '.github', 'workflows');

YamlMap workflow(String name) =>
    loadYaml(File(p.join(workflowsDir, '$name.yml')).readAsStringSync())
        as YamlMap;

/// Every `run:` script of [job], joined.
String scripts(YamlMap job) => [
  for (final step in job['steps'] as YamlList)
    if ((step as YamlMap)['run'] case final String run) run,
].join('\n');

void main() {
  test('every workflow parses and pins actions to a commit SHA', () {
    final files = Directory(workflowsDir)
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.yml'));
    expect(
      files.map((f) => p.basename(f.path)),
      containsAll(['ci.yml', 'deps.yml']),
    );

    final pinned = RegExp(
      r'^\s*(?:-\s*)?uses:\s*[\w.-]+/[\w./-]+@[0-9a-f]{40}\s+#\s*v\d',
    );
    for (final file in files) {
      final text = file.readAsStringSync();
      expect(loadYaml(text), isA<YamlMap>(), reason: file.path);
      for (final line in text.split('\n').where((l) => l.contains('uses:'))) {
        expect(line, matches(pinned), reason: '${file.path}: $line');
      }
    }
  });

  test('ci runs the check on push and PR, and --build on macOS', () {
    final ci = workflow('ci');
    final on = ci['on'] as YamlMap;
    expect(on.keys, containsAll(['push', 'pull_request']));

    final jobs = (ci['jobs'] as YamlMap).values.cast<YamlMap>();
    expect(
      jobs.where((job) => scripts(job).contains('dart run tool/check.dart')),
      isNotEmpty,
    );
    expect(
      jobs.where(
        (job) =>
            '${job['runs-on']}'.startsWith('macos') &&
            scripts(job).contains('dart run tool/check.dart --build'),
      ),
      hasLength(1),
    );
  });

  test('deps runs weekly and keeps one deps-breaking issue', () {
    final deps = workflow('deps');
    final on = deps['on'] as YamlMap;
    expect((on['schedule'] as YamlList).single['cron'], isA<String>());

    final script = (deps['jobs'] as YamlMap).values
        .cast<YamlMap>()
        .map(scripts)
        .join('\n');
    expect(script, contains('dart run tool/deps_report.dart --markdown'));
    expect(script, contains('deps-breaking'));
    expect(script, contains('gh issue create'));
    expect(script, contains('gh issue edit'));
  });
}
