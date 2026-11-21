/// Umbrella package of HiFlutter.
///
/// Re-exports the HiFlutter-owned public APIs of the core contract packages
/// and default non-vendor adapters without exposing third-party types or
/// triggering any automatic initialization.
///
/// Optional adapters (`hiflutter_net_connectivity`,
/// `hiflutter_suite_cached_image`, `hiflutter_suite_webview`) and optional
/// state-management bindings (`hiflutter_riverpod`) are installed separately.
library;

export 'package:hiflutter_base/hiflutter_base.dart';
export 'package:hiflutter_base_log_file/hiflutter_base_log_file.dart';
export 'package:hiflutter_core/hiflutter_core.dart';
export 'package:hiflutter_core_device/hiflutter_core_device.dart';
export 'package:hiflutter_nav/hiflutter_nav.dart';
export 'package:hiflutter_nav_go_router/hiflutter_nav_go_router.dart';
export 'package:hiflutter_nav_url_launcher/hiflutter_nav_url_launcher.dart';
export 'package:hiflutter_net/hiflutter_net.dart';
export 'package:hiflutter_net_dio/hiflutter_net_dio.dart';
export 'package:hiflutter_store/hiflutter_store.dart';
export 'package:hiflutter_store_file/hiflutter_store_file.dart';
export 'package:hiflutter_store_prefs/hiflutter_store_prefs.dart';
export 'package:hiflutter_store_secure/hiflutter_store_secure.dart';
export 'package:hiflutter_suite/hiflutter_suite.dart';
