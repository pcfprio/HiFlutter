import 'dart:convert';
import 'dart:io';

/// One step of `tool/check.dart`.
///
/// Stages run in order; the first failing stage stops the run. To add a stage
/// (for example the end-to-end rehearsal or `--build`), implement this class
/// and register it in `tool/src/stages.dart`.
abstract class CheckStage {
  /// Short, stable identifier used by `--only` and in PASS/FAIL lines.
  String get id;

  /// Human-readable description printed in the stage header.
  String get title;

  /// Runs the stage against [context] and reports the outcome.
  Future<StageResult> run(CheckContext context);
}

/// Outcome of a [CheckStage].
class StageResult {
  /// A passing result.
  const StageResult.pass() : problems = const [];

  /// A failing result listing what is wrong; [problems] must not be empty.
  StageResult.fail(this.problems) : assert(problems.isNotEmpty);

  /// Collapses [problems] into a pass when empty and a failure otherwise.
  factory StageResult.of(List<String> problems) =>
      problems.isEmpty ? const StageResult.pass() : StageResult.fail(problems);

  /// What is wrong; empty when the stage passed.
  final List<String> problems;

  /// Whether the stage passed.
  bool get passed => problems.isEmpty;
}

/// Shared environment handed to every stage.
class CheckContext {
  /// Creates a context rooted at the workspace directory [root].
  CheckContext({required this.root, required this.out});

  /// Absolute path of the workspace root.
  final String root;

  /// Where stage output goes.
  final StringSink out;

  /// Runs [executable] with [arguments], streaming its output to [out], and
  /// returns its exit code.
  Future<int> exec(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    final dir = workingDirectory ?? root;
    out.writeln('    \$ $executable ${arguments.join(' ')}  (in $dir)');
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: dir,
      runInShell: Platform.isWindows,
    );
    Future<void> forward(Stream<List<int>> stream) => stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) => out.writeln('      $line'));
    final done = Future.wait<void>([
      forward(process.stdout),
      forward(process.stderr),
    ]);
    final code = await process.exitCode;
    await done;
    return code;
  }
}
