import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:test/test.dart';

void main() {
  test('consent starts unknown and is not granted', () {
    final consent = HiConsent();
    expect(consent.status, HiConsentStatus.unknown);
    expect(consent.isGranted, isFalse);
  });

  test('changes are observable', () async {
    final consent = HiConsent();
    final seen = <HiConsentStatus>[];
    consent.changes.listen(seen.add);

    consent.grant();
    consent.grant();
    consent.deny();
    await Future<void>.delayed(Duration.zero);

    expect(seen, [HiConsentStatus.granted, HiConsentStatus.denied]);
    expect(consent.status, HiConsentStatus.denied);
    expect(consent.isGranted, isFalse);
  });
}
