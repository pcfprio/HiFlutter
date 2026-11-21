import 'dart:io';

import 'package:hiflutter_tool/hiflutter_tool.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  late _TestWorkspace ws;

  setUp(() async {
    ws = await _TestWorkspace.create();
  });

  tearDown(() => ws.dispose());

  group('CLI usage and arguments', () {
    test('prints help and exits 0 on --help', () async {
      final result = await ws.run(['--help']);

      expect(result.exitCode, 0);
      expect(result.stdout, contains('mode'));
      expect(result.stdout, contains('check'));
    });

    test('exits 64 on unknown command or missing pin tag', () async {
      final unknown = await ws.run(['unknown']);
      expect(unknown.exitCode, 64);

      final missingTag = await ws.run(['mode', 'pin']);
      expect(missingTag.exitCode, 64);

      final extraArgs = await ws.run(['mode', 'source', 'extra']);
      expect(extraArgs.exitCode, 64);
    });
  });

  group('mode source', () {
    test(
      'computes transitive closure and writes relative POSIX paths',
      () async {
        final consumerPubspec = File(p.join(ws.consumerDir, 'pubspec.yaml'));
        final originalPubspec = consumerPubspec.readAsStringSync();

        final result = await ws.run([
          'mode',
          'source',
          '--project-dir',
          ws.consumerDir,
        ]);

        expect(result.exitCode, 0, reason: result.debugSummary);
        expect(consumerPubspec.readAsStringSync(), originalPubspec);

        final overridesFile = File(
          p.join(ws.consumerDir, 'pubspec_overrides.yaml'),
        );
        expect(overridesFile.existsSync(), isTrue);

        final text = overridesFile.readAsStringSync();
        expect(text, contains('# hiflutter-tool:mode=source'));
        expect(text, contains('# BEGIN HIFLUTTER MANAGED'));
        expect(text, contains('# END HIFLUTTER MANAGED'));

        final parsed = loadYaml(text) as YamlMap;
        final overrides = parsed['dependency_overrides'] as YamlMap;
        expect(
          overrides.keys.toSet(),
          equals({'hiflutter_base', 'hiflutter_net'}),
        );
        expect(
          (overrides['hiflutter_base'] as YamlMap)['path'],
          '../HiFlutter/packages/hiflutter_base',
        );
        expect(
          (overrides['hiflutter_net'] as YamlMap)['path'],
          '../HiFlutter/packages/hiflutter_net',
        );
      },
    );

    test('includes consumer dev_dependencies in closure', () async {
      ws.writeConsumerPubspec(
        dependencies: {'hiflutter_net': '^1.0.0'},
        devDependencies: {'hiflutter_store': '^1.0.0'},
      );

      final result = await ws.run([
        'mode',
        'source',
        '--project-dir',
        ws.consumerDir,
      ]);

      expect(result.exitCode, 0, reason: result.debugSummary);
      final parsed = loadYaml(
        File(p.join(ws.consumerDir, 'pubspec_overrides.yaml'))
            .readAsStringSync(),
      ) as YamlMap;
      final overrides = parsed['dependency_overrides'] as YamlMap;
      expect(
        overrides.keys.toSet(),
        equals({'hiflutter_base', 'hiflutter_net', 'hiflutter_store'}),
      );
    });

    test(
      'resolves HiFlutter dir with precedence: flag > env > sibling',
      () async {
        final altByEnv = await ws.createAltRepo('alt_env');
        final altByFlag = await ws.createAltRepo('alt_flag');

        final envResult = await ws.run(
          ['mode', 'source', '--project-dir', ws.consumerDir],
          environment: {'HIFLUTTER_DIR': altByEnv},
        );
        expect(envResult.exitCode, 0, reason: envResult.debugSummary);
        var text = File(p.join(ws.consumerDir, 'pubspec_overrides.yaml'))
            .readAsStringSync();
        expect(text, contains('../alt_env/packages/hiflutter_net'));

        final flagResult = await ws.run(
          [
            'mode',
            'source',
            '--project-dir',
            ws.consumerDir,
            '--hiflutter-dir',
            altByFlag,
          ],
          environment: {'HIFLUTTER_DIR': altByEnv},
        );
        expect(flagResult.exitCode, 0, reason: flagResult.debugSummary);
        text = File(p.join(ws.consumerDir, 'pubspec_overrides.yaml'))
            .readAsStringSync();
        expect(text, contains('../alt_flag/packages/hiflutter_net'));
      },
    );

    test(
      'preserves user-owned dependency_overrides and replaces conflicts',
      () async {
        File(p.join(ws.consumerDir, 'pubspec_overrides.yaml'))
            .writeAsStringSync('''
# User override header
dependency_overrides:
  # Keep dio pinned locally
  dio: ^5.9.0
  local_pkg:
    path: ../local_pkg
  hiflutter_base:
    path: ../stale_manual_base
''');

        final result = await ws.run([
          'mode',
          'source',
          '--project-dir',
          ws.consumerDir,
        ]);

        expect(result.exitCode, 0, reason: result.debugSummary);
        final text = File(p.join(ws.consumerDir, 'pubspec_overrides.yaml'))
            .readAsStringSync();
        expect(text, contains('# User override header'));
        expect(text, contains('# Keep dio pinned locally'));
        expect(text, isNot(contains('../stale_manual_base')));

        final parsed = loadYaml(text) as YamlMap;
        final overrides = parsed['dependency_overrides'] as YamlMap;
        expect(overrides['dio'], '^5.9.0');
        expect((overrides['local_pkg'] as YamlMap)['path'], '../local_pkg');
        expect(
          (overrides['hiflutter_base'] as YamlMap)['path'],
          '../HiFlutter/packages/hiflutter_base',
        );
        expect(
          (overrides['hiflutter_net'] as YamlMap)['path'],
          '../HiFlutter/packages/hiflutter_net',
        );
      },
    );

    test('preserves flow-style user dependency_overrides cleanly', () async {
      File(p.join(ws.consumerDir, 'pubspec_overrides.yaml'))
          .writeAsStringSync('dependency_overrides: {dio: ^5.9.0}\n');

      final result = await ws.run([
        'mode',
        'source',
        '--project-dir',
        ws.consumerDir,
      ]);

      expect(result.exitCode, 0, reason: result.debugSummary);
      final parsed = loadYaml(
        File(p.join(ws.consumerDir, 'pubspec_overrides.yaml'))
            .readAsStringSync(),
      ) as YamlMap;
      final overrides = parsed['dependency_overrides'] as YamlMap;
      expect(overrides['dio'], '^5.9.0');
      expect(overrides['hiflutter_base'], isA<YamlMap>());
      expect(overrides['hiflutter_net'], isA<YamlMap>());
    });

    test('fails when an unknown hiflutter_* dependency is requested', () async {
      ws.writeConsumerPubspec(dependencies: {'hiflutter_missing': '^1.0.0'});

      final result = await ws.run([
        'mode',
        'source',
        '--project-dir',
        ws.consumerDir,
      ]);

      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('hiflutter_missing'));
    });
  });

  group('mode pin', () {
    test('shallow-clones tag, computes closure, and writes git overrides', () async {
      final consumerPubspec = File(p.join(ws.consumerDir, 'pubspec.yaml'));
      final originalPubspec = consumerPubspec.readAsStringSync();

      File(p.join(ws.consumerDir, 'pubspec_overrides.yaml'))
          .writeAsStringSync('''
dependency_overrides:
  custom_dep: ^2.0.0
''');

      final result = await ws.run([
        'mode',
        'pin',
        ws.annotatedTag,
        '--project-dir',
        ws.consumerDir,
        '--git-url',
        ws.repoDir,
      ]);

      expect(result.exitCode, 0, reason: result.debugSummary);
      expect(consumerPubspec.readAsStringSync(), originalPubspec);

      final text = File(p.join(ws.consumerDir, 'pubspec_overrides.yaml'))
          .readAsStringSync();
      expect(
        text,
        contains(
          '# hiflutter-tool:mode=pin tag=${ws.annotatedTag} url=${ws.repoDir}',
        ),
      );
      expect(text, contains('# BEGIN HIFLUTTER MANAGED'));
      expect(text, contains('# END HIFLUTTER MANAGED'));

      final parsed = loadYaml(text) as YamlMap;
      final overrides = parsed['dependency_overrides'] as YamlMap;
      expect(overrides['custom_dep'], '^2.0.0');
      expect(
        overrides.keys.toSet(),
        equals({'custom_dep', 'hiflutter_base', 'hiflutter_net'}),
      );

      final netGit = (overrides['hiflutter_net'] as YamlMap)['git'] as YamlMap;
      expect(netGit['url'], ws.repoDir);
      expect(netGit['ref'], ws.annotatedTag);
      expect(netGit['path'], 'packages/hiflutter_net');

      final baseGit =
          (overrides['hiflutter_base'] as YamlMap)['git'] as YamlMap;
      expect(baseGit['url'], ws.repoDir);
      expect(baseGit['ref'], ws.annotatedTag);
      expect(baseGit['path'], 'packages/hiflutter_base');
    });

    test('fails cleanly when tag does not exist', () async {
      final result = await ws.run([
        'mode',
        'pin',
        'v99.99.99',
        '--project-dir',
        ws.consumerDir,
        '--git-url',
        ws.repoDir,
      ]);

      expect(result.exitCode, isNot(0));
      expect(
        File(p.join(ws.consumerDir, 'pubspec_overrides.yaml')).existsSync(),
        isFalse,
      );
    });
  });

  group('mode hosted', () {
    test(
      'deletes pubspec_overrides.yaml when no user overrides exist',
      () async {
        expect(
          (await ws.run(['mode', 'source', '--project-dir', ws.consumerDir]))
              .exitCode,
          0,
        );
        final overrides = File(
          p.join(ws.consumerDir, 'pubspec_overrides.yaml'),
        );
        expect(overrides.existsSync(), isTrue);

        final result = await ws.run([
          'mode',
          'hosted',
          '--project-dir',
          ws.consumerDir,
        ]);

        expect(result.exitCode, 0, reason: result.debugSummary);
        expect(overrides.existsSync(), isFalse);
      },
    );

    test('removes managed entries while preserving user overrides', () async {
      final overrides = File(p.join(ws.consumerDir, 'pubspec_overrides.yaml'));
      overrides.writeAsStringSync('''
# Keep this comment
dependency_overrides:
  dio: ^5.9.0
''');

      expect(
        (await ws.run([
          'mode',
          'pin',
          ws.annotatedTag,
          '--project-dir',
          ws.consumerDir,
          '--git-url',
          ws.repoDir,
        ])).exitCode,
        0,
      );

      final result = await ws.run([
        'mode',
        'hosted',
        '--project-dir',
        ws.consumerDir,
      ]);

      expect(result.exitCode, 0, reason: result.debugSummary);
      expect(overrides.existsSync(), isTrue);

      final text = overrides.readAsStringSync();
      expect(text, contains('# Keep this comment'));
      expect(text, isNot(contains('hiflutter-tool:')));
      expect(text, isNot(contains('HIFLUTTER MANAGED')));
      expect(text, isNot(contains('hiflutter_base')));
      expect(text, isNot(contains('hiflutter_net')));

      final parsed = loadYaml(text) as YamlMap;
      final map = parsed['dependency_overrides'] as YamlMap;
      expect(map.keys.toList(), ['dio']);
      expect(map['dio'], '^5.9.0');
    });

    test('succeeds when pubspec_overrides.yaml is already absent', () async {
      final result = await ws.run([
        'mode',
        'hosted',
        '--project-dir',
        ws.consumerDir,
      ]);
      expect(result.exitCode, 0);
    });
  });

  group('check', () {
    test('hosted mode passes with and without --release', () async {
      final normal = await ws.run(['check', '--project-dir', ws.consumerDir]);
      expect(normal.exitCode, 0, reason: normal.debugSummary);
      expect(normal.stdout.toLowerCase(), contains('hosted'));

      final release = await ws.run([
        'check',
        '--release',
        '--project-dir',
        ws.consumerDir,
      ]);
      expect(release.exitCode, 0, reason: release.debugSummary);
      expect(release.stdout.toLowerCase(), contains('hosted'));
    });

    test(
      'source mode reports clean/dirty and fails only on --release',
      () async {
        expect(
          (await ws.run(['mode', 'source', '--project-dir', ws.consumerDir]))
              .exitCode,
          0,
        );

        final clean = await ws.run(['check', '--project-dir', ws.consumerDir]);
        expect(clean.exitCode, 0, reason: clean.debugSummary);
        expect(clean.stdout.toLowerCase(), contains('source'));
        expect(clean.stdout.toLowerCase(), contains('clean'));

        final cleanRelease = await ws.run([
          'check',
          '--release',
          '--project-dir',
          ws.consumerDir,
        ]);
        expect(cleanRelease.exitCode, isNot(0));
        expect(cleanRelease.stderr.toLowerCase(), contains('source'));

        // Dirty the HiFlutter repo.
        File(p.join(ws.repoDir, 'UNTRACKED.txt')).writeAsStringSync('dirty\n');

        final dirty = await ws.run(['check', '--project-dir', ws.consumerDir]);
        expect(dirty.exitCode, 0, reason: dirty.debugSummary);
        expect(dirty.stdout.toLowerCase(), contains('dirty'));

        final dirtyRelease = await ws.run([
          'check',
          '--release',
          '--project-dir',
          ws.consumerDir,
        ]);
        expect(dirtyRelease.exitCode, isNot(0));
      },
    );

    test('pin mode verifies resolved-ref in pubspec.lock against annotated and lightweight tags', () async {
      expect(
        (await ws.run([
          'mode',
          'pin',
          ws.annotatedTag,
          '--project-dir',
          ws.consumerDir,
          '--git-url',
          ws.repoDir,
        ])).exitCode,
        0,
      );

      // Missing pubspec.lock fails.
      final noLock = await ws.run([
        'check',
        '--release',
        '--project-dir',
        ws.consumerDir,
      ]);
      expect(noLock.exitCode, isNot(0));
      expect(noLock.stderr, contains('pubspec.lock'));

      // Write matching pubspec.lock for both managed packages.
      ws.writeConsumerLock({
        'hiflutter_base': _LockEntry.git(
          url: ws.repoDir,
          ref: ws.annotatedTag,
          resolvedRef: ws.commitSha,
          path: 'packages/hiflutter_base',
        ),
        'hiflutter_net': _LockEntry.git(
          url: ws.repoDir,
          ref: ws.annotatedTag,
          resolvedRef: ws.commitSha,
          path: 'packages/hiflutter_net',
        ),
      });

      final ok = await ws.run([
        'check',
        '--release',
        '--project-dir',
        ws.consumerDir,
      ]);
      expect(ok.exitCode, 0, reason: ok.debugSummary);
      expect(ok.stdout.toLowerCase(), contains('pin'));

      // Lightweight tag should also resolve to commitSha and pass.
      expect(
        (await ws.run([
          'mode',
          'pin',
          ws.lightweightTag,
          '--project-dir',
          ws.consumerDir,
          '--git-url',
          ws.repoDir,
        ])).exitCode,
        0,
      );
      ws.writeConsumerLock({
        'hiflutter_base': _LockEntry.git(
          url: ws.repoDir,
          ref: ws.lightweightTag,
          resolvedRef: ws.commitSha,
          path: 'packages/hiflutter_base',
        ),
        'hiflutter_net': _LockEntry.git(
          url: ws.repoDir,
          ref: ws.lightweightTag,
          resolvedRef: ws.commitSha,
          path: 'packages/hiflutter_net',
        ),
      });
      final lightOk = await ws.run([
        'check',
        '--release',
        '--project-dir',
        ws.consumerDir,
      ]);
      expect(lightOk.exitCode, 0, reason: lightOk.debugSummary);
    });

    test(
      'pin mode fails on missing package, wrong source, or mismatched SHA',
      () async {
        expect(
          (await ws.run([
            'mode',
            'pin',
            ws.annotatedTag,
            '--project-dir',
            ws.consumerDir,
            '--git-url',
            ws.repoDir,
          ])).exitCode,
          0,
        );

        // Missing hiflutter_base from lockfile.
        ws.writeConsumerLock({
          'hiflutter_net': _LockEntry.git(
            url: ws.repoDir,
            ref: ws.annotatedTag,
            resolvedRef: ws.commitSha,
            path: 'packages/hiflutter_net',
          ),
        });
        final missingPkg = await ws.run([
          'check',
          '--project-dir',
          ws.consumerDir,
        ]);
        expect(missingPkg.exitCode, isNot(0));
        expect(missingPkg.stderr, contains('hiflutter_base'));

        // Wrong source (path instead of git).
        ws.writeConsumerLock({
          'hiflutter_base': _LockEntry.path(
            '../HiFlutter/packages/hiflutter_base',
          ),
          'hiflutter_net': _LockEntry.git(
            url: ws.repoDir,
            ref: ws.annotatedTag,
            resolvedRef: ws.commitSha,
            path: 'packages/hiflutter_net',
          ),
        });
        final wrongSource = await ws.run([
          'check',
          '--project-dir',
          ws.consumerDir,
        ]);
        expect(wrongSource.exitCode, isNot(0));
        expect(wrongSource.stderr, contains('hiflutter_base'));

        // Stale resolved-ref SHA.
        ws.writeConsumerLock({
          'hiflutter_base': _LockEntry.git(
            url: ws.repoDir,
            ref: ws.annotatedTag,
            resolvedRef: '0' * 40,
            path: 'packages/hiflutter_base',
          ),
          'hiflutter_net': _LockEntry.git(
            url: ws.repoDir,
            ref: ws.annotatedTag,
            resolvedRef: ws.commitSha,
            path: 'packages/hiflutter_net',
          ),
        });
        final badSha = await ws.run(['check', '--project-dir', ws.consumerDir]);
        expect(badSha.exitCode, isNot(0));
        expect(badSha.stderr, contains('hiflutter_base'));
      },
    );

    test('check source fails when HiFlutter dir is missing and supports --hiflutter-dir', () async {
      final alt = await ws.createAltRepo('custom_hi');
      await Process.run('git', ['init', '-q'], workingDirectory: alt);

      expect(
        (await ws.run([
          'mode',
          'source',
          '--project-dir',
          ws.consumerDir,
          '--hiflutter-dir',
          alt,
        ])).exitCode,
        0,
      );

      final okCheck = await ws.run([
        'check',
        '--project-dir',
        ws.consumerDir,
        '--hiflutter-dir',
        alt,
      ]);
      expect(okCheck.exitCode, 0, reason: okCheck.debugSummary);

      Directory(alt).deleteSync(recursive: true);
      final missingDirCheck = await ws.run([
        'check',
        '--project-dir',
        ws.consumerDir,
        '--hiflutter-dir',
        alt,
      ]);
      expect(missingDirCheck.exitCode, isNot(0));
    });

    test(
      'mode transitions shrink removed managed deps and keep user keys',
      () async {
        File(p.join(ws.consumerDir, 'pubspec_overrides.yaml'))
            .writeAsStringSync('''
dependency_overrides:
  dio: ^5.9.0
other_top_level: keep
''');

        ws.writeConsumerPubspec(
          dependencies: {
            'hiflutter_net': '^1.0.0',
            'hiflutter_store': '^1.0.0',
          },
        );
        expect(
          (await ws.run(['mode', 'source', '--project-dir', ws.consumerDir]))
              .exitCode,
          0,
        );

        // Drop hiflutter_store and switch to pin, then back to source.
        ws.writeConsumerPubspec(dependencies: {'hiflutter_net': '^1.0.0'});
        expect(
          (await ws.run([
            'mode',
            'pin',
            ws.annotatedTag,
            '--project-dir',
            ws.consumerDir,
            '--git-url',
            ws.repoDir,
          ])).exitCode,
          0,
        );
        expect(
          (await ws.run(['mode', 'source', '--project-dir', ws.consumerDir]))
              .exitCode,
          0,
        );

        final text = File(p.join(ws.consumerDir, 'pubspec_overrides.yaml'))
            .readAsStringSync();
        final parsed = loadYaml(text) as YamlMap;
        expect(parsed['other_top_level'], 'keep');
        final overrides = parsed['dependency_overrides'] as YamlMap;
        expect(
          overrides.keys.toSet(),
          equals({'dio', 'hiflutter_base', 'hiflutter_net'}),
        );
        expect(overrides.containsKey('hiflutter_store'), isFalse);
      },
    );
  });

  test('CLI binary bin/hiflutter.dart executes successfully', () async {
    final proc = await Process.run('dart', [
      'run',
      'hiflutter_tool:hiflutter',
      '--help',
    ]);
    expect(proc.exitCode, 0, reason: '${proc.stderr}');
    expect(proc.stdout as String, contains('mode'));
  });
}

