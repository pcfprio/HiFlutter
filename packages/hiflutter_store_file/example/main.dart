import 'package:flutter/widgets.dart';
import 'package:hiflutter_store/hiflutter_store.dart';
import 'package:hiflutter_store_file/hiflutter_store_file.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final files = HiFileStore(HiAppFileBackend());
  final previous = await files.readText('notes/last_open.txt');
  await files.writeText(
    'notes/last_open.txt',
    DateTime.now().toIso8601String(),
  );

  runApp(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: Text('Last opened: ${previous ?? 'never'}')),
    ),
  );
}
