/// Pure Dart foundation of HiFlutter: the layered [HiError] model, routed
/// and redacted logging with [HiLogger] and the global [HiLog] entry,
/// lenient type conversion with [HiConvert] and `'a|b'` multi-candidate map
/// lookup with [HiMapPick].
///
/// It also defines the [HiAnalytics] and [HiCrashReporter] contracts, gated
/// by the user's [HiConsent].
library;

export 'src/analytics.dart';
export 'src/consent.dart';
export 'src/convert.dart';
export 'src/crash.dart';
export 'src/error.dart';
export 'src/log.dart';
export 'src/log_console.dart';
export 'src/log_global.dart';
export 'src/map_pick.dart';
export 'src/scalar.dart';
