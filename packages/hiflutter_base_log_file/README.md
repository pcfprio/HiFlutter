# hiflutter_base_log_file

File log sink for [HiFlutter](https://github.com/pcfprio/HiFlutter)'s
logging in [`hiflutter_base`](../hiflutter_base), so users can export logs
when they report a problem.

## Features

- **Daily rotation**: records go to `hiflutter-<yyyy-MM-dd>.log`; a new file
  starts at midnight.
- **Size limit**: when the next record would push a file past
  `maxFileBytes` (default 5 MiB), it goes to the next part of the day,
  `hiflutter-<yyyy-MM-dd>.1.log`, `.2.log`, ... After a restart the sink
  continues the latest part.
- **Retention**: files older than `retentionDays` (default 7, today
  included) are deleted whenever a day's file is first opened. Other files
  in the directory are left alone.
- **Export**: `logFiles()` lists the log files, oldest first.
- **You choose the directory**, or use
  `HiFileLogSink.inApplicationSupport()` for a `logs` folder in the app's
  application support directory (via `path_provider`).

Each record is one line with its time, level, module, message and
attributes as JSON; the error text and stack trace follow, indented.
Records reach the sink already redacted by their `HiLogRoute`. Keep the
default `HiRedaction.standard()` for this sink, since log files leave the
device when exported.

## Usage

```dart
import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_base_log_file/hiflutter_base_log_file.dart';

Future<void> main() async {
  final fileSink = await HiFileLogSink.inApplicationSupport(
    maxFileBytes: 2 * 1024 * 1024,
    retentionDays: 3,
  );
  HiLog.install(HiLogger([
    HiLogRoute(const HiConsoleLogSink(), minLevel: HiLogLevel.debug),
    HiLogRoute(fileSink), // info and above, redacted.
  ]));

  HiLog.info(() => 'app started', module: 'app');

  // Later, when the user sends feedback:
  final files = await fileSink.logFiles();
  // Attach `files` to the report.
}
```

To pick the directory yourself, pass a `Directory`:

```dart
final sink = HiFileLogSink(Directory('/path/to/logs'));
```

See `example/main.dart` for a complete example.

## License

MIT
