import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_nav/hiflutter_nav.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

/// [HiLinkOpener] backed by url_launcher.
///
/// [HiLinkMode.inAppBrowser] only supports `http` and `https` links; other
/// schemes complete with an [ArgumentError] in that mode. Platform failures
/// (for example a missing handler activity) are normalized into [HiError] via
/// [HiError.from] so third-party/platform exceptions never leak.
class HiUrlLauncherLinkOpener implements HiLinkOpener {
  /// Creates an opener using the current url_launcher platform.
  const HiUrlLauncherLinkOpener();

  @override
  Future<bool> canOpen(Uri uri) => _guard(() => launcher.canLaunchUrl(uri));

  @override
  Future<bool> open(Uri uri, {HiLinkMode mode = HiLinkMode.platformDefault}) =>
      _guard(() => launcher.launchUrl(uri, mode: _mode(mode)));

  Future<bool> _guard(Future<bool> Function() run) async {
    try {
      return await run();
    } on ArgumentError {
      rethrow;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(HiError.from(error, stackTrace), stackTrace);
    }
  }

  static launcher.LaunchMode _mode(HiLinkMode mode) => switch (mode) {
    HiLinkMode.platformDefault => launcher.LaunchMode.platformDefault,
    HiLinkMode.inAppBrowser => launcher.LaunchMode.inAppBrowserView,
    HiLinkMode.externalApp => launcher.LaunchMode.externalApplication,
  };
}
