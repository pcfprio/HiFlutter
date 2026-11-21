import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'git_client.dart';
import 'lockfile.dart';
import 'overrides_file.dart';
import 'package_graph.dart';
import 'tool_failure.dart';

/// Integration mode used by a HiFlutter consumer project.
enum HiIntegrationMode {
  /// Reads packages directly from a sibling HiFlutter checkout via path overrides.
  source,

  /// Pins packages to a specific git tag via git overrides.
  pin,

  /// Uses published packages from pub.dev with no HiFlutter overrides.
  hosted,
}

/// Runs the `hiflutter` command-line tool and returns a process exit code.
///
/// Supports `mode source`, `mode pin <tag>`, `mode hosted`, and `check`.
final class HiToolRunner {
  /// Default upstream git URL used when pinning without `--git-url`.
  static const defaultGitUrl = 'https://github.com/pcfprio/HiFlutter.git';

  /// Creates a runner with optional overrides for output, error output,
  /// working directory, and environment variables.
  HiToolRunner({
    StringSink? out,
    StringSink? err,
    String? workingDirectory,
    Map<String, String>? environment,
  }) : _out = out ?? stdout,
       _err = err ?? stderr,
       _workingDirectory = workingDirectory ?? Directory.current.path,
       _environment = environment ?? Platform.environment;

  final StringSink _out;
  final StringSink _err;
  final String _workingDirectory;
  final Map<String, String> _environment;

  /// Parses [args], executes the requested subcommand, and returns an exit code.
  Future<int> run(List<String> args) async {
    final parser = _buildParser();
    final ArgResults top;
    try {
      top = parser.parse(args);
    } on FormatException catch (e) {
      _err.writeln(e.message);
      _printRootUsage(parser, toErr: true);
      return 64;
    }

    if (top.flag('help') || (top.command == null && top.rest.isEmpty)) {
      _printRootUsage(parser);
      return 0;
    }

    final command = top.command;
    if (command == null) {
      _err.writeln('Unknown command: ${top.rest.join(' ')}');
      _printRootUsage(parser, toErr: true);
      return 64;
    }

    try {
      return switch (command.name) {
        'mode' => await _runModeCommand(parser, command),
        'check' => await _runCheck(parser.commands['check']!, command),
        _ => throw ToolFailure('Unknown command: ${command.name}', 64),
      };
    } on ToolFailure catch (e) {
      _err.writeln(e.message);
      return e.exitCode;
    }
  }

  ArgParser _buildParser() {
    final sourceParser = ArgParser()
      ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage.')
      ..addOption(
        'project-dir',
        abbr: 'p',
        help: 'Consumer project directory (defaults to current directory).',
      )
      ..addOption(
        'hiflutter-dir',
        help: 'HiFlutter checkout directory (defaults to \$HIFLUTTER_DIR or ../HiFlutter).',
      );

    final pinParser = ArgParser()
      ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage.')
      ..addOption(
        'project-dir',
        abbr: 'p',
        help: 'Consumer project directory (defaults to current directory).',
      )
      ..addOption(
        'git-url',
        defaultsTo: defaultGitUrl,
        help: 'Git repository URL or path to pin against.',
      );

    final hostedParser = ArgParser()
      ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage.')
      ..addOption(
        'project-dir',
        abbr: 'p',
        help: 'Consumer project directory (defaults to current directory).',
      );

    final modeParser = ArgParser()
      ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage.')
      ..addCommand('source', sourceParser)
      ..addCommand('pin', pinParser)
      ..addCommand('hosted', hostedParser);

    final checkParser = ArgParser()
      ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage.')
      ..addFlag(
        'release',
        negatable: false,
        help: 'Enforce release-readiness checks (forbids source mode).',
      )
      ..addOption(
        'project-dir',
        abbr: 'p',
        help: 'Consumer project directory (defaults to current directory).',
      )
      ..addOption(
        'hiflutter-dir',
        help: 'HiFlutter checkout directory for source mode checks.',
      );

    return ArgParser()
      ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage.')
      ..addCommand('mode', modeParser)
      ..addCommand('check', checkParser);
  }

