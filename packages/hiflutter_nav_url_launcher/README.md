# hiflutter_nav_url_launcher

[url_launcher](https://pub.dev/packages/url_launcher) implementation of the
`HiLinkOpener` contract from `hiflutter_nav`, part of
[HiFlutter](https://github.com/pcfprio/HiFlutter).

## Features

- `canOpen` checks whether an installed app can handle a link.
- `open` launches a link in the `HiLinkMode` you choose:
  `platformDefault`, `inAppBrowser` (http and https only) or
  `externalApp`. It completes with `false` when nothing could open it.

## Usage

```dart
import 'package:hiflutter_nav/hiflutter_nav.dart';
import 'package:hiflutter_nav_url_launcher/hiflutter_nav_url_launcher.dart';

const HiLinkOpener links = HiUrlLauncherLinkOpener();

Future<void> openHelp() async {
  final opened = await links.open(
    Uri.parse('https://example.com/help'),
    mode: HiLinkMode.inAppBrowser,
  );
  if (!opened) {
    // Tell the user the page could not be opened.
  }
}
```

To query other apps with `canOpen`, declare the schemes you check in
`LSApplicationQueriesSchemes` (iOS) and `<queries>` (Android), as described
in the url_launcher documentation. See `example/main.dart` for a complete
example.

## License

MIT