class _RunOutput {
  _RunOutput(this.exitCode, this.stdout, this.stderr);

  final int exitCode;
  final String stdout;
  final String stderr;

  String get debugSummary =>
      'exit=$exitCode\nstdout:\n$stdout\nstderr:\n$stderr';
}

class _LockEntry {
  _LockEntry.git({
    required this.url,
    required this.ref,
    required this.resolvedRef,
    required this.path,
  }) : source = 'git';

  _LockEntry.path(this.path)
    : source = 'path',
      url = null,
      ref = null,
      resolvedRef = null;

  final String source;
  final String path;
  final String? url;
  final String? ref;
  final String? resolvedRef;
}

class _TestWorkspace {
  _TestWorkspace._({
    required this.rootDir,
    required this.repoDir,
    required this.consumerDir,
    required this.commitSha,
  });

  final String rootDir;
  final String repoDir;
  final String consumerDir;
  final String commitSha;

  final String annotatedTag = 'v1.0.0';
  final String lightweightTag = 'v1.0.0-light';

  static Future<_TestWorkspace> create() async {
    final root = await Directory.systemTemp.createTemp('hiflutter_tool_test_');
    final repoDir = p.join(root.path, 'HiFlutter');
    final consumerDir = p.join(root.path, 'consumer');

    await _createRepo(repoDir);
    await _git(repoDir, ['init', '-q']);
    await _git(repoDir, ['config', 'user.name', 'Test User']);
    await _git(repoDir, ['config', 'user.email', 'test@example.com']);
    await _git(repoDir, ['add', '.']);
    await _git(repoDir, ['commit', '-q', '-m', 'Initial packages']);
    await _git(repoDir, ['tag', '-a', 'v1.0.0', '-m', 'Release v1.0.0']);
    await _git(repoDir, ['tag', 'v1.0.0-light']);
    final sha = (await _git(repoDir, ['rev-parse', 'HEAD'])).trim();

    Directory(p.join(consumerDir, 'lib')).createSync(recursive: true);
    final ws = _TestWorkspace._(
      rootDir: root.path,
      repoDir: repoDir,
      consumerDir: consumerDir,
      commitSha: sha,
    );
    ws.writeConsumerPubspec(dependencies: {'hiflutter_net': '^1.0.0'});
    return ws;
  }

