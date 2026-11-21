import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../tool/src/deps_report.dart';
import 'support/fixture_repo.dart';

/// A `dart pub outdated --json` document reporting [latest] versions.
String outdatedJson(Map<String, String> latest) => jsonEncode({
  'packages': [
    for (final MapEntry(key: name, value: version) in latest.entries)
      {
        'package': name,
        'kind': 'direct',
        'current': {'version': '0.0.1'},
        'upgradable': {'version': '0.0.1'},
        'resolvable': {'version': version},
        'latest': {'version': version},
      },
  ],
});

void main() {
  late FixtureRepo repo;

  tearDown(() => repo.dispose());

  Future<CheckRun> report(List<String> args, Map<String, String> latest) async {
    final out = StringBuffer();
    final code = await runDepsReport(
      ['--root', repo.root, ...args],
      out: out,
      outdated: (_) async => outdatedJson(latest),
    );
    return CheckRun(code, out.toString());
  }

  test('lists only updates that leave the caret constraint', () async {
    repo = await FixtureRepo.create(
      packages: ['hiflutter_base', 'hiflutter_net'],
    );
    repo.addPackage(
      'hiflutter_net',
      dependencies: {'http': '^0.13.0', 'meta': '^1.16.0'},
    );

    final run = await report([], {'http': '1.5.0', 'meta': '1.17.0'});

    expect(run.exitCode, breakingUpdatesExitCode, reason: '$run');
    expect(run.output, contains('hiflutter_net'));
    expect(run.output, contains('http'));
    expect(run.output, contains('^0.13.0'));
    expect(run.output, contains('1.5.0'));
    expect(run.output, contains('https://pub.dev/packages/http/changelog'));
    expect(run.output, isNot(contains('meta')));
  });

  test('exits 0 when only workspace packages or the SDK are behind', () async {
    repo = await FixtureRepo.create(
      packages: ['hiflutter_base', 'hiflutter_net'],
    );
    repo.addPackage(
      'hiflutter_net',
      dependencies: {
        'hiflutter_base': '^0.1.0',
        'flutter': '\n    sdk: flutter',
      },
    );

    final run = await report([], {
      'hiflutter_base': '1.0.0',
      'flutter': '9.0.0',
    });

    expect(run.exitCode, 0, reason: '$run');
    expect(run.output, contains('No breaking updates'));
  });

  test('--markdown prints a table for the tracker issue', () async {
    repo = await FixtureRepo.create();
    repo.addPackage('hiflutter_base', dependencies: {'http': '^0.13.0'});

    final run = await report(['--markdown'], {'http': '1.5.0'});

    expect(run.exitCode, breakingUpdatesExitCode, reason: '$run');
    expect(
      run.output,
      contains(
        '| 所在包 | 依赖 | 类型 | 当前约束 | 最新版本 | 变更日志 |\n'
        '| --- | --- | --- | --- | --- | --- |\n'
        '| hiflutter_base | `http` | dependencies | `^0.13.0` | `1.5.0` | '
        '[changelog](https://pub.dev/packages/http/changelog) |\n',
      ),
    );
  });

  test('exits 1, not the breaking code, when pub outdated fails', () async {
    repo = await FixtureRepo.create();
    final err = StringBuffer();

    final code = await runDepsReport(
      ['--root', repo.root],
      out: StringBuffer(),
      err: err,
      outdated: (_) async => throw const ProcessException('dart', [], 'boom'),
    );

    expect(code, 1);
    expect('$err', contains('boom'));
  });

  test('exits 1 when pub outdated prints something other than JSON', () async {
    repo = await FixtureRepo.create();

    final code = await runDepsReport(
      ['--root', repo.root],
      out: StringBuffer(),
      err: StringBuffer(),
      outdated: (_) async => 'Resolving dependencies...',
    );

    expect(code, 1);
  });

  test('rejects asking for both --json and --markdown', () async {
    repo = await FixtureRepo.create();

    final run = await report(['--json', '--markdown'], {});

    expect(run.exitCode, 64, reason: '$run');
  });

  test('--json prints each breaking update as a record', () async {
    repo = await FixtureRepo.create();
    repo.write('packages/hiflutter_base/pubspec.yaml', '''
name: hiflutter_base
version: 0.1.0
environment:
  sdk: ^3.14.0
resolution: workspace
dev_dependencies:
  lints: ^5.0.0
''');

    final run = await report(['--json'], {'lints': '6.1.0'});

    expect(run.exitCode, breakingUpdatesExitCode, reason: '$run');
    expect(jsonDecode(run.output), {
      'breaking': [
        {
          'package': 'hiflutter_base',
          'dependency': 'lints',
          'constraint': '^5.0.0',
          'latest': '6.1.0',
          'dev': true,
          'changelog': 'https://pub.dev/packages/lints/changelog',
        },
      ],
    });
  });
}
