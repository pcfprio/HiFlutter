/// Where a [HiLinkOpener] opens a link.
enum HiLinkMode {
  /// Let the platform decide, typically the default browser or the app
  /// that handles the link.
  platformDefault,

  /// An in-app browser view, staying inside the app.
  inAppBrowser,

  /// Another application, such as the system browser or a store app.
  externalApp,
}

/// Opens links outside the app's own routes: web pages, mail, phone,
/// store pages or other apps.
///
/// The default implementation lives in `hiflutter_nav_url_launcher`.
abstract interface class HiLinkOpener {
  /// Whether some installed application can handle [uri].
  Future<bool> canOpen(Uri uri);

  /// Opens [uri] in [mode].
  ///
  /// Completes with `false` when no application could open it. Platform
  /// failures complete with an error.
  Future<bool> open(Uri uri, {HiLinkMode mode = HiLinkMode.platformDefault});
}
