import 'dart:async';

/// Whether the user agreed to send analytics or crash data.
enum HiConsentStatus {
  /// The user has not decided yet. Treated as not granted.
  unknown,

  /// The user explicitly agreed.
  granted,

  /// The user explicitly refused.
  denied,
}

/// Observable privacy consent of the user.
///
/// Create one in the composition root, restore the persisted decision through
/// `initial`, and hand it to the consent-gated analytics and crash reporting
/// implementations. Only [HiConsentStatus.granted] lets data leave the app.
class HiConsent {
  /// Creates a consent holder starting at [initial].
  HiConsent({HiConsentStatus initial = HiConsentStatus.unknown})
    : _status = initial;

  HiConsentStatus _status;
  final StreamController<HiConsentStatus> _changes =
      StreamController<HiConsentStatus>.broadcast(sync: true);

  /// The current status.
  HiConsentStatus get status => _status;

  /// Whether data may be sent. `false` for both unknown and denied.
  bool get isGranted => _status == HiConsentStatus.granted;

  /// Emits the new status every time it changes. Setting the same status
  /// again emits nothing.
  Stream<HiConsentStatus> get changes => _changes.stream;

  /// Sets the status to [status], notifying [changes] if it differs.
  void update(HiConsentStatus status) {
    if (status == _status) return;
    _status = status;
    _changes.add(status);
  }

  /// Records that the user agreed.
  void grant() => update(HiConsentStatus.granted);

  /// Records that the user refused.
  void deny() => update(HiConsentStatus.denied);

  /// Closes [changes]. The status can no longer be updated afterwards.
  Future<void> close() => _changes.close();
}
