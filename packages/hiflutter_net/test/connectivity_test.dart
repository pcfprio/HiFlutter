import 'package:hiflutter_net/hiflutter_net.dart';
import 'package:test/test.dart';

void main() {
  test('HiNetworkStatus.isOnline reflects online vs offline', () {
    expect(HiNetworkStatus.online.isOnline, isTrue);
    expect(HiNetworkStatus.offline.isOnline, isFalse);
  });

  test(
    'HiMemoryConnectivity starts online by default and is configurable',
    () async {
      final defaultConn = HiMemoryConnectivity();
      final offlineConn = HiMemoryConnectivity(
        initial: HiNetworkStatus.offline,
      );

      expect(await defaultConn.check(), HiNetworkStatus.online);
      expect(await offlineConn.check(), HiNetworkStatus.offline);

      await defaultConn.dispose();
      await offlineConn.dispose();
    },
  );

  test('emit updates check() and notifies onStatusChanged listeners', () async {
    final connectivity = HiMemoryConnectivity();
    final events = <HiNetworkStatus>[];
    final sub = connectivity.onStatusChanged.listen(events.add);

    connectivity.emit(HiNetworkStatus.offline);
    expect(await connectivity.check(), HiNetworkStatus.offline);

    connectivity.emit(HiNetworkStatus.online);
    expect(await connectivity.check(), HiNetworkStatus.online);

    await Future<void>.delayed(Duration.zero);
    expect(events, [HiNetworkStatus.offline, HiNetworkStatus.online]);

    await sub.cancel();
    await connectivity.dispose();
  });

  test('dispose closes the onStatusChanged stream', () async {
    final connectivity = HiMemoryConnectivity();
    final done = expectLater(connectivity.onStatusChanged, emitsDone);

    await connectivity.dispose();

    await done;
  });
}
