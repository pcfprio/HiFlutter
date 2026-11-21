# hiflutter_suite_cached_image

[cached_network_image](https://pub.dev/packages/cached_network_image) adapter
for [HiFlutter](https://github.com/pcfprio/HiFlutter), providing `HiCachedImage`
and `HiImageViewer` without exposing any third-party types.

## Features

- **Zero third-party type leakage**: `package:hiflutter_suite_cached_image/hiflutter_suite_cached_image.dart`
  exposes only `HiCachedImage`, `HiImageViewer`, and HiFlutter/Flutter types.
- **Cached image widget (`HiCachedImage`)**:
  - Wraps `CachedNetworkImage` with `width`, `height`, `fit`, `borderRadius`,
    `headers`, `placeholder`, `errorWidget`, `onTap`, and optional
    `imageProviderOverride` for offline tests or custom image sources.
  - Renders an error view immediately when `imageUrl.trim().isEmpty` without
    starting a network request.
  - Uses a centered compact loading indicator and a localized Material 3 error
    fallback by default, mapping failures to `HiError`.
- **Fullscreen image viewer (`HiImageViewer`)**:
  - Open directly as a widget or via `HiImageViewer.show(context, urls: ...)`.
  - Supports single-image and multi-image `PageView` swiping, pinch-to-zoom via
    `InteractiveViewer`, page numbering (`1 / 3`), and a close button.

## Usage

```dart
import 'package:hiflutter_suite_cached_image/hiflutter_suite_cached_image.dart';
import 'package:material_ui/material_ui.dart';

class GalleryAvatar extends StatelessWidget {
  const GalleryAvatar({super.key, required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    return HiCachedImage(
      imageUrl: urls.first,
      width: 96,
      height: 96,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.circular(12),
      onTap: () => HiImageViewer.show(context, urls: urls),
    );
  }
}
```

See `example/main.dart` for a complete runnable Flutter example.

## License

MIT
