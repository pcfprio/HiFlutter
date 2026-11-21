import 'package:flutter/widgets.dart';
import 'package:hiflutter_nav/hiflutter_nav.dart';
import 'package:hiflutter_nav_url_launcher/hiflutter_nav_url_launcher.dart';

void main() => runApp(
  const Directionality(
    textDirection: TextDirection.ltr,
    child: ColoredBox(color: Color(0xFFFFFFFF), child: LinksPage()),
  ),
);

/// Opens a help page in each [HiLinkMode].
class LinksPage extends StatefulWidget {
  /// Creates the page.
  const LinksPage({super.key, this.links = const HiUrlLauncherLinkOpener()});

  /// The link opener; inject a fake in tests.
  final HiLinkOpener links;

  @override
  State<LinksPage> createState() => _LinksPageState();
}

class _LinksPageState extends State<LinksPage> {
  static final _help = Uri.parse('https://example.com/help');

  String _status = 'Tap a mode to open the help page';

  Future<void> _open(HiLinkMode mode) async {
    final opened = await widget.links.open(_help, mode: mode);
    if (!mounted) return;
    setState(() {
      _status = opened ? 'Opened with ${mode.name}' : 'Could not open the link';
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(_status),
      for (final mode in HiLinkMode.values)
        GestureDetector(
          onTap: () => _open(mode),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Open help: ${mode.name}'),
          ),
        ),
    ],
  );
}
