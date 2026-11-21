import 'package:hiflutter_net/hiflutter_net.dart';
import 'package:hiflutter_net_dio/hiflutter_net_dio.dart';

Future<void> main() async {
  final transport = HiDioTransport(
    connectTimeout: const Duration(seconds: 10),
    sendTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  );

  final client = HiHttpClient(
    transport: transport,
    baseUrl: Uri.parse('https://api.example.com/v1/'),
    envelope: const HiEnvelope(),
  );

  // Ready to send requests with client.get(...), client.post(...), etc.
  await client.close();
}
