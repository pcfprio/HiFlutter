import 'package:flutter/widgets.dart';
import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_base_log_file/hiflutter_base_log_file.dart';

Future<void> main() async {
  // path_provider needs the Flutter binding.
  WidgetsFlutterBinding.ensureInitialized();

  // Daily files in <application support>/logs, at most 2 MiB each, kept
  // for three days.
  final fileSink = await HiFileLogSink.inApplicationSupport(
    maxFileBytes: 2 * 1024 * 1024,
    retentionDays: 3,
  );

  // The file route keeps the default level (info) and redaction, because
  // log files leave the device when the user exports them.
  HiLog.install(
    HiLogger([
      HiLogRoute(const HiConsoleLogSink(), minLevel: HiLogLevel.debug),
      HiLogRoute(fileSink),
    ]),
  );

  HiLog.info(
    () =>
        'GET /v1/me?access_token=abc123', // Written as access_token=[REDACTED].
    module: 'net',
    attributes: {'status': 200},
  );
  HiLog.error(
    () => 'upload failed',
    module: 'net',
    error: StateError('connection reset'),
    stackTrace: StackTrace.current,
  );

  // When the user sends feedback, attach the files.
  for (final file in await fileSink.logFiles()) {
    HiLog.info(() => 'exportable log: ${file.path}');
  }
}
