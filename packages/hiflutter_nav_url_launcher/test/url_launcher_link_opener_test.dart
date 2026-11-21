import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
  final Exception? failure;
  final launches = <(String, PreferredLaunchMode)>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => openable.contains(url);

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

  test('open completes with the platform failure', () async {
    UrlLauncherPlatform.instance = FakeUrlLauncher(
      failure: PlatformException(code: 'ACTIVITY_NOT_FOUND'),
    );
    expect(opener.open(Uri.parse(page)), throwsA(isA<PlatformException>()));
  });
}
