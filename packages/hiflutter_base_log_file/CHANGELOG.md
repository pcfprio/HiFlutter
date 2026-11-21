## 0.1.0

- Initial release: `HiFileLogSink` writes log records to daily files with a
  per-file size limit (extra parts per day), deletes files older than the
  retention days, and lists the log files for export.
  `HiFileLogSink.inApplicationSupport` places them in the application
  support directory through path_provider.
