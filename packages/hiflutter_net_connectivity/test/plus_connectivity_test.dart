import 'dart:async';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_net/hiflutter_net.dart';
import 'package:hiflutter_net_connectivity/hiflutter_net_connectivity.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakeConnectivityPlatform extends ConnectivityPlatform
    with MockPlatformInterfaceMixin {
  List<ConnectivityResult> current = const [ConnectivityResult.wifi];
  Object? checkError;
  Object? streamGetterError;

  final StreamController<List<ConnectivityResult>> controller =
      StreamController<List<ConnectivityResult>>.broadcast();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async {
    if (checkError case final error?) {
      throw error;
    }
    return current;
  }

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged {
    if (streamGetterError case final error?) {
      throw error;
    }
    return controller.stream;
  }
}

void main() {
  late ConnectivityPlatform originalPlatform;
  late _FakeConnectivityPlatform fakePlatform;
  const HiConnectivity connectivity = HiPlusConnectivity();

  setUp(() {
    originalPlatform = ConnectivityPlatform.instance;
    fakePlatform = _FakeConnectivityPlatform();
    ConnectivityPlatform.instance = fakePlatform;
  });

  tearDown(() async {
    ConnectivityPlatform.instance = originalPlatform;
    await fakePlatform.controller.close();
  });

  group('HiPlusConnectivity.check', () {
    test('maps single active connectivity results to online', () async {
      for (final result in [
        ConnectivityResult.wifi,
        ConnectivityResult.mobile,
        ConnectivityResult.ethernet,
        ConnectivityResult.vpn,
        ConnectivityResult.bluetooth,
        ConnectivityResult.satellite,
        ConnectivityResult.other,
      ]) {
        fakePlatform.current = [result];
        final status = await connectivity.check();
        expect(
          status,
          HiNetworkStatus.online,
          reason: '$result should map to online',
        );
        expect(status.isOnline, isTrue);
      }
    });

    test('maps combined connectivity results to online', () async {
      for (final results in const [
        [ConnectivityResult.wifi, ConnectivityResult.mobile],
        [ConnectivityResult.mobile, ConnectivityResult.vpn],
        [ConnectivityResult.wifi, ConnectivityResult.ethernet],
        [ConnectivityResult.none, ConnectivityResult.wifi],
      ]) {
        fakePlatform.current = results;
        expect(await connectivity.check(), HiNetworkStatus.online);
      }
    });

    test('maps none-only and empty lists to offline', () async {
      for (final results in const [
        [ConnectivityResult.none],
        [ConnectivityResult.none, ConnectivityResult.none],
        <ConnectivityResult>[],
      ]) {
        fakePlatform.current = results;
        final status = await connectivity.check();
        expect(status, HiNetworkStatus.offline);
        expect(status.isOnline, isFalse);
      }
    });

    test('normalizes platform exceptions via HiError.from', () async {
      fakePlatform.checkError = PlatformException(
        code: 'CHECK_FAILED',
        message: 'native error',
      );
      await expectLater(
        connectivity.check(),
        throwsA(
          isA<HiUnknownError>().having(
            (e) => e.diagnostics,
            'diagnostics',
            contains('CHECK_FAILED'),
          ),
        ),
      );

      fakePlatform.checkError = TimeoutException('check timed out');
      await expectLater(connectivity.check(), throwsA(isA<HiTimeoutError>()));

      fakePlatform.checkError = const FormatException('unexpected payload');
      await expectLater(connectivity.check(), throwsA(isA<HiDecodeError>()));

      const existing = HiNetworkError(message: 'already normalized');
      fakePlatform.checkError = existing;
      await expectLater(connectivity.check(), throwsA(same(existing)));
    });
  });

  group('HiPlusConnectivity.onStatusChanged', () {
    test('maps status changes across online and offline states', () async {
      final emitted = <HiNetworkStatus>[];
      final sub = connectivity.onStatusChanged.listen(emitted.add);

      fakePlatform.controller.add([ConnectivityResult.wifi]);
      fakePlatform.controller.add([ConnectivityResult.none]);
      fakePlatform.controller.add([ConnectivityResult.mobile]);
      fakePlatform.controller.add(const []);
      fakePlatform.controller.add([
        ConnectivityResult.ethernet,
        ConnectivityResult.vpn,
      ]);

      await Future<void>.delayed(Duration.zero);

      expect(emitted, [
        HiNetworkStatus.online,
        HiNetworkStatus.offline,
        HiNetworkStatus.online,
        HiNetworkStatus.offline,
        HiNetworkStatus.online,
      ]);
      await sub.cancel();
    });

    test(
      'deduplicates adjacent identical mapped statuses by default',
      () async {
        final emitted = <HiNetworkStatus>[];
        final sub = connectivity.onStatusChanged.listen(emitted.add);

        // Multiple distinct online combinations collapse into one online event.
        fakePlatform.controller.add([ConnectivityResult.wifi]);
        fakePlatform.controller.add([ConnectivityResult.mobile]);
        fakePlatform.controller.add([
          ConnectivityResult.ethernet,
          ConnectivityResult.vpn,
        ]);
        // Distinct offline representations collapse into one offline event.
        fakePlatform.controller.add([ConnectivityResult.none]);
        fakePlatform.controller.add(const []);
        // Transitioning back to online emits again.
        fakePlatform.controller.add([ConnectivityResult.vpn]);

        await Future<void>.delayed(Duration.zero);

        expect(emitted, [
          HiNetworkStatus.online,
          HiNetworkStatus.offline,
          HiNetworkStatus.online,
        ]);
        await sub.cancel();
      },
    );

    test(
      'preserves adjacent identical mapped statuses when emitDistinct is false',
      () async {
        const nonDistinct = HiPlusConnectivity(emitDistinct: false);
        final emitted = <HiNetworkStatus>[];
        final sub = nonDistinct.onStatusChanged.listen(emitted.add);

        fakePlatform.controller.add([ConnectivityResult.wifi]);
        fakePlatform.controller.add([ConnectivityResult.mobile]);
        fakePlatform.controller.add(const []);
        fakePlatform.controller.add([ConnectivityResult.none]);

        await Future<void>.delayed(Duration.zero);

        expect(emitted, [
          HiNetworkStatus.online,
          HiNetworkStatus.online,
          HiNetworkStatus.offline,
          HiNetworkStatus.offline,
        ]);
        await sub.cancel();
      },
    );

    test('maps stream errors via HiError.from and keeps listening', () async {
      final events = <Object>[];
      final sub = connectivity.onStatusChanged.listen(
        events.add,
        onError: (Object error) => events.add(error),
      );

      fakePlatform.controller.add([ConnectivityResult.wifi]);
      fakePlatform.controller.addError(
        PlatformException(code: 'STREAM_ERR', message: 'stream failed'),
      );
      fakePlatform.controller.addError(TimeoutException('stream timeout'));
      fakePlatform.controller.addError(const FormatException('bad event'));
      fakePlatform.controller.add([ConnectivityResult.none]);

      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(5));
      expect(events[0], HiNetworkStatus.online);
      expect(events[1], isA<HiUnknownError>());
      expect(events[2], isA<HiTimeoutError>());
      expect(events[3], isA<HiDecodeError>());
      expect(events[4], HiNetworkStatus.offline);

      await sub.cancel();
    });

    test(
      'maps synchronous stream getter failure to HiError on the stream',
      () async {
        fakePlatform.streamGetterError = PlatformException(
          code: 'STREAM_INIT_FAILED',
        );

        await expectLater(
          connectivity.onStatusChanged,
          emitsError(isA<HiUnknownError>()),
        );
      },
    );

    test(
      'supports multiple listeners when platform stream is broadcast',
      () async {
        final first = <HiNetworkStatus>[];
        final second = <HiNetworkStatus>[];
        final sub1 = connectivity.onStatusChanged.listen(first.add);
        final sub2 = connectivity.onStatusChanged.listen(second.add);

        fakePlatform.controller.add([ConnectivityResult.wifi]);
        fakePlatform.controller.add([ConnectivityResult.none]);
        await Future<void>.delayed(Duration.zero);

        expect(first, [HiNetworkStatus.online, HiNetworkStatus.offline]);
        expect(second, [HiNetworkStatus.online, HiNetworkStatus.offline]);

        await sub1.cancel();
        await sub2.cancel();
      },
    );
  });
}
