import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import 'workspace.dart';

/// Exit code of `tool/deps_report.dart` when at least one breaking update
/// is available. Zero means none; 1 means the report could not be made; 64
/// means bad usage.
const breakingUpdatesExitCode = 2;

/// Produces the `dart pub outdated --json` document of the workspace [root].
typedef OutdatedRunner = Future<String> Function(String root);

/// One direct dependency whose latest version leaves its constraint.
class BreakingUpdate {
  /// Creates a breaking update entry.
  BreakingUpdate({
    required this.package,
    required this.dependency,
    required this.constraint,
    required this.latest,
    required this.dev,
  });

  /// Workspace package declaring the dependency.
  final String package;

  /// Name of the dependency.
  final String dependency;

  /// Constraint the package declares, e.g. `^1.2.0`.
  final String constraint;

  /// Latest stable version on pub.dev.
  final String latest;

  /// Whether it is declared under `dev_dependencies`.
  final bool dev;

  /// pub.dev changelog page of the dependency.
  String get changelog => 'https://pub.dev/packages/$dependency/changelog';

  /// JSON form used by `--json`.
  Map<String, Object> toJson() => {
    'package': package,
    'dependency': dependency,
    'constraint': constraint,
    'latest': latest,
    'dev': dev,
    'changelog': changelog,
  };
}

/// Reports the workspace's breaking dependency updates; returns an exit code.
///
/// Usage: `dart run tool/deps_report.dart [--root <dir>] [--json|--markdown]`.
/// The report goes to [out]; progress and errors go to [err].
Future<int> runDepsReport(
  List<String> args, {
  StringSink? out,
  StringSink? err,
  OutdatedRunner? outdated,
}) async {
  final sink = out ?? stdout;
  final errors = err ?? stderr;
  const usage =
      'Usage: dart run tool/deps_report.dart [--root <dir>] '
      '[--json | --markdown]';
  final parser = ArgParser()
    ..addOption('root', help: 'Workspace root to report on.')
    ..addFlag('json', negatable: false, help: 'Print the report as JSON.')
    ..addFlag('markdown', negatable: false, help: 'Print it as Markdown.')
    ..addFlag('help', abbr: 'h', negatable: false);

  final ArgResults options;
  try {
    options = parser.parse(args);
  } on FormatException catch (e) {
    errors.writeln('${e.message}\n\n$usage\n${parser.usage}');
    return 64;
  }
  if (options.flag('help')) {
    sink.writeln(
      '$usage\n${parser.usage}\n\nExit codes: 0 none, '
      '$breakingUpdatesExitCode breaking updates found, 1 failure.',
    );
    return 0;
  }
  if (options.flag('json') && options.flag('markdown')) {
    errors.writeln('Pass at most one of --json and --markdown.\n\n$usage');
    return 64;
  }

  final root = p.normalize(
    p.absolute(options.option('root') ?? _defaultRoot()),
  );
  final packages = [WorkspacePackage.load(root, root), ...loadWorkspace(root)];

  final Map<String, Version> latest;
  try {
    final document = await (outdated ?? _runOutdated(packages, errors))(root);
    latest = _latestVersions(document);
  } on Exception catch (e) {
    errors.writeln('Could not read pub outdated results: $e');
    return 1;
  }

  final updates = breakingUpdates(packages, latest);
  if (options.flag('json')) {
    sink.writeln(
      const JsonEncoder.withIndent('  ').convert({
        'breaking': [for (final update in updates) update.toJson()],
      }),
    );
  } else if (options.flag('markdown')) {
    sink.write(_markdown(updates));
  } else {
    if (updates.isEmpty) sink.writeln('No breaking updates available.');
    for (final update in updates) {
      sink.writeln(
        '${update.package}: ${update.dependency} ${update.constraint} -> '
        '${update.latest} (${update.changelog})',
      );
    }
  }
  return updates.isEmpty ? 0 : breakingUpdatesExitCode;
}

/// Direct dependencies of [packages] whose [latest] version falls outside
/// the declared constraint.
List<BreakingUpdate> breakingUpdates(
  List<WorkspacePackage> packages,
  Map<String, Version> latest,
) {
  final members = {for (final pkg in packages) pkg.name};
  return [
    for (final pkg in packages)
      for (final (dev, deps) in [
        (false, pkg.dependencies),
        (true, pkg.devDependencies),
      ])
        for (final MapEntry(key: name, value: spec) in deps.entries)
          if (!members.contains(name))
            if ((spec, latest[name]) case (
              final String constraint,
              final Version newest,
            ))
              if (!VersionConstraint.parse(constraint).allows(newest))
                BreakingUpdate(
                  package: pkg.name,
                  dependency: name,
                  constraint: constraint,
                  latest: '$newest',
                  dev: dev,
                ),
  ];
}

/// The report as the body of the `deps-breaking` tracker issue.
String _markdown(List<BreakingUpdate> updates) {
  final text = StringBuffer('## 依赖破坏性更新报告\n\n');
  if (updates.isEmpty) {
    text.writeln('没有可做破坏性更新的直接依赖。');
    return '$text';
  }
  text
    ..writeln(
      '以下直接依赖的最新版本超出了当前约束。处理流程见 '
      '`docs/engineering/dependencies.md`：智能体评估影响并给出建议，'
      '由维护者决定是否升级。\n',
    )
    ..writeln('| 所在包 | 依赖 | 类型 | 当前约束 | 最新版本 | 变更日志 |')
    ..writeln('| --- | --- | --- | --- | --- | --- |');
  for (final u in updates) {
    text.writeln(
      '| ${u.package} | `${u.dependency}` | '
      '${u.dev ? 'dev_dependencies' : 'dependencies'} | `${u.constraint}` | '
      '`${u.latest}` | [changelog](${u.changelog}) |',
    );
  }
  return '$text';
}

Map<String, Version> _latestVersions(String document) {
  final json = jsonDecode(document);
  final entries = json is Map ? json['packages'] : null;
  return {
    if (entries is List)
      for (final entry in entries)
        if (entry case {
          'package': final String name,
          'latest': {'version': final String version},
        })
          name: Version.parse(version),
  };
}

OutdatedRunner _runOutdated(
  List<WorkspacePackage> packages,
  StringSink errors,
) => (root) async {
  final tool = packages.any((pkg) => pkg.isFlutter) ? 'flutter' : 'dart';
  const arguments = ['pub', 'outdated', '--json', '--no-prereleases'];
  errors.writeln('\$ $tool ${arguments.join(' ')}  (in $root)');
  final result = await Process.run(
    tool,
    arguments,
    workingDirectory: root,
    runInShell: Platform.isWindows,
  );
  if (result.exitCode != 0) {
    throw ProcessException(
      tool,
      arguments,
      '${result.stderr}'.trim(),
      result.exitCode,
    );
  }
  return result.stdout as String;
};

/// The repository containing this script (`tool/..`).
String _defaultRoot() => p.dirname(p.dirname(p.fromUri(Platform.script)));
