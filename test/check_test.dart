import 'package:test/test.dart';

import 'support/fixture_repo.dart';

void main() {
  late FixtureRepo repo;

  tearDown(() => repo.dispose());

  test('runs the Spec stages in order', () async {
    repo = await FixtureRepo.create();

    final run = await repo.check(['--help']);

    expect(
      run.output,
      contains(
        'Stages: format, analyze, test, deps, terms, versions, publish, e2e',
      ),
    );
  });

  test('e2e stage fails cleanly when hiflutter_net is absent', () async {
    repo = await FixtureRepo.create(packages: ['hiflutter_base']);

    final run = await repo.check(['--only', 'e2e']);

    expect(run.exitCode, isNot(0), reason: '$run');
    expect(run.output, contains('FAIL e2e'));
    expect(run.output, contains('hiflutter_net'));
  });

  test('rejects an unknown stage id', () async {
    repo = await FixtureRepo.create();

    final run = await repo.check(['--only', 'nope']);

    expect(run.exitCode, 64);
    expect(run.output, contains('Unknown stage(s): nope'));
  });

  group('format stage', () {
    test('passes on a formatted workspace', () async {
      repo = await FixtureRepo.create();

      final run = await repo.check(['--only', 'format']);

      expect(run.exitCode, 0, reason: '$run');
    });

    test('fails when a Dart file is not formatted', () async {
      repo = await FixtureRepo.create();
      repo.write('packages/hiflutter_base/lib/ugly.dart', 'int   x(  )=>1;\n');

      final run = await repo.check(['--only', 'format']);

      expect(run.exitCode, isNot(0), reason: '$run');
      expect(run.output, contains('FAIL format'));
    });
  });

  group('versions stage', () {
    test('passes when every package shares one version', () async {
      repo = await FixtureRepo.create(
        packages: ['hiflutter_base', 'hiflutter_net'],
      );

      final run = await repo.check(['--only', 'versions']);

      expect(run.exitCode, 0, reason: '$run');
    });

    test('fails when packages have different versions', () async {
      repo = await FixtureRepo.create(
        packages: ['hiflutter_base', 'hiflutter_net'],
      );
      repo.addPackage('hiflutter_net', version: '0.2.0');

      final run = await repo.check(['--only', 'versions']);

      expect(run.exitCode, isNot(0), reason: '$run');
      expect(run.output, contains('FAIL versions'));
      expect(run.output, contains('hiflutter_net'));
    });

    test('fails when an inter-package constraint is not ^version', () async {
      repo = await FixtureRepo.create(
        packages: ['hiflutter_base', 'hiflutter_net'],
      );
      repo.addPackage(
        'hiflutter_net',
        dependencies: {'hiflutter_base': '^0.0.9'},
      );

      final run = await repo.check(['--only', 'versions']);

      expect(run.exitCode, isNot(0), reason: '$run');
      expect(run.output, contains('hiflutter_net -> hiflutter_base'));
    });

    test('fails when a CHANGELOG lacks the current version header', () async {
      repo = await FixtureRepo.create();
      repo.addPackage('hiflutter_base', changelog: '## 0.0.1\n\n- Old.\n');

      final run = await repo.check(['--only', 'versions']);

      expect(run.exitCode, isNot(0), reason: '$run');
      expect(run.output, contains('CHANGELOG'));
    });
  });

  group('deps stage', () {
    test('passes for dependencies allowed by the package table', () async {
      repo = await FixtureRepo.create(
        packages: ['hiflutter_base', 'hiflutter_net'],
      );
      repo.addPackage(
        'hiflutter_net',
        dependencies: {'hiflutter_base': '^0.1.0', 'meta': '^1.16.0'},
      );

      final run = await repo.check(['--only', 'deps']);

      expect(run.exitCode, 0, reason: '$run');
    });

    test('fails for a dependency direction the table forbids', () async {
      repo = await FixtureRepo.create(
        packages: ['hiflutter_base', 'hiflutter_net', 'hiflutter_store'],
      );
      repo.addPackage(
        'hiflutter_net',
        dependencies: {'hiflutter_store': '^0.1.0'},
      );

      final run = await repo.check(['--only', 'deps']);

      expect(run.exitCode, isNot(0), reason: '$run');
      expect(run.output, contains('FAIL deps'));
      expect(run.output, contains('hiflutter_net -> hiflutter_store'));
    });

    test('fails when a contract package depends on a third party', () async {
      repo = await FixtureRepo.create();
      repo.addPackage('hiflutter_base', dependencies: {'http': '^1.5.0'});

      final run = await repo.check(['--only', 'deps']);

      expect(run.exitCode, isNot(0), reason: '$run');
      expect(run.output, contains('hiflutter_base -> http'));
    });

    test('lets Flutter contracts, not pure Dart ones, use the SDK', () async {
      repo = await FixtureRepo.create(
        packages: ['hiflutter_base', 'hiflutter_core'],
      );
      const flutterSdk = '\n    sdk: flutter';
      repo.addPackage('hiflutter_core', dependencies: {'flutter': flutterSdk});

      expect((await repo.check(['--only', 'deps'])).exitCode, 0);

      repo.addPackage('hiflutter_base', dependencies: {'flutter': flutterSdk});
      final run = await repo.check(['--only', 'deps']);

      expect(run.exitCode, isNot(0), reason: '$run');
      expect(run.output, contains('hiflutter_base -> flutter'));
    });

    test('fails for a package missing from the table', () async {
      repo = await FixtureRepo.create(packages: ['hiflutter_extra']);

      final run = await repo.check(['--only', 'deps']);

      expect(run.exitCode, isNot(0), reason: '$run');
      expect(run.output, contains('hiflutter_extra'));
    });

    test('reports dependency cycles', () async {
      repo = await FixtureRepo.create(
        packages: ['hiflutter_base', 'hiflutter_net'],
      );
      repo.addPackage(
        'hiflutter_base',
        dependencies: {'hiflutter_net': '^0.1.0'},
      );
      repo.addPackage(
        'hiflutter_net',
        dependencies: {'hiflutter_base': '^0.1.0'},
      );

      final run = await repo.check(['--only', 'deps']);

      expect(run.exitCode, isNot(0), reason: '$run');
      expect(run.output, contains('dependency cycle: hiflutter_base'));
    });
  });

  group('terms stage', () {
    final term = businessTerms().first;

    test('passes when no business term appears', () async {
      repo = await FixtureRepo.create();

      final run = await repo.check(['--only', 'terms']);

      expect(run.exitCode, 0, reason: '$run');
    });

    test('fails on a business term in any letter case', () async {
      repo = await FixtureRepo.create();
      repo.write(
        'packages/hiflutter_base/README.md',
        'Built for ${term.toLowerCase()}.\n',
      );

      final run = await repo.check(['--only', 'terms']);

      expect(run.exitCode, isNot(0), reason: '$run');
      expect(run.output, contains('FAIL terms'));
      expect(run.output, contains('packages/hiflutter_base/README.md:1'));
    });

    test('fails on a business term in a file path', () async {
      repo = await FixtureRepo.create();
      repo.write('docs/${term.toUpperCase()}.md', 'Nothing here.\n');

      final run = await repo.check(['--only', 'terms']);

      expect(run.exitCode, isNot(0), reason: '$run');
      expect(run.output, contains('docs/${term.toUpperCase()}.md'));
    });
  });
}
