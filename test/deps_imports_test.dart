import 'package:test/test.dart';

import 'support/fixture_repo.dart';

void main() {
  group('deps stage import guards', () {
    late FixtureRepo repo;

    tearDown(() => repo.dispose());

    test(
      'fails when a workspace member imports or exports material.dart',
      () async {
        repo = await FixtureRepo.create(packages: ['hiflutter_core']);
        repo.write(
          'packages/hiflutter_core/lib/widget.dart',
          "import 'package:flutter/widgets.dart';\n"
              "import 'package:flutter/material.dart';\n",
        );
        repo.write(
          'packages/hiflutter_core/test/widget_test.dart',
          '  export "package:flutter/material.dart";\n',
        );
        repo.write(
          'packages/hiflutter_core/example/main.dart',
          "import 'package:flutter/material.dart' show Colors;\n",
        );
        repo.write(
          'packages/hiflutter_core/bin/cli.dart',
          "import 'package:flutter/material.dart';\n",
        );

        final run = await repo.check(['--only', 'deps']);

        expect(run.exitCode, isNot(0), reason: '$run');
        expect(run.output, contains('FAIL deps'));
        expect(
          run.output,
          contains('packages/hiflutter_core/lib/widget.dart:2'),
        );
        expect(
          run.output,
          contains('packages/hiflutter_core/test/widget_test.dart:1'),
        );
        expect(
          run.output,
          contains('packages/hiflutter_core/example/main.dart:1'),
        );
        expect(run.output, contains('packages/hiflutter_core/bin/cli.dart:1'));
      },
    );

    test(
      'fails when a workspace member test imports or exports internal src/',
      () async {
        repo = await FixtureRepo.create(
          packages: ['hiflutter_base', 'hiflutter_net'],
        );
        repo.write(
          'packages/hiflutter_net/test/net_test.dart',
          "import 'package:hiflutter_net/hiflutter_net.dart';\n"
              "import 'package:hiflutter_net/src/client.dart';\n",
        );
        repo.write(
          'packages/hiflutter_net/test/relative_test.dart',
          "import '../lib/src/internal.dart';\n",
        );
        repo.write(
          'packages/hiflutter_net/test/export_test.dart',
          '  export "package:hiflutter/src/umbrella.dart";\n',
        );

        final run = await repo.check(['--only', 'deps']);

        expect(run.exitCode, isNot(0), reason: '$run');
        expect(run.output, contains('FAIL deps'));
        expect(
          run.output,
          contains('packages/hiflutter_net/test/net_test.dart:2'),
        );
        expect(
          run.output,
          contains('packages/hiflutter_net/test/relative_test.dart:1'),
        );
        expect(
          run.output,
          contains('packages/hiflutter_net/test/export_test.dart:1'),
        );
      },
    );

    test('scans publish_to: none members and nested directories', () async {
      repo = await FixtureRepo.create(packages: ['hiflutter_base']);
      repo.write('pubspec.yaml', '''
name: fixture_workspace
publish_to: none
environment:
  sdk: ^3.14.0
workspace:
  - apps/showcase
  - packages/hiflutter_base
''');
      repo.write('apps/showcase/pubspec.yaml', '''
name: hiflutter_showcase
publish_to: none
version: 0.1.0+1
environment:
  sdk: ^3.14.0
resolution: workspace
dependencies:
  hiflutter_base: ^0.1.0
''');
      repo.write(
        'apps/showcase/lib/screens/home.dart',
        "import 'package:flutter/material.dart';\n",
      );
      repo.write(
        'apps/showcase/test/screens/home_test.dart',
        "import 'package:hiflutter_base/src/secret.dart';\n"
            "import '../../lib/src/local.dart';\n",
      );

      final run = await repo.check(['--only', 'deps']);

      expect(run.exitCode, isNot(0), reason: '$run');
      expect(run.output, contains('apps/showcase/lib/screens/home.dart:1'));
      expect(
        run.output,
        contains('apps/showcase/test/screens/home_test.dart:1'),
      );
      expect(
        run.output,
        contains('apps/showcase/test/screens/home_test.dart:2'),
      );
    });

    test(
      'allows public entrypoints, lib src imports, comments, and root tests',
      () async {
        repo = await FixtureRepo.create(
          packages: ['hiflutter_base', 'hiflutter_core', 'hiflutter_suite'],
        );
        repo.addPackage(
          'hiflutter_core',
          dependencies: {
            'hiflutter_base': '^0.1.0',
            'flutter': '\n    sdk: flutter',
          },
        );
        repo.addPackage(
          'hiflutter_suite',
          dependencies: {
            'hiflutter_base': '^0.1.0',
            'hiflutter_core': '^0.1.0',
            'flutter': '\n    sdk: flutter',
            'material_ui': '^1.11.1',
          },
        );
        repo.write(
          'packages/hiflutter_core/lib/hiflutter_core.dart',
          "export 'src/core.dart';\n",
        );
        repo.write(
          'packages/hiflutter_core/lib/src/core.dart',
          "import 'package:flutter/widgets.dart';\n"
              "import 'package:hiflutter_core/src/helper.dart';\n"
              "// import 'package:flutter/material.dart';\n"
              'const note = "import \'package:flutter/material.dart\'";\n',
        );
        repo.write(
          'packages/hiflutter_suite/lib/button.dart',
          "import 'package:material_ui/material_ui.dart';\n",
        );
        repo.write(
          'packages/hiflutter_core/test/core_test.dart',
          "import 'package:hiflutter_core/hiflutter_core.dart';\n"
              "// import 'package:hiflutter_core/src/core.dart';\n",
        );
        repo.write(
          'test/tool_test.dart',
          "import '../tool/src/stages.dart';\n"
              "import '../tool/src/stages/deps_stage.dart';\n",
        );

        final run = await repo.check(['--only', 'deps']);

        expect(run.exitCode, 0, reason: '$run');
      },
    );
  });
}