  Future<String> createAltRepo(String name) async {
    final dir = p.join(rootDir, name);
    await _createRepo(dir);
    return dir;
  }

  void writeConsumerPubspec({
    Map<String, String> dependencies = const {},
    Map<String, String> devDependencies = const {},
  }) {
    final buf = StringBuffer()
      ..writeln('name: consumer_app')
      ..writeln('version: 1.0.0')
      ..writeln('environment:')
      ..writeln('  sdk: ^3.14.0');
    if (dependencies.isNotEmpty) {
      buf.writeln('dependencies:');
      for (final e in dependencies.entries) {
        buf.writeln('  ${e.key}: ${e.value}');
      }
    }
    if (devDependencies.isNotEmpty) {
      buf.writeln('dev_dependencies:');
      for (final e in devDependencies.entries) {
        buf.writeln('  ${e.key}: ${e.value}');
      }
    }
    File(p.join(consumerDir, 'pubspec.yaml')).writeAsStringSync(buf.toString());
  }

  void writeConsumerLock(Map<String, _LockEntry> packages) {
    final buf = StringBuffer()..writeln('packages:');
    for (final entry in packages.entries) {
      final pkg = entry.key;
      final info = entry.value;
      buf
        ..writeln('  $pkg:')
        ..writeln('    dependency: "direct main"')
        ..writeln('    description:');
      if (info.source == 'git') {
        buf
          ..writeln('      path: "${info.path}"')
          ..writeln('      ref: "${info.ref}"')
          ..writeln('      resolved-ref: ${info.resolvedRef}')
          ..writeln('      url: "${info.url}"');
      } else {
        buf
          ..writeln('      path: "${info.path}"')
          ..writeln('      relative: true');
      }
      buf
        ..writeln('    source: ${info.source}')
        ..writeln('    version: "1.0.0"');
    }
    File(p.join(consumerDir, 'pubspec.lock')).writeAsStringSync(buf.toString());
  }