  Future<int> _runModeCommand(ArgParser rootParser, ArgResults modeArgs) async {
    final modeParser = rootParser.commands['mode']!;
    if (modeArgs.flag('help') ||
        (modeArgs.command == null && modeArgs.rest.isEmpty)) {
      _printModeUsage(modeParser);
      return 0;
    }
    final sub = modeArgs.command;
    if (sub == null) {
      _err.writeln('Unknown mode subcommand: ${modeArgs.rest.join(' ')}');
      _printModeUsage(modeParser, toErr: true);
      return 64;
    }

    final subParser = modeParser.commands[sub.name]!;
    if (sub.flag('help')) {
      _out.writeln('Usage: hiflutter mode ${sub.name} [options]');
      _out.writeln(subParser.usage);
      return 0;
    }

    return switch (sub.name) {
      'source' => _runModeSource(subParser, sub),
      'pin' => await _runModePin(subParser, sub),
      'hosted' => _runModeHosted(subParser, sub),
      _ => 64,
    };
  }

  int _runModeSource(ArgParser parser, ArgResults args) {
    if (args.rest.isNotEmpty) {
      _err.writeln('Unexpected argument(s): ${args.rest.join(' ')}');
      _err.writeln('Usage: hiflutter mode source [options]\n${parser.usage}');
      return 64;
    }
    final projectDir = _resolveProjectDir(args.option('project-dir'));
    final hiFlutterDir = resolveHiFlutterDir(
      flagDir: args.option('hiflutter-dir'),
      environment: _environment,
      workingDirectory: _workingDirectory,
      projectDir: projectDir,
    );

    final closure = _resolveClosureForRepo(
      projectDir: projectDir,
      repoDir: hiFlutterDir,
    );
    final entries = <String, Map<String, Object?>>{
      for (final pkg in closure)
        pkg.name: {'path': toPosixPath(p.relative(pkg.dir, from: projectDir))},
    };
    writeManagedOverrides(
      projectDir: projectDir,
      modeHeaderLine: sourceModeHeader(),
      managedEntries: entries,
    );
    _out.writeln(
      'Switched to source mode (${closure.length} package(s)) '
      'using $hiFlutterDir.',
    );
    return 0;
  }

  Future<int> _runModePin(ArgParser parser, ArgResults args) async {
    if (args.rest.length != 1) {
      _err.writeln('Expected exactly one <tag> argument.');
      _err.writeln(
        'Usage: hiflutter mode pin <tag> [options]\n${parser.usage}',
      );
      return 64;
    }
    final tag = args.rest.single.trim();
    if (tag.isEmpty) {
      _err.writeln('Tag must not be empty.');
      return 64;
    }

    final projectDir = _resolveProjectDir(args.option('project-dir'));
    final directDeps = _requireConsumerHiFlutterDeps(projectDir);
    final gitUrl = normalizeGitUrl(
      args.option('git-url') ?? defaultGitUrl,
      _workingDirectory,
    );

    final tempRoot = await Directory.systemTemp.createTemp('hiflutter_pin_');
    try {
      final cloneDir = p.join(tempRoot.path, 'repo');
      await shallowCloneTag(url: gitUrl, tag: tag, destinationDir: cloneDir);
      final catalog = scanHiFlutterPackages(cloneDir);
      final closure = computeClosure(catalog, directDeps);
      final entries = <String, Map<String, Object?>>{
        for (final pkg in closure)
          pkg.name: {
            'git': {
              'url': gitUrl,
              'ref': tag,
              if (pkg.repoRelativePosixPath != '.')
                'path': pkg.repoRelativePosixPath,
            },
          },
      };
      writeManagedOverrides(
        projectDir: projectDir,
        modeHeaderLine: pinModeHeader(tag, gitUrl),
        managedEntries: entries,
      );
      _out.writeln(
        'Switched to pin mode (${closure.length} package(s)) '
        'at tag $tag ($gitUrl).',
      );
      return 0;
    } finally {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    }
  }

  int _runModeHosted(ArgParser parser, ArgResults args) {
    if (args.rest.isNotEmpty) {
      _err.writeln('Unexpected argument(s): ${args.rest.join(' ')}');
      _err.writeln('Usage: hiflutter mode hosted [options]\n${parser.usage}');
      return 64;
    }
    final projectDir = _resolveProjectDir(args.option('project-dir'));
    _assertProjectPubspecExists(projectDir);
    final changed = removeManagedOverrides(projectDir);
    _out.writeln(
      changed
          ? 'Switched to hosted mode (removed HiFlutter overrides).'
          : 'Already in hosted mode (no pubspec_overrides.yaml).',
    );
    return 0;
  }

