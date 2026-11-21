import 'stage.dart';
import 'stages/command_stages.dart';
import 'stages/deps_stage.dart';
import 'stages/e2e_stage.dart';
import 'stages/format_stage.dart';
import 'stages/terms_stage.dart';
import 'stages/versions_stage.dart';

/// The stages `tool/check.dart` runs, in order (Spec #2, "总检查").
///
/// Later tickets append stages here (`--build`).
List<CheckStage> defaultStages() => [
  FormatStage(),
  AnalyzeStage(),
  TestStage(),
  DepsStage(),
  TermsStage(),
  VersionsStage(),
  PublishStage(),
  E2eStage(),
];
