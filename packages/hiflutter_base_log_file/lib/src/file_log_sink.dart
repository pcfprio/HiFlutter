import 'dart:convert';
import 'dart:io';

import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:path_provider/path_provider.dart';

/// A [HiLogSink] that appends records to daily log files in [directory].
///
/// Files are named `hiflutter-<yyyy-MM-dd>.log`. When the next record would
/// push a file past [maxFileBytes], it goes to a new part of the same day,
/// `hiflutter-<yyyy-MM-dd>.1.log`, `.2.log` and so on; a single record
/// larger than the limit gets a part of its own. Whenever a day's file is
/// first opened, files older than [retentionDays] are deleted. Other files
/// in [directory] are never touched.
///
/// Each record is one line, `<time> <LEVEL> [module] message {attributes}`
/// with attributes as JSON, followed by the error text and stack trace, if
/// any, indented by two spaces. Records arrive already redacted by their
/// [HiLogRoute]; keep the default [HiRedaction.standard] for this sink,
/// since log files are meant to be exported.
///
/// Writes are synchronous and unbuffered, so [logFiles] always sees every
/// record written so far.
final class HiFileLogSink implements HiLogSink {
  /// Creates a sink that writes into [directory].
  ///
  /// A file grows to at most [maxFileBytes] before the next part of the
  /// same day is started. Files of the last [retentionDays] days, today
  /// included, are kept. [now] tells the current time; it defaults to
  /// [DateTime.now].
  HiFileLogSink(
    this.directory, {
    this.maxFileBytes = defaultMaxFileBytes,
    this.retentionDays = defaultRetentionDays,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Creates a sink that writes into [folder] of the application support
  /// directory, which the user cannot see and the system does not clear.
  ///
  /// The other parameters are those of the [HiFileLogSink.new] constructor.
  static Future<HiFileLogSink> inApplicationSupport({
    String folder = 'logs',
    int maxFileBytes = defaultMaxFileBytes,
    int retentionDays = defaultRetentionDays,
    DateTime Function()? now,
  }) async {
    final support = await getApplicationSupportDirectory();
    return HiFileLogSink(
      Directory('${support.path}/$folder'),
      maxFileBytes: maxFileBytes,
      retentionDays: retentionDays,
      now: now,
    );
  }

  /// Default [maxFileBytes]: 5 MiB.
  static const defaultMaxFileBytes = 5 * 1024 * 1024;

  /// Default [retentionDays]: one week.
  static const defaultRetentionDays = 7;

  /// Directory that holds the log files.
  final Directory directory;

  /// Size limit of one log file, in bytes.
  final int maxFileBytes;

  /// Number of days, today included, whose log files are kept.
  final int retentionDays;

  final DateTime Function() _now;

  RandomAccessFile? _file;
  _LogFileName? _name;
  int _size = 0;

  @override
  void write(HiLogRecord record) {
    final bytes = utf8.encode(_format(record));
    final now = _now();
    final day = _date(now);
    var name = _name;
    if (name == null || name.day != day) {
      final oldest = _date(
        DateTime(now.year, now.month, now.day - (retentionDays - 1)),
      );
      final names = _names();
      for (final expired in names.where(
        (name) => name.day.compareTo(oldest) < 0,
      )) {
        _delete(expired);
      }
      // Continue the latest part of the day, e.g. after an app restart.
      name = names.lastWhere(
        (existing) => existing.day == day,
        orElse: () => _LogFileName(day, 0),
      );
      _open(name);
    }
    if (_size > 0 && _size + bytes.length > maxFileBytes) {
      _open(_LogFileName(day, name.part + 1));
    }
    _file!.writeFromSync(bytes);
    _size += bytes.length;
  }

  /// Closes the open log file; a later [write] opens it again.
  void close() {
    _file?.closeSync();
    _file = null;
    _name = null;
    _size = 0;
  }

  /// The log files in [directory], oldest first, for example to attach to
  /// a feedback report or share with the platform share sheet.
  ///
  /// Empty when nothing was written yet.
  Future<List<File>> logFiles() async => [
    for (final name in _names()) File('${directory.path}/$name'),
  ];

  /// Names of the log files in [directory], oldest first.
  List<_LogFileName> _names() {
    if (!directory.existsSync()) return [];
    return [
      for (final entity in directory.listSync())
        if (entity is File)
          if (_LogFileName.parse(entity.uri.pathSegments.last) case final name?)
            name,
    ]..sort();
  }

  void _delete(_LogFileName name) {
    try {
      File('${directory.path}/$name').deleteSync();
    } on FileSystemException {
      // Already gone or locked; try again at the next cleanup.
    }
  }

  void _open(_LogFileName name) {
    close();
    directory.createSync(recursive: true);
    final file = File('${directory.path}/$name');
    _file = file.openSync(mode: FileMode.append);
    _name = name;
    _size = _file!.lengthSync();
  }

  static String _date(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  /// One line `<time> <LEVEL> [module] message {attributes}`, followed by
  /// the error text and stack trace lines, each indented by two spaces.
  static String _format(HiLogRecord record) {
    final module = record.module;
    final head = [
      record.time.toIso8601String(),
      record.level.name.toUpperCase(),
      if (module != null) '[$module]',
      record.message,
      if (record.attributes.isNotEmpty) jsonEncode(record.attributes),
    ].join(' ');
    final details = [
      ?record.error,
      if (record.stackTrace case final stackTrace?) '$stackTrace',
    ];
    final buffer = StringBuffer(head)..writeln();
    for (final text in details) {
      for (final line in const LineSplitter().convert(text)) {
        if (line.isNotEmpty) buffer.writeln('  $line');
      }
    }
    return buffer.toString();
  }
}

/// Name of one log file: `hiflutter-<day>.log` for the first part of a day,
/// `hiflutter-<day>.<part>.log` for the following ones.
final class _LogFileName implements Comparable<_LogFileName> {
  const _LogFileName(this.day, this.part);

  /// Day in `yyyy-MM-dd` form.
  final String day;

  /// Zero-based part number within [day].
  final int part;

  static final _pattern = RegExp(
    r'^hiflutter-(\d{4}-\d\d-\d\d)(?:\.(\d+))?\.log$',
  );

  static _LogFileName? parse(String name) {
    final match = _pattern.firstMatch(name);
    if (match == null) return null;
    return _LogFileName(match[1]!, int.parse(match[2] ?? '0'));
  }

  @override
  int compareTo(_LogFileName other) {
    final byDay = day.compareTo(other.day);
    return byDay != 0 ? byDay : part.compareTo(other.part);
  }

  @override
  String toString() =>
      part == 0 ? 'hiflutter-$day.log' : 'hiflutter-$day.$part.log';
}
