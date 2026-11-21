import 'dart:developer' as developer;

import 'log.dart';

/// A [HiLogSink] that writes to the developer console through
/// `dart:developer`, for use during development.
///
/// The record's module becomes the log name (default `hiflutter`), and its
/// error and stack trace are passed through so IDEs can render them.
final class HiConsoleLogSink implements HiLogSink {
  /// Creates a console sink.
  const HiConsoleLogSink();

  /// The text written for [record]: level, message, and attributes if any,
  /// such as `INFO request sent {path: /feed}`.
  String format(HiLogRecord record) {
    final head = '${record.level.name.toUpperCase()} ${record.message}';
    return record.attributes.isEmpty ? head : '$head ${record.attributes}';
  }

  @override
  void write(HiLogRecord record) => developer.log(
    format(record),
    time: record.time,
    level: _developerLevel(record.level),
    name: record.module ?? 'hiflutter',
    error: record.error,
    stackTrace: record.stackTrace,
  );

  /// Levels on the scale of `package:logging`, which DevTools understands.
  static int _developerLevel(HiLogLevel level) => switch (level) {
    HiLogLevel.debug => 500,
    HiLogLevel.info => 800,
    HiLogLevel.warning => 900,
    HiLogLevel.error => 1000,
  };
}
