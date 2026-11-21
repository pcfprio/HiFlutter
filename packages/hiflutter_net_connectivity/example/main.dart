import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_net/hiflutter_net.dart';
import 'package:hiflutter_net_connectivity/hiflutter_net_connectivity.dart';

void main() => runApp(
  const Directionality(
    textDirection: TextDirection.ltr,
    child: ColoredBox(color: Color(0xFFFFFFFF), child: ConnectivityPage()),
  ),
);

/// Displays the current [HiNetworkStatus] and updates on changes.
class ConnectivityPage extends StatefulWidget {
  /// Creates the connectivity page.
  const ConnectivityPage({
    super.key,
    this.connectivity = const HiPlusConnectivity(),
  });

  /// Connectivity source; inject a fake such as `HiMemoryConnectivity` in
  /// tests.
  final HiConnectivity connectivity;

  @override
  State<ConnectivityPage> createState() => _ConnectivityPageState();
}

class _ConnectivityPageState extends State<ConnectivityPage> {
  String _label = 'Checking network status...';
  StreamSubscription<HiNetworkStatus>? _subscription;

  @override
  void initState() {
    super.initState();
    unawaited(_loadInitial());
    _subscription = widget.connectivity.onStatusChanged.listen(
      (status) {
        if (!mounted) return;
        setState(() => _label = 'Status: ${status.name}');
      },
      onError: (Object error) {
        if (!mounted) return;
        final message = error is HiError ? error.diagnostics : '$error';
        setState(() => _label = 'Connectivity error: $message');
      },
    );
  }

  Future<void> _loadInitial() async {
    try {
      final status = await widget.connectivity.check();
      if (!mounted) return;
      setState(() => _label = 'Status: ${status.name}');
    } on HiError catch (error) {
      if (!mounted) return;
      setState(() => _label = 'Connectivity error: ${error.diagnostics}');
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(child: Text(_label));
}
