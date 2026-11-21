import 'package:flutter/widgets.dart';
import 'package:hiflutter_store/hiflutter_store.dart';
import 'package:hiflutter_store_secure/hiflutter_store_secure.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final secrets = HiSecureStore(HiSecureStorageBackend());
  if (!await secrets.containsKey('accessToken')) {
    await secrets.write('accessToken', 'token-from-sign-in');
  }
  final signedIn = await secrets.read('accessToken') != null;

  runApp(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: Text(signedIn ? 'Signed in' : 'Signed out')),
    ),
  );
}
