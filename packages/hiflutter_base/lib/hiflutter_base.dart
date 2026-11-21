/// Pure Dart foundation of HiFlutter: the layered [HiError] model, lenient
/// type conversion with [HiConvert] and `'a|b'` multi-candidate map lookup
/// with [HiMapPick].
///
/// It also defines the [HiAnalytics] and [HiCrashReporter] contracts, gated
/// by the user's [HiConsent].
library;

export 'src/convert.dart';
export 'src/error.dart';
export 'src/map_pick.dart';
export 'src/consent.dart';
export 'src/scalar.dart';
export 'src/analytics.dart';
export 'src/crash.dart';
