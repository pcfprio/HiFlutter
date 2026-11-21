/// Command-line tooling for HiFlutter consumer projects.
///
/// Use [HiToolRunner] to switch a consumer project's `pubspec_overrides.yaml`
/// between [HiIntegrationMode.source], [HiIntegrationMode.pin], and
/// [HiIntegrationMode.hosted], and to verify release readiness via `check`.
library;

export 'src/tool_runner.dart' show HiIntegrationMode, HiToolRunner;
