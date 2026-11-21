import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_nav/hiflutter_nav.dart';
import 'package:hiflutter_nav_url_launcher/hiflutter_nav_url_launcher.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Platform fake that records launches and answers from [openable].
class FakeUrlLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  FakeUrlLauncher({this.openable = const {}, this.failure});

  final Set<String> openable;
  final Object? failure;
  final launches = <(String, PreferredLaunchMode)>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async {
    if (failure case final failure?) throw failure;
    return openable.contains(url);
  }

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    if (failure case final failure?) throw failure;
    launches.add((url, options.mode));
    return openable.contains(url);
  }
}

void main() {
  const page = 'https://example.com/help';
  late FakeUrlLauncher platform;
  final HiLinkOpener opener = HiUrlLauncherLinkOpener();

  setUp(() {
    platform = FakeUrlLauncher(openable: {page});
    UrlLauncherPlatform.instance = platform;
  });

  test('canOpen asks the platform', () async {
    expect(await opener.canOpen(Uri.parse(page)), isTrue);
    expect(await opener.canOpen(Uri.parse('weird://x')), isFalse);
  });

  test('open launches with the platform default mode', () async {
    expect(await opener.open(Uri.parse(page)), isTrue);
    expect(platform.launches, [(page, PreferredLaunchMode.platformDefault)]);
  });

  test('open maps every link mode', () async {
    await opener.open(Uri.parse(page), mode: HiLinkMode.inAppBrowser);
    await opener.open(Uri.parse(page), mode: HiLinkMode.externalApp);
    expect(platform.launches, [
      (page, PreferredLaunchMode.inAppBrowserView),
      (page, PreferredLaunchMode.externalApplication),
    ]);
  });

  test('open completes with false when nothing can open the link', () async {
    expect(await opener.open(Uri.parse('mailto:a@example.com')), isFalse);
  });

  test('open and canOpen normalize platform failures into HiError', () async {
    UrlLauncherPlatform.instance = FakeUrlLauncher(
      failure: PlatformException(code: 'ACTIVITY_NOT_FOUND'),
    );
    await expectLater(
      opener.open(Uri.parse(page)),
      throwsA(
        isA<HiUnknownError>().having(
          (e) => e.diagnostics,
          'diagnostics',
          contains('ACTIVITY_NOT_FOUND'),
        ),
      ),
    );
    await expectLater(
      opener.canOpen(Uri.parse(page)),
      throwsA(isA<HiUnknownError>()),
    );
  });

  test('open preserves ArgumentError for invalid arguments', () async {
    UrlLauncherPlatform.instance = FakeUrlLauncher(
      failure: ArgumentError('Only http/https supported'),
    );
    await expectLater(
      opener.open(
        Uri.parse('mailto:a@example.com'),
        mode: HiLinkMode.inAppBrowser,
      ),
      throwsA(isA<ArgumentError>()),
    );
  });
}
