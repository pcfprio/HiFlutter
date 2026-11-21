import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'workspace.dart';

/// Moves every HiFlutter package to one version and returns an exit code.
///
/// Usage: `dart run tool/bump_version.dart [--root <dir>] <version>`.
///
/// For every workspace member it rewrites constraints on other members to
/// `^<version>`; for every publishable member it also sets `version`.
Future<int> runBumpVersion(List<String> args, {StringSink? out}) async {
  final sink = out ?? stdout;
  const usage =
      'Usage: dart run tool/bump_version.dart [--root <dir>] <version>';
  final parser = ArgParser()
    ..addOption('root', help: 'Workspace root to bump.')
    ..addFlag('help', abbr: 'h', negatable: false);

  final ArgResults options;
  try {
    options = parser.parse(args);
  } on FormatException catch (e) {
    sink.writeln('${e.message}\n\n$usage\n${parser.usage}');
    return 64;
  }
  if (options.flag('help')) {
    sink.writeln('$usage\n${parser.usage}');
    return 0;
  }
  if (options.rest.length != 1) {
    sink.writeln('Expected exactly one version.\n\n$usage');
    return 64;
  }
  final Version version;
  try {
    version = Version.parse(options.rest.single);
  } on FormatException {
    sink.writeln('Not a semantic version: "${options.rest.single}"');
    return 64;
  }

  final root = p.normalize(
    p.absolute(options.option('root') ?? _defaultRoot()),
  );
  final packages = loadWorkspace(root);
  final names = {for (final pkg in packages) pkg.name};

  final stale = [
    for (final pkg in packages)
      if (pkg.publishable && pkg.version != null)
        if (Version.parse(pkg.version!) case final current
            when current >= version)
          '${pkg.name} is already at $current',
  ];
  if (stale.isNotEmpty) {
    sink.writeln('Version $version does not move forward:');
    for (final line in stale) {
      sink.writeln('  - $line');
    }
    return 1;
  }

  for (final pkg in packages) {
    final file = File(p.join(pkg.dir, 'pubspec.yaml'));
    final editor = YamlEditor(file.readAsStringSync());
    if (pkg.publishable) editor.update(['version'], '$version');
    for (final (section, deps) in [
      ('dependencies', pkg.dependencies),
      ('dev_dependencies', pkg.devDependencies),
    ]) {
      for (final dep in deps.keys.where(names.contains)) {
        editor.update([section, dep], '^$version');
      }
    }
    file.writeAsStringSync(editor.toString());
    if (pkg.publishable) _addChangelogHeader(pkg.dir, version);
    sink.writeln(
      '${pkg.name}: ${pkg.publishable ? '$version' : 'constraints'}',
    );
  }
  sink.writeln('Bumped ${packages.length} package(s) to $version.');
  return 0;
}

/// Entry written for a package that changed nothing in this release.
const alignedEntry = '- 版本对齐，无变化';

/// Header of the section collecting changes not yet in a release.
final _unreleased = RegExp(r'^## Unreleased[ \t]*$', multiLine: true);

/// Turns `## Unreleased` into `## <version>`, or prepends a `## <version>`
/// section with [alignedEntry] when the package has no unreleased changes.
void _addChangelogHeader(String dir, Version version) {
  final file = File(p.join(dir, 'CHANGELOG.md'));
  final text = file.existsSync() ? file.readAsStringSync() : '';
  file.writeAsStringSync(
    _unreleased.hasMatch(text)
        ? text.replaceFirst(_unreleased, '## $version')
        : '## $version\n\n$alignedEntry\n\n$text',
  );
}

/// The repository containing this script (`tool/..`).
String _defaultRoot() => p.dirname(p.dirname(p.fromUri(Platform.script)));
