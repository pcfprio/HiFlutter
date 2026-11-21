import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_net/hiflutter_net.dart';

/// Sample model decoded from a JSON object payload.
final class User {
  /// Creates a user from [json].
  User.fromJson(Map<String, dynamic> json)
    : id = json.pickInt('id') ?? 0,
      name = json.pickString('name') ?? 'anonymous';

  /// User identifier.
  final int id;

  /// Display name.
  final String name;
}

/// Adds a client request header before the transport runs.
final class RequestTagInterceptor extends HiHttpInterceptor {
  @override
  HiRequest onRequest(HiRequest request) =>
      request.copyWith(headers: {...request.headers, 'x-client': 'hiflutter'});
}

Future<void> main() async {
  HiLog.install(
    HiLogger([
      HiLogRoute(const HiConsoleLogSink(), minLevel: HiLogLevel.debug),
    ]),
  );

  final transport = HiMemoryTransport(
    (request) => HiResponse.json(200, {
      'code': 0,
      'message': 'ok',
      'data': {'id': 42, 'name': 'Ada'},
    }),
  );

  final client = HiHttpClient(
    transport: transport,
    baseUrl: Uri.parse('https://api.example.com/v1/'),
    headers: () => {'authorization': 'Bearer demo-token'},
    envelope: const HiEnvelope(unauthorizedCodes: {'40101'}),
    defaultTimeout: const Duration(seconds: 10),
    interceptors: [RequestTagInterceptor()],
    onUnauthorized: (error, request) {
      print('Unauthorized on ${request.url}: ${error.message}');
    },
  );

  final user = await client.get('users/me').object(User.fromJson);
  final page = HiPageResult<User>(items: [user], hasMore: false, page: 1);
  print('Loaded ${page.map((u) => u.name).items}');

  final connectivity = HiMemoryConnectivity();
  print('Online: ${(await connectivity.check()).isOnline}');
  await connectivity.dispose();
  await client.close();
}