  Future<_RunOutput> run(
    List<String> args, {
    Map<String, String>? environment,
  }) async {
    final out = StringBuffer();
    final err = StringBuffer();
    final runner = HiToolRunner(
      out: out,
      err: err,
      workingDirectory: consumerDir,
      environment: environment ?? const {},
    );
    final code = await runner.run(args);
    return _RunOutput(code, out.toString(), err.toString());
  }

  void dispose() {
    Directory(rootDir).deleteSync(recursive: true);
  }

  static Future<void> _createRepo(String repoDir) async {
    void writePkg(
      String name, {
      Map<String, String> deps = const {},
      Map<String, String> devDeps = const {},
    }) {
      final pkgDir = p.join(repoDir, 'packages', name);
      Directory(p.join(pkgDir, 'lib')).createSync(recursive: true);
      final buf = StringBuffer()
        ..writeln('name: $name')
        ..writeln('version: 1.0.0')
        ..writeln('environment:')
        ..writeln('  sdk: ^3.14.0')
        ..writeln('resolution: workspace');
      if (deps.isNotEmpty) {
        buf.writeln('dependencies:');
        for (final e in deps.entries) {
          buf.writeln('  ${e.key}: ${e.value}');
        }
      }
      if (devDeps.isNotEmpty) {
        buf.writeln('dev_dependencies:');
        for (final e in devDeps.entries) {
          buf.writeln('  ${e.key}: ${e.value}');
        }
      }
      File(p.join(pkgDir, 'pubspec.yaml')).writeAsStringSync(buf.toString());
      File(p.join(pkgDir, 'lib', '$name.dart')).writeAsStringSync('library;\n');
    }

    Directory(repoDir).createSync(recursive: true);
    File(p.join(repoDir, 'pubspec.yaml')).writeAsStringSync('''
name: hiflutter_workspace
publish_to: none
environment:
  sdk: ^3.14.0
workspace:
  - packages/hiflutter_base
  - packages/hiflutter_net
  - packages/hiflutter_store
  - packages/hiflutter_dev_only
''');
    writePkg('hiflutter_base');
    writePkg(
      'hiflutter_net',
      deps: {'hiflutter_base': '^1.0.0'},
      devDeps: {'hiflutter_dev_only': '^1.0.0'},
    );
    writePkg('hiflutter_store', deps: {'hiflutter_base': '^1.0.0'});
    writePkg('hiflutter_dev_only');
  }

  static Future<String> _git(String dir, List<String> args) async {
    final res = await Process.run('git', args, workingDirectory: dir);
    if (res.exitCode != 0) {
      throw ProcessException('git', args, '${res.stderr}', res.exitCode);
    }
    return res.stdout as String;
  }
}
