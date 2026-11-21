/// Internal error signaling an expected CLI failure with a non-zero exit code.
class ToolFailure implements Exception {
  /// Creates a failure with a user-facing [message] and process [exitCode].
  ToolFailure(this.message, [this.exitCode = 1]);

  /// Human-readable error message printed to stderr.
  final String message;

  /// Process exit code to return (`1` by default).
  final int exitCode;
}
