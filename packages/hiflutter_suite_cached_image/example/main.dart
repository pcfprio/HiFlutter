import 'package:hiflutter_suite/hiflutter_suite.dart';
import 'package:hiflutter_suite_cached_image/hiflutter_suite_cached_image.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  runApp(const _CachedImageExampleApp());
}

class _CachedImageExampleApp extends StatelessWidget {
  const _CachedImageExampleApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      supportedLocales: HiSuiteLocalizations.supportedLocales,
      localizationsDelegates: HiSuiteLocalizations.localizationsDelegates,
      home: const _GalleryExamplePage(),
    );
  }
}

class _GalleryExamplePage extends StatelessWidget {
  const _GalleryExamplePage();

  static const _urls = <String>[
    'https://example.com/photo-1.jpg',
    'https://example.com/photo-2.jpg',
    'https://example.com/photo-3.jpg',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HiCachedImage Example')),
      body: Center(
        child: HiCachedImage(
          imageUrl: _urls.first,
          width: 160,
          height: 160,
          fit: BoxFit.cover,
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HiImageViewer.show(context, urls: _urls);
          },
        ),
      ),
    );
  }
}
