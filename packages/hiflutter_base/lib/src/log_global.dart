import 'log.dart';

/// The global log entry (ADR-0005), so that any layer can log without a
/// [HiLogger] being passed down.
///
/// The composition root calls [install] once at startup; the installed
/// logger cannot be replaced afterwards. Until then every call does nothing
/// and the message closure never runs.
abstract final class HiLog {
  static HiLogger? _logger;

  /// Whether [install] has been called.
  static bool get isInstalled => _logger != null;

  /// Makes [logger] the global logger.
  ///
  /// Throws a [StateError] if a logger is already installed.
  static void install(HiLogger logger) {
    if (_logger != null) {
      throw StateError('HiLog is already installed and cannot be replaced.');
    }
    _logger = logger;
  }

  /// Logs [message] at [level] through the installed logger; see
  /// [HiLogger.log].
  static void log(
    HiLogLevel level,
    String Function() message, {
    String? module,
    Map<String, Object?> attributes = const {},
    Object? error,
    StackTrace? stackTrace,
  }) => _logger?.log(
    level,
    message,
    module: module,
    attributes: attributes,
    error: error,
    stackTrace: stackTrace,
  );

  /// Logs [message] at [HiLogLevel.debug]; see [log].
  static void debug(
    String Function() message, {
    String? module,
    Map<String, Object?> attributes = const {},
    Object? error,
    StackTrace? stackTrace,
  }) => log(
    HiLogLevel.debug,
    message,
    module: module,
    attributes: attributes,
    error: error,
    stackTrace: stackTrace,
  );

  /// Logs [message] at [HiLogLevel.info]; see [log].
  static void info(
    String Function() message, {
    String? module,
    Map<String, Object?> attributes = const {},
    Object? error,
    StackTrace? stackTrace,
  }) => log(
    HiLogLevel.info,
    message,
    module: module,
    attributes: attributes,
    error: error,
    stackTrace: stackTrace,
  );

  /// Logs [message] at [HiLogLevel.warning]; see [log].
  static void warning(
    String Function() message, {
    String? module,
    Map<String, Object?> attributes = const {},
    Object? error,
    StackTrace? stackTrace,
  }) => log(
    HiLogLevel.warning,
    message,
    module: module,
    attributes: attributes,
    error: error,
    stackTrace: stackTrace,
  );

  /// Logs [message] at [HiLogLevel.error]; see [log].
  static void error(
    String Function() message, {
    String? module,
    Map<String, Object?> attributes = const {},
    Object? error,
    StackTrace? stackTrace,
  }) => log(
    HiLogLevel.error,
    message,
    module: module,
    attributes: attributes,
    error: error,
    stackTrace: stackTrace,
  );
}
