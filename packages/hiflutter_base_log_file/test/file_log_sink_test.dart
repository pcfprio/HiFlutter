import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_base_log_file/hiflutter_base_log_file.dart';

void main() {
  late Directory dir;
  late DateTime now;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('hi_log_file_test_');
    now = DateTime(2026, 11, 21, 9, 30);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  HiFileLogSink sinkIn(Directory directory) =>
      HiFileLogSink(directory, now: () => now);

  HiLogger loggerFor(HiLogSink sink) =>
      HiLogger([HiLogRoute(sink, minLevel: HiLogLevel.debug)]);

  List<String> names(List<File> files) => [
    for (final file in files) file.uri.pathSegments.last,
  ];

  test('writes records to a file named after the current day', () async {
    final sink = sinkIn(dir);
    loggerFor(sink).info(
      () => 'GET /feed?token=abc',
      module: 'net',
      attributes: {'status': 200, 'password': 'p'},
    );
    sink.close();

    final files = await sink.logFiles();
    expect(names(files), ['hiflutter-2026-11-21.log']);
    final line = files.single.readAsStringSync();
    expect(
      line,
      matches(
        RegExp(
          r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d+ INFO \[net\] '
          r'GET /feed\?token=\[REDACTED\] '
          r'\{"status":200,"password":"\[REDACTED\]"\}\n$',
        ),
      ),
    );
  });

  test(
    'writes the redacted error and the stack trace below the line',
    () async {
      final sink = sinkIn(dir);
      loggerFor(sink).error(
        () => 'upload failed',
        error: StateError('Bearer secret123 rejected'),
        stackTrace: StackTrace.fromString('#0 main (file.dart:1)\n#1 run'),
      );
      sink.close();

      final lines = (await sink.logFiles()).single.readAsLinesSync();
      expect(lines, hasLength(4));
      expect(lines[0], endsWith(' ERROR upload failed'));
      expect(lines.skip(1), [
        '  Bad state: Bearer [REDACTED] rejected',
        '  #0 main (file.dart:1)',
        '  #1 run',
      ]);
    },
  );

  test('starts a new file when the day changes', () async {
    final sink = sinkIn(dir);
    final logger = loggerFor(sink);
    logger.info(() => 'before midnight');
    now = DateTime(2026, 11, 22, 0, 0, 1);
    logger.info(() => 'after midnight');
    sink.close();

    final files = await sink.logFiles();
    expect(names(files), [
      'hiflutter-2026-11-21.log',
      'hiflutter-2026-11-22.log',
    ]);
    expect(files[0].readAsStringSync(), contains('before midnight'));
    expect(files[0].readAsStringSync(), isNot(contains('after midnight')));
    expect(files[1].readAsStringSync(), contains('after midnight'));
  });

  test('starts a new part when a file would exceed the size limit', () async {
    final sink = HiFileLogSink(dir, maxFileBytes: 100, now: () => now);
    final logger = loggerFor(sink);
    for (final word in ['first', 'second', 'third']) {
      logger.info(() => word.padRight(40, '.'));
    }
    for (var i = 0; i < 10; i++) {
      logger.info(() => 'small $i');
    }
    sink.close();

    // Each padded line is about 75 bytes and each small one about 40, so
    // the padded lines get a file each and small ones share at most two.
    final files = await sink.logFiles();
    expect(names(files).take(4), [
      'hiflutter-2026-11-21.log',
      'hiflutter-2026-11-21.1.log',
      'hiflutter-2026-11-21.2.log',
      'hiflutter-2026-11-21.3.log',
    ]);
    expect(names(files).skip(4), [
      for (var part = 4; part < files.length; part++)
        'hiflutter-2026-11-21.$part.log',
    ]);
    expect(files.length, greaterThanOrEqualTo(8));
    expect(files[0].readAsStringSync(), contains('first'));
    expect(files[1].readAsStringSync(), contains('second'));
    expect(files[2].readAsStringSync(), contains('third'));
    for (final file in files) {
      expect(file.lengthSync(), lessThanOrEqualTo(100));
    }
    final text = files.map((file) => file.readAsStringSync()).join();
    expect('small'.allMatches(text), hasLength(10));
  });

  test('a new sink continues after the latest part of the day', () async {
    final first = HiFileLogSink(dir, maxFileBytes: 100, now: () => now);
    loggerFor(first)
      ..info(() => 'first'.padRight(40, '.'))
      ..info(() => 'second'.padRight(40, '.'));
    first.close();

    final second = HiFileLogSink(dir, maxFileBytes: 100, now: () => now);
    loggerFor(second).info(() => 'third'.padRight(40, '.'));
    second.close();

    final files = await second.logFiles();
    expect(names(files), [
      'hiflutter-2026-11-21.log',
      'hiflutter-2026-11-21.1.log',
      'hiflutter-2026-11-21.2.log',
    ]);
    expect(files[2].readAsStringSync(), contains('third'));
    for (final file in files) {
      expect(file.lengthSync(), lessThanOrEqualTo(100));
    }
  });

  test('deletes files older than the retention days on first write', () async {
    for (final name in [
      'hiflutter-2026-11-01.log',
      'hiflutter-2026-11-14.log',
      'hiflutter-2026-11-14.1.log',
      'hiflutter-2026-11-15.log',
      'hiflutter-2026-11-15.1.log',
      'notes.txt',
    ]) {
      File('${dir.path}/$name').writeAsStringSync('old\n');
    }
    final sink = HiFileLogSink(dir, retentionDays: 7, now: () => now);
    loggerFor(sink).info(() => 'today');
    sink.close();

    expect(names(await sink.logFiles()), [
      'hiflutter-2026-11-15.log',
      'hiflutter-2026-11-15.1.log',
      'hiflutter-2026-11-21.log',
    ]);
    expect(File('${dir.path}/notes.txt').existsSync(), isTrue);
  });

  test('deletes expired files when the day changes', () async {
    final sink = HiFileLogSink(dir, retentionDays: 2, now: () => now);
    final logger = loggerFor(sink);
    logger.info(() => 'day one');
    now = DateTime(2026, 11, 22, 12);
    logger.info(() => 'day two');
    now = DateTime(2026, 11, 23, 12);
    logger.info(() => 'day three');
    sink.close();

    expect(names(await sink.logFiles()), [
      'hiflutter-2026-11-22.log',
      'hiflutter-2026-11-23.log',
    ]);
  });

  test('lists no files before anything is written', () async {
    final sink = sinkIn(Directory('${dir.path}/missing'));
    expect(await sink.logFiles(), isEmpty);
  });

  test('creates the directory on first write', () async {
    final sink = sinkIn(Directory('${dir.path}/nested/logs'));
    loggerFor(sink).info(() => 'hello');
    sink.close();
    expect(names(await sink.logFiles()), ['hiflutter-2026-11-21.log']);
  });

  test(
    'writes a record larger than the limit into a part of its own',
    () async {
      final sink = HiFileLogSink(dir, maxFileBytes: 50, now: () => now);
      final logger = loggerFor(sink);
      logger.info(() => 'a' * 80);
      logger.info(() => 'b' * 80);
      sink.close();

      final files = await sink.logFiles();
      expect(names(files), [
        'hiflutter-2026-11-21.log',
        'hiflutter-2026-11-21.1.log',
      ]);
      expect(files[0].readAsStringSync(), contains('a' * 80));
      expect(files[1].readAsStringSync(), contains('b' * 80));
    },
  );
}
