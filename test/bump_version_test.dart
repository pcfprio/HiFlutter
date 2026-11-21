import 'package:test/test.dart';

import 'support/fixture_repo.dart';

void main() {
  late FixtureRepo repo;

  tearDown(() => repo.dispose());

  test(
    'moves every package and inter-package constraint to the version',
    () async {
      repo = await FixtureRepo.create(
        packages: ['hiflutter_base', 'hiflutter_net'],
      );
      repo.addPackage(
        'hiflutter_net',
        dependencies: {'hiflutter_base': '^0.1.0', 'meta': '^1.16.0'},
      );

      final run = await repo.bumpVersion(['0.2.0']);

      expect(run.exitCode, 0, reason: '$run');
      final net = repo.read('packages/hiflutter_net/pubspec.yaml');
      expect(net, contains('version: 0.2.0'));
      expect(net, contains('hiflutter_base: ^0.2.0'));
      expect(net, contains('meta: ^1.16.0'));
      expect(
        repo.read('packages/hiflutter_base/pubspec.yaml'),
        contains('version: 0.2.0'),
      );
      final check = await repo.check(['--only', 'versions']);
      expect(check.exitCode, 0, reason: '$check');
    },
  );

  test(
    'releases Unreleased entries and aligns packages without changes',
    () async {
      repo = await FixtureRepo.create(
        packages: ['hiflutter_base', 'hiflutter_net'],
      );
      repo.addPackage(
        'hiflutter_base',
        changelog: '## Unreleased\n\n- Add retry.\n\n## 0.1.0\n\n- Initial.\n',
      );

      final run = await repo.bumpVersion(['0.2.0']);

      expect(run.exitCode, 0, reason: '$run');
      expect(
        repo.read('packages/hiflutter_base/CHANGELOG.md'),
        '## 0.2.0\n\n- Add retry.\n\n## 0.1.0\n\n- Initial.\n',
      );
      expect(
        repo.read('packages/hiflutter_net/CHANGELOG.md'),
        '## 0.2.0\n\n- 版本对齐，无变化\n\n## 0.1.0\n\n- Fixture.\n',
      );
    },
  );

  test('updates constraints, not version, of unpublished members', () async {
    repo = await FixtureRepo.create();
    repo.write('pubspec.yaml', '''
name: fixture_workspace
publish_to: none
environment:
  sdk: ^3.14.0
workspace:
  - packages/hiflutter_base
  - apps/showcase
''');
    repo.write('apps/showcase/pubspec.yaml', '''
name: showcase
publish_to: none
version: 1.0.0+1
environment:
  sdk: ^3.14.0
resolution: workspace
dependencies:
  hiflutter_base: ^0.1.0
''');

    final run = await repo.bumpVersion(['0.2.0']);

    expect(run.exitCode, 0, reason: '$run');
    final showcase = repo.read('apps/showcase/pubspec.yaml');
    expect(showcase, contains('hiflutter_base: ^0.2.0'));
    expect(showcase, contains('version: 1.0.0+1'));
  });

  test('rejects a malformed version without touching files', () async {
    repo = await FixtureRepo.create();
    final before = repo.read('packages/hiflutter_base/pubspec.yaml');

    final run = await repo.bumpVersion(['v0.2']);

    expect(run.exitCode, 64, reason: '$run');
    expect(run.output, contains('v0.2'));
    expect(repo.read('packages/hiflutter_base/pubspec.yaml'), before);
  });

  test('refuses a version that does not move forward', () async {
    repo = await FixtureRepo.create(version: '0.2.0');
    final before = repo.read('packages/hiflutter_base/CHANGELOG.md');

    final run = await repo.bumpVersion(['0.2.0']);

    expect(run.exitCode, 1, reason: '$run');
    expect(run.output, contains('hiflutter_base is already at 0.2.0'));
    expect(repo.read('packages/hiflutter_base/CHANGELOG.md'), before);
  });
}
