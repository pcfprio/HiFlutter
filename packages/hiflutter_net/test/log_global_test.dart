import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_net/hiflutter_net.dart';
import 'package:test/test.dart';

final class _MemorySink implements HiLogSink {
  final records = <HiLogRecord>[];

  @override
  void write(HiLogRecord record) => records.add(record);
}

void main() {
  test(
    'falls back to global HiLog when no logger is passed to HiHttpClient',
    () async {
      final sink = _MemorySink();
      HiLog.install(HiLogger([HiLogRoute(sink)]));

      final client = HiHttpClient(
        transport: HiMemoryTransport((_) => HiResponse.json(200, {'ok': true})),
        baseUrl: Uri.parse('https://api.example.com/'),
        headers: () => {'authorization': 'Bearer global-secret'},
      );

      await client.get('ping', query: {'token': 'secret-param'});

      expect(sink.records, hasLength(2));
      expect(sink.records[0].module, 'net');
      expect(sink.records[0].message, contains('token=[REDACTED]'));
      expect(sink.records[0].attributes['headers'], {
        'authorization': '[REDACTED]',
      });
      expect(sink.records[1].attributes['status'], 200);
    },
  );
}