  Future<int> _runCheck(ArgParser parser, ArgResults args) async {
    if (args.flag('help')) {
      _out.writeln('Usage: hiflutter check [options]');
      _out.writeln(parser.usage);
      return 0;
    }
    if (args.rest.isNotEmpty) {
      _err.writeln('Unexpected argument(s): ${args.rest.join(' ')}');
      _err.writeln('Usage: hiflutter check [options]\n${parser.usage}');
      return 64;
    }

    final projectDir = _resolveProjectDir(args.option('project-dir'));
    _assertProjectPubspecExists(projectDir);
    final release = args.flag('release');
    final state = inspectOverrides(projectDir);

    switch (state) {
      case HostedModeState():
        _out.writeln('Mode: hosted');
        return 0;

      case SourceModeState():
        _out.writeln('Mode: source');
        final hiFlutterDir = resolveHiFlutterDir(
          flagDir: args.option('hiflutter-dir'),
          environment: _environment,
          workingDirectory: _workingDirectory,
          projectDir: projectDir,
        );
        final dirty = await isWorkingTreeDirty(hiFlutterDir);
        _out.writeln(
          'HiFlutter checkout ($hiFlutterDir): ${dirty ? 'dirty' : 'clean'}',
        );
        if (release) {
          _err.writeln(
            'Release check failed: source mode cannot be used for release '
            'builds. Switch to "pin <tag>" or "hosted" mode first.',
          );
          return 1;
        }
        return 0;

      case PinModeState(:final tag, :final url, :final managedPackages):
        _out.writeln('Mode: pin (tag: $tag, url: $url)');
        final expectedSha = await resolveRemoteTagSha(url: url, tag: tag);
        assertPinnedLockfile(
          projectDir: projectDir,
          tag: tag,
          expectedSha: expectedSha,
          managedPackages: managedPackages,
        );
        _out.writeln(
          'Verified ${managedPackages.length} pinned package(s) '
          'at $expectedSha.',
        );
        return 0;
    }
  }

  String _resolveProjectDir(String? rawDir) {
    final trimmed = rawDir?.trim();
    final resolved = (trimmed != null && trimmed.isNotEmpty)
        ? p.normalize(p.absolute(_workingDirectory, trimmed))
        : p.normalize(p.absolute(_workingDirectory));
    if (!Directory(resolved).existsSync()) {
      throw ToolFailure('Project directory does not exist: $resolved');
    }
    return resolved;
  }

  void _assertProjectPubspecExists(String projectDir) {
    if (!File(p.join(projectDir, 'pubspec.yaml')).existsSync()) {
      throw ToolFailure('Missing pubspec.yaml in $projectDir.');
    }
  }

  List<String> _requireConsumerHiFlutterDeps(String projectDir) {
    final directDeps = readConsumerHiFlutterDeps(projectDir);
    if (directDeps.isEmpty) {
      throw ToolFailure(
        'No hiflutter or hiflutter_* dependencies declared in '
        '${p.join(projectDir, 'pubspec.yaml')}.',
      );
    }
    return directDeps;
  }

  List<HiRepoPackage> _resolveClosureForRepo({
    required String projectDir,
    required String repoDir,
  }) {
    final directDeps = _requireConsumerHiFlutterDeps(projectDir);
    final catalog = scanHiFlutterPackages(repoDir);
    return computeClosure(catalog, directDeps);
  }

  void _printRootUsage(ArgParser parser, {bool toErr = false}) {
    final sink = toErr ? _err : _out;
    sink
      ..writeln('Usage: hiflutter <command> [options]')
      ..writeln('')
      ..writeln('Commands:')
      ..writeln('  mode <source|pin|hosted>  Switch integration mode.')
      ..writeln('  check [--release]         Verify active mode and lockfile.')
      ..writeln('')
      ..writeln(parser.usage);
  }

  void _printModeUsage(ArgParser modeParser, {bool toErr = false}) {
    final sink = toErr ? _err : _out;
    sink
      ..writeln('Usage: hiflutter mode <source|pin|hosted> [options]')
      ..writeln('')
      ..writeln('Subcommands:')
      ..writeln('  source    Point overrides to a sibling HiFlutter checkout.')
      ..writeln('  pin       Pin overrides to a specific git tag.')
      ..writeln('  hosted    Remove HiFlutter overrides and use pub.dev.')
      ..writeln('')
      ..writeln(modeParser.usage);
  }
}
