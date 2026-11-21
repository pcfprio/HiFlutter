import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_net/hiflutter_net.dart';
import 'package:test/test.dart';

final class User {
  User.fromJson(Map<String, dynamic> json)
    : id = json.pickInt('id')!,
      name = json.pickString('name')!;

  final int id;
  final String name;
}

HiHttpClient clientReturning(Object? body, {HiEnvelope? envelope}) =>
    HiHttpClient(
      transport: HiMemoryTransport((_) => HiResponse.json(200, body)),
      baseUrl: Uri.parse('https://api.example.com/'),
      envelope: envelope,
    );

void main() {
  const envelope = HiEnvelope(
    codeKeys: 'code|status',
    messageKeys: 'message|msg',
    dataKeys: 'data|result',
    successCodes: {'0', '200'},
  );

  test(
    'reads code, message and data from the first present candidate',
    () async {
      final reply = await clientReturning({
        'status': 200,
        'msg': 'ok',
        'result': {'id': 1, 'name': 'Ada'},
      }, envelope: envelope).get('me');

      expect(reply.code, '200');
      expect(reply.message, 'ok');
      expect(reply.data, {'id': 1, 'name': 'Ada'});
    },
  );

  test('reads data from the data keys, never from the code keys', () async {
    final reply = await clientReturning({
      'code': 0,
      'data': ['payload'],
    }, envelope: envelope).get('me');

    expect(reply.data, ['payload']);
  });

  test('accepts string codes against the success set', () async {
    final reply = await clientReturning({
      'code': '0',
      'data': 1,
    }, envelope: envelope).get('me');

    expect(reply.data, 1);
  });

  test('a code outside the success set is a server error with code and '
      'message', () async {
    final call = clientReturning({
      'code': 1001,
      'message': 'Insufficient balance',
      'data': null,
    }, envelope: envelope).get('me');

    await expectLater(
      call,
      throwsA(
        isA<HiServerError>()
            .having((e) => e.code, 'code', '1001')
            .having((e) => e.message, 'message', 'Insufficient balance')
            .having((e) => e.statusCode, 'statusCode', 200)
            .having((e) => e.retryable, 'retryable', false),
      ),
    );
  });

  test('a body without any code key is a decode error', () async {
    final call = clientReturning({'data': 1}, envelope: envelope).get('me');

    await expectLater(call, throwsA(isA<HiDecodeError>()));
  });

  test('a body that is not a JSON object is a decode error', () async {
    final call = clientReturning([1, 2], envelope: envelope).get('me');

    await expectLater(call, throwsA(isA<HiDecodeError>()));
  });

  test(
    'business codes listed as unauthorized raise an unauthorized error',
    () async {
      final call = clientReturning({
        'code': 40101,
        'message': 'Session expired',
      }, envelope: envelope.copyWith(unauthorizedCodes: {'40101'})).get('me');

      await expectLater(
        call,
        throwsA(
          isA<HiUnauthorizedError>().having(
            (e) => e.message,
            'message',
            'Session expired',
          ),
        ),
      );
    },
  );

  group('unpacking', () {
    test('object() decodes the data with the injected fromJson', () async {
      final user = await clientReturning({
        'code': 0,
        'data': {'id': 1, 'name': 'Ada'},
      }, envelope: envelope).get('me').object(User.fromJson);

      expect((user.id, user.name), (1, 'Ada'));
    });

    test('list() decodes every element with the injected fromJson', () async {
      final users = await clientReturning({
        'code': 0,
        'data': [
          {'id': 1, 'name': 'Ada'},
          {'id': 2, 'name': 'Bob'},
        ],
      }, envelope: envelope).get('users').list(User.fromJson);

      expect(users.map((u) => u.name), ['Ada', 'Bob']);
    });

    test('list() of null data is empty', () async {
      final users = await clientReturning({
        'code': 0,
      }, envelope: envelope).get('users').list(User.fromJson);

      expect(users, isEmpty);
    });

    test('object() of data that is not an object is a decode error', () async {
      final call = clientReturning({
        'code': 0,
        'data': 'nope',
      }, envelope: envelope).get('me').object(User.fromJson);

      await expectLater(call, throwsA(isA<HiDecodeError>()));
    });

    test('a throwing fromJson becomes a decode error', () async {
      final call = clientReturning({
        'code': 0,
        'data': [
          {'id': 1},
        ],
      }, envelope: envelope).get('users').list(User.fromJson);

      await expectLater(call, throwsA(isA<HiDecodeError>()));
    });

    test('decode() converts arbitrary data', () async {
      final count = await clientReturning({
        'code': 0,
        'data': '42',
      }, envelope: envelope).get('count').decode(HiConvert.asInt);

      expect(count, 42);
    });

    test('without an envelope the whole body is the data', () async {
      final user = await clientReturning({'id': 1, 'name': 'Ada'})
          .get('me')
          .object(User.fromJson);

      expect(user.name, 'Ada');
    });
  });
}
