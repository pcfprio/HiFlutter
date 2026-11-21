import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_store/hiflutter_store.dart';

Future<void> main() async {
  // In an app, pass a platform backend such as HiPrefsKeyValueBackend from
  // hiflutter_store_prefs; the in-memory store behaves the same way.
  final settings = HiKeyValueStore.memory();
  await settings.setBool('onboarded', true);
  await settings.setInt('launches', 3);
  await settings.setJson('profile', {
    'id': 7,
    'name': 'Ada',
    'tags': ['admin'],
  });
  print('profile: ${await settings.getJson('profile')}');

  // Credentials are refused by plain key-value storage...
  try {
    await settings.setString('accessToken', 'abc.def');
  } on HiStorageError catch (e) {
    print('refused: ${e.message}');
  }

  // ...and belong in secure storage instead.
  final secrets = HiSecureStore.memory();
  await secrets.write('accessToken', 'abc.def');
  print('has token: ${await secrets.containsKey('accessToken')}');

  // Files are addressed by relative paths that cannot escape the store.
  final files = HiFileStore.memory();
  await files.writeText('notes/today.txt', 'hello');
  print('note: ${await files.readText('notes/today.txt')}');
  try {
    await files.readText('../outside.txt');
  } on HiStorageError catch (e) {
    print('refused: ${e.message}');
  }
}
