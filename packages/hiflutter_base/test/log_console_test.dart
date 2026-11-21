import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:test/test.dart';

final class MemorySink implements HiLogSink {
  final records = <HiLogRecord>[];

  @override
  void write(HiLogRecord record) => records.add(record);
}

HiLogRecord record(void Function(HiLogger logger) log) {
  final sink = MemorySink();
  log(HiLogger([HiLogRoute(sink, minLevel: HiLogLevel.debug)]));
  return sink.records.single;
}

void main() {
  const console = HiConsoleLogSink();

  test('formats level and message', () {
    expect(
      console.format(record((l) => l.warning(() => 'low disk'))),
      'WARNING low disk',
    );
  });

  test('appends redacted attributes', () {
    expect(
      console.format(
        record(
          (l) => l.info(
            () => 'request sent',
            module: 'net',
            attributes: {'path': '/feed', 'token': 't1', 'retry': 2},
          ),
        ),
      ),
      'INFO request sent {path: /feed, token: [REDACTED], retry: 2}',
    );
  });

  test('writing a record with an error does not throw', () {
    final r = record(
      (l) => l.error(
        () => 'failed',
        error: StateError('boom'),
        stackTrace: StackTrace.current,
      ),
    );

    expect(() => console.write(r), returnsNormally);
  });
}
