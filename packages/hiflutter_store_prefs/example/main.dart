import 'package:flutter/widgets.dart';
import 'package:hiflutter_store/hiflutter_store.dart';
import 'package:hiflutter_store_prefs/hiflutter_store_prefs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settings = HiKeyValueStore(HiPrefsKeyValueBackend());
  final launches = (await settings.getInt('launches') ?? 0) + 1;
  await settings.setInt('launches', launches);
  await settings.setJson('lastLaunch', {
    'count': launches,
    'at': DateTime.now().toIso8601String(),
  });

  runApp(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: Text('Launched $launches times')),
    ),
  );
}
