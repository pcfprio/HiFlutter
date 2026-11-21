import '../stage.dart';

/// Fails when any Dart file in the workspace is not `dart format`-clean.
class FormatStage implements CheckStage {
  @override
  String get id => 'format';

  @override
  String get title => 'dart format check';

  @override
  Future<StageResult> run(CheckContext context) async {
    final code = await context.exec('dart', [
      'format',
      '--output=none',
      '--set-exit-if-changed',
      '.',
    ]);
    return code == 0
        ? const StageResult.pass()
        : StageResult.fail([
            'Unformatted Dart files (see above). Run `dart format .`.',
          ]);
  }
}
