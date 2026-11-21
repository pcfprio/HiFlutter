/// Severity of a log record, from least to most severe.
enum HiLogLevel {
  /// Detailed diagnostics, dropped by the default route.
  debug,

  /// Normal operation worth recording.
  info,

  /// Something unexpected that the app recovered from.
  warning,

  /// A failure.
  error,
}

/// A log record after filtering and redaction, as delivered to a
/// [HiLogSink].
///
/// Records are created only by [HiLogger]; sinks cannot construct one, and
/// every field, including [attributes], is read-only.
final class HiLogRecord {
  HiLogRecord._({
    required this.time,
    required this.level,
    required this.message,
    required this.module,
    required this.attributes,
    required this.error,
    required this.stackTrace,
  });

  /// When the record was logged, in local time.
  final DateTime time;

  /// Severity of this record.
  final HiLogLevel level;

  /// The log message.
  final String message;

  /// Module tag, such as `'net'`, when the caller gave one.
  final String? module;

  /// Structured attributes, unmodifiable.
  ///
  /// Values are `null`, [bool], [num], [String], or unmodifiable lists and
  /// maps of them; any other object is replaced by its `toString()`.
  final Map<String, Object?> attributes;

  /// Text of the error that accompanied this record, if any.
  final String? error;

  /// Stack trace that accompanied this record, if any.
  final StackTrace? stackTrace;
}

/// Destination of log records, such as the console or a file.
///
/// A sink only ever receives records that its [HiLogRoute] accepted and
/// redacted.
abstract interface class HiLogSink {
  /// Writes [record].
  void write(HiLogRecord record);
}

/// How a [HiLogRoute] hides sensitive data before it reaches the sink.
final class HiRedaction {
  /// The default policy.
  ///
  /// Replaces with [mask]:
  ///
  /// - the value of every attribute (at any depth) whose key contains a
  ///   sensitive word, ignoring case, `_` and `-`: `password`, `passwd`,
  ///   `token`, `authorization`, `cookie`, `secret`, `apikey`, `privatekey`,
  ///   `credential`, plus [extraKeys];
  /// - in the message, the error text and string attribute values: Bearer
  ///   tokens, JWTs, URL query parameters whose name is sensitive as above,
  ///   and every match of [extraPatterns].
  const HiRedaction.standard({
    this.extraKeys = const {},
    this.extraPatterns = const [],
  }) : _enabled = true;

  /// Delivers records unchanged.
  ///
  /// Only choose this for sinks whose output never leaves the developer's
  /// machine.
  const HiRedaction.none()
    : _enabled = false,
      extraKeys = const {},
      extraPatterns = const [];

  /// Additional sensitive key words, matched like the built-in ones.
  final Set<String> extraKeys;

  /// Additional patterns whose matches are replaced with [mask].
  final List<Pattern> extraPatterns;

  final bool _enabled;

  /// Replacement for hidden values.
  static const mask = '[REDACTED]';

  static const _sensitiveKeys = [
    'password',
    'passwd',
    'token',
    'authorization',
    'cookie',
    'secret',
    'apikey',
    'privatekey',
    'credential',
  ];

  static final _keySeparators = RegExp('[-_]');

  static String _normalizeKey(String key) =>
      key.toLowerCase().replaceAll(_keySeparators, '');

  bool _isSensitiveKey(String key) {
    final normalized = _normalizeKey(key);
    return _sensitiveKeys.any(normalized.contains) ||
        extraKeys.map(_normalizeKey).any(normalized.contains);
  }

  static final _bearer = RegExp(
    r'\b(bearer\s+)[A-Za-z0-9\-._~+/]+=*',
    caseSensitive: false,
  );

  static final _jwt = RegExp(
    r'\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+',
  );

  static final _queryParameter = RegExp(r'([?&])([^=&#\s]+)=([^&#\s]*)');

  String _text(String text) {
    if (!_enabled) return text;
    for (final pattern in extraPatterns) {
      text = text.replaceAll(pattern, mask);
    }
    return text
        .replaceAll(_jwt, mask)
        .replaceAllMapped(_bearer, (m) => '${m[1]}$mask')
        .replaceAllMapped(
          _queryParameter,
          (m) => _isSensitiveKey(m[2]!) ? '${m[1]}${m[2]}=$mask' : m[0]!,
        );
  }

  Map<String, Object?> _attributes(Map<String, Object?> attributes) =>
      _map(attributes);

  Map<String, Object?> _map(Map<Object?, Object?> map) => Map.unmodifiable({
    for (final MapEntry(:key, :value) in map.entries)
      '$key': _enabled && _isSensitiveKey('$key') ? mask : _value(value),
  });

  Object? _value(Object? value) => switch (value) {
    null || bool() || num() => value,
    String() => _text(value),
    Map<Object?, Object?>() => _map(value),
    Iterable<Object?>() => List<Object?>.unmodifiable(value.map(_value)),
    _ => _text(value.toString()),
  };
}

/// Connects a [HiLogSink] to a [HiLogger] with its own minimum level and
/// redaction policy.
final class HiLogRoute {
  /// Creates a route to [sink] that accepts records at [minLevel] or above.
  ///
  /// The default [minLevel] drops [HiLogLevel.debug] and the default
  /// [redaction] is [HiRedaction.standard].
  const HiLogRoute(
    this.sink, {
    this.minLevel = HiLogLevel.info,
    this.redaction = const HiRedaction.standard(),
  });

  /// Where accepted records go.
  final HiLogSink sink;

  /// Least severe level this route accepts.
  final HiLogLevel minLevel;

  /// How sensitive data is hidden before reaching [sink].
  final HiRedaction redaction;

  bool _accepts(HiLogLevel level) => level.index >= minLevel.index;
}

/// Writes log records to one or more [HiLogRoute]s.
///
/// Each route filters and redacts on its own, so routes never affect each
/// other; an exception thrown by one sink is swallowed and does not reach
/// the caller or the other routes.
final class HiLogger {
  /// Creates a logger that routes every record to each of [routes].
  HiLogger(Iterable<HiLogRoute> routes) : _routes = List.unmodifiable(routes);

  final List<HiLogRoute> _routes;

  /// Logs [message] at [level].
  ///
  /// [message] runs at most once, and only if some route accepts [level].
  /// [module] tags the record; [attributes] adds structured data; [error]
  /// and [stackTrace] describe a failure.
  void log(
    HiLogLevel level,
    String Function() message, {
    String? module,
    Map<String, Object?> attributes = const {},
    Object? error,
    StackTrace? stackTrace,
  }) {
    final accepting = [
      for (final route in _routes)
        if (route._accepts(level)) route,
    ];
    if (accepting.isEmpty) return;
    final text = message();
    final time = DateTime.now();
    for (final route in accepting) {
      final redaction = route.redaction;
      final record = HiLogRecord._(
        time: time,
        level: level,
        message: redaction._text(text),
        module: module,
        attributes: redaction._attributes(attributes),
        error: error == null ? null : redaction._text('$error'),
        stackTrace: stackTrace,
      );
      try {
        route.sink.write(record);
      } catch (_) {
        // Logging must never break the caller or starve the other routes.
      }
    }
  }

  /// Logs [message] at [HiLogLevel.debug]; see [log].
  void debug(
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
  void info(
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
  void warning(
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
  void error(
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
