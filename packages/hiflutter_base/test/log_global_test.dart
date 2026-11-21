// The global entry can be installed only once per isolate, and every test
// file runs in its own isolate. The tests below therefore walk through the
// entry's lifecycle in order: not installed, installed, installed again.
import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:test/test.dart';

final class MemorySink implements HiLogSink {
  final records = <HiLogRecord>[];

  @override
  void write(HiLogRecord record) => records.add(record);
}

void main() {
  final sink = MemorySink();
  final logger = HiLogger([HiLogRoute(sink, minLevel: HiLogLevel.debug)]);

  test('before installation, logging does nothing and runs no closure', () {
    var calls = 0;
    String message() => 'call ${++calls}';

    expect(HiLog.isInstalled, isFalse);
    expect(() {
      HiLog.debug(message);
      HiLog.info(message);
      HiLog.warning(message);
      HiLog.error(message, error: StateError('x'));
      HiLog.log(HiLogLevel.error, message);
    }, returnsNormally);
    expect(calls, 0);
  });

  test('after installation, every level reaches the installed logger', () {
    HiLog.install(logger);

    HiLog.debug(() => 'd', module: 'app');
    HiLog.info(() => 'i', attributes: {'token': 't'});
    HiLog.warning(() => 'w');
    HiLog.error(() => 'e', error: StateError('boom'));
    HiLog.log(HiLogLevel.info, () => 'l');

    expect(HiLog.isInstalled, isTrue);
    expect(sink.records.map((r) => (r.level, r.message)), [
      (HiLogLevel.debug, 'd'),
      (HiLogLevel.info, 'i'),
      (HiLogLevel.warning, 'w'),
      (HiLogLevel.error, 'e'),
      (HiLogLevel.info, 'l'),
    ]);
    expect(sink.records[0].module, 'app');
    expect(sink.records[1].attributes, {'token': '[REDACTED]'});
    expect(sink.records[3].error, 'Bad state: boom');
  });

  test('installing again throws and keeps the first logger', () {
    final other = MemorySink();

    expect(
      () => HiLog.install(HiLogger([HiLogRoute(other)])),
      throwsStateError,
    );

    HiLog.info(() => 'still first');
    expect(sink.records.last.message, 'still first');
    expect(other.records, isEmpty);
  });
}
