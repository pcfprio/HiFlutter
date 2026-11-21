import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hiflutter/hiflutter.dart';
import 'package:hiflutter_riverpod/hiflutter_riverpod.dart';
import 'package:hiflutter_suite_cached_image/hiflutter_suite_cached_image.dart';
import 'package:hiflutter_suite_webview/hiflutter_suite_webview.dart';
import 'package:material_ui/material_ui.dart';

import 'showcase_deps.dart';

/// Strongly typed routes for the showcase app.
abstract final class ShowcaseRoutes {
  /// Home catalog route.
  static final home = HiRoute<void>(
    '/',
    encode: (_) => const {},
    decode: (_) {},
  );

  /// Suite UI widgets and controls route.
  static final suiteControls = HiRoute<void>(
    '/suite',
    encode: (_) => const {},
    decode: (_) {},
  );

  /// Riverpod-backed pagination list route.
  static final pagination = HiRoute<void>(
    '/pagination',
    encode: (_) => const {},
    decode: (_) {},
  );

  /// Networking, storage, and observability demo route.
  static final coreAndData = HiRoute<void>(
    '/data',
    encode: (_) => const {},
    decode: (_) {},
  );

  /// Optional cached-image and webview adapters demo route.
  static final mediaAndWeb = HiRoute<void>(
    '/media',
    encode: (_) => const {},
    decode: (_) {},
  );

  /// WebView detail route driven by `HiWebViewPage`.
  static final webPage = HiRoute<Uri>(
    '/webview',
    encode: (uri) => {'url': '$uri'},
    decode: (params) => Uri.parse(params.requireString('url')),
  );
}

/// Sample Riverpod pagination provider demonstrating `hiPaginationProvider`.
final showcasePaginationProvider = hiPaginationProvider<String>(
  (_) => (page) async {
    final start = (page - 1) * 10 + 1;
    final items = [for (var i = 0; i < 10; i++) 'Entry #${start + i}'];
    return HiPageSlice(items: items, hasMore: page < 3);
  },
);

/// Builds the [HiGoRouterNavigator] and [HiRouteTable] for all showcase pages.
HiGoRouterNavigator createShowcaseNavigator(ShowcaseDependencies deps) {
  final table = HiRouteTable([
    ShowcaseRoutes.home,
    ShowcaseRoutes.suiteControls,
    ShowcaseRoutes.pagination,
    ShowcaseRoutes.coreAndData,
    ShowcaseRoutes.mediaAndWeb,
    ShowcaseRoutes.webPage,
  ], deepLinks: HiDeepLinkGuard(schemes: {'https'}, hosts: {'hiflutter.dev'}));

  return HiGoRouterNavigator(
    table: table,
    pages: [
      ShowcaseRoutes.home.page((_, _) => const ShowcaseHomePage()),
      ShowcaseRoutes.suiteControls.page((_, _) => const ShowcaseSuitePage()),
      ShowcaseRoutes.pagination.page((_, _) => const ShowcasePaginationPage()),
      ShowcaseRoutes.coreAndData.page((_, _) => ShowcaseDataPage(deps: deps)),
      ShowcaseRoutes.mediaAndWeb.page((_, _) => const ShowcaseMediaPage()),
      ShowcaseRoutes.webPage.page((_, url) => _ShowcaseWebViewScreen(url: url)),
    ],
    initialLocation: '/',
  );
}

/// Home page listing every HiFlutter package demonstration with live search.
class ShowcaseHomePage extends ConsumerStatefulWidget {
  /// Creates the showcase home page.
  const ShowcaseHomePage({super.key});

  @override
  ConsumerState<ShowcaseHomePage> createState() => _ShowcaseHomePageState();
}

class _ShowcaseHomePageState extends ConsumerState<ShowcaseHomePage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final navigator = ref.watch(hiNavigatorProvider);
    final entries = <({String title, String subtitle, HiRoute<void> route})>[
      (
        title: 'Suite UI & Controls',
        subtitle: 'Toast, dialog, list rows, primary button, search field',
        route: ShowcaseRoutes.suiteControls,
      ),
      (
        title: 'Pagination List',
        subtitle: 'HiPaginationNotifier + HiPaginatedListView',
        route: ShowcaseRoutes.pagination,
      ),
      (
        title: 'Net, Store & Observability',
        subtitle: 'HiHttpClient, HiKeyValueStore, HiConsent, HiError',
        route: ShowcaseRoutes.coreAndData,
      ),
      (
        title: 'Media & WebView',
        subtitle: 'HiCachedImage, HiImageViewer, HiWebViewPage',
        route: ShowcaseRoutes.mediaAndWeb,
      ),
    ];

    final normalized = _query.trim().toLowerCase();
    final filtered = normalized.isEmpty
        ? entries
        : [
            for (final entry in entries)
              if (entry.title.toLowerCase().contains(normalized) ||
                  entry.subtitle.toLowerCase().contains(normalized))
                entry,
          ];

    return Scaffold(
      appBar: AppBar(title: const Text('HiFlutter Showcase')),
      body: ListView(
        padding: const EdgeInsets.all(HiSuiteMetrics.horizontalSafeMargin),
        children: [
          HiSearchField(
            hintText: 'Filter package demos',
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: HiSuiteMetrics.spacingLarge),
          if (filtered.isEmpty)
            const HiEmptyView(
              title: 'No matching demo',
              message: 'Try another keyword or clear the filter.',
            )
          else
            HiListSection(
              header: const Text('Package Families'),
              children: [
                for (final entry in filtered)
                  HiListRow(
                    title: Text(entry.title),
                    subtitle: Text(entry.subtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => navigator.push<void, void>(entry.route, null),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Demonstrates `hiflutter_suite` widgets: rows, buttons, toast, and dialog.
class ShowcaseSuitePage extends StatefulWidget {
  /// Creates the suite components demo page.
  const ShowcaseSuitePage({super.key});

  @override
  State<ShowcaseSuitePage> createState() => _ShowcaseSuitePageState();
}

class _ShowcaseSuitePageState extends State<ShowcaseSuitePage> {
  String _selected = 'Alpha';
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Suite UI & Controls')),
      body: ListView(
        padding: const EdgeInsets.all(HiSuiteMetrics.horizontalSafeMargin),
        children: [
          HiListSection(
            header: const Text('Selectable Options'),
            footer: Text('Confirmed: $_confirmed'),
            children: [
              HiSelectableListRow(
                title: const Text('Option Alpha'),
                selected: _selected == 'Alpha',
                onTap: () => setState(() => _selected = 'Alpha'),
              ),
              HiSelectableListRow(
                title: const Text('Option Beta'),
                selected: _selected == 'Beta',
                onTap: () => setState(() => _selected = 'Beta'),
              ),
            ],
          ),
          const SizedBox(height: HiSuiteMetrics.spacingLarge),
          HiPrimaryButton(
            label: 'Show Toast',
            onPressed: () => HiToast.show(context, 'Saved option: $_selected'),
          ),
          const SizedBox(height: HiSuiteMetrics.spacingMedium),
          HiPrimaryButton(
            label: 'Open Confirm Dialog',
            shape: HiButtonShape.capsule,
            onPressed: () async {
              final accepted = await HiConfirmDialog.show(
                context,
                title: 'Confirm selection',
                message: 'Apply $_selected as the active choice?',
              );
              if (!mounted) return;
              setState(() => _confirmed = accepted);
            },
          ),
          const SizedBox(height: HiSuiteMetrics.spacingLarge),
          HiErrorView(
            error: const HiNetworkError(message: 'Preview retryable error'),
            onRetry: () => HiToast.show(context, 'Retry tapped'),
          ),
        ],
      ),
    );
  }
}

/// Demonstrates `HiPaginationNotifier` coupled with `HiPaginatedListView`.
class ShowcasePaginationPage extends ConsumerStatefulWidget {
  /// Creates the pagination demo page.
  const ShowcasePaginationPage({super.key});

  @override
  ConsumerState<ShowcasePaginationPage> createState() =>
      _ShowcasePaginationPageState();
}

class _ShowcasePaginationPageState
    extends ConsumerState<ShowcasePaginationPage> {
  late final HiPaginationController<String> _controller =
      HiPaginationController<String>(
        loader: (page) async {
          final start = (page - 1) * 10 + 1;
          final items = [for (var i = 0; i < 10; i++) 'Entry #${start + i}'];
          return HiPageSlice(items: items, hasMore: page < 3);
        },
      );

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(showcasePaginationProvider.notifier).loadInitial(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final riverpodState = ref.watch(showcasePaginationProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('Pagination (${riverpodState.items.length} via Riverpod)'),
      ),
      body: HiPaginatedListView<String>(
        controller: _controller,
        itemBuilder: (context, item, index) => HiListRow(title: Text(item)),
      ),
    );
  }
}

/// Demonstrates `hiflutter_net`, `hiflutter_store`, `hiflutter_core`, and
/// `hiflutter_base` observability contracts.
class ShowcaseDataPage extends ConsumerStatefulWidget {
  /// Creates the data and observability demo page.
  const ShowcaseDataPage({super.key, required this.deps});

  /// Injected dependencies used to inspect consent and redacted logs.
  final ShowcaseDependencies deps;

  @override
  ConsumerState<ShowcaseDataPage> createState() => _ShowcaseDataPageState();
}

class _ShowcaseDataPageState extends ConsumerState<ShowcaseDataPage> {
  String _httpOutput = 'Not sent';
  String _storeOutput = 'Not tested';
  String _deviceOutput = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
  }

  Future<void> _loadDeviceInfo() async {
    try {
      final info = await ref.read(hiDeviceInfoSourceProvider).load();
      if (!mounted) return;
      setState(() => _deviceOutput = info.toUserAgent());
    } catch (error) {
      if (!mounted) return;
      setState(() => _deviceOutput = 'Device info error: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final consent = ref.watch(hiConsentProvider);
    final analytics = ref.watch(hiAnalyticsProvider);
    final httpClient = ref.watch(hiHttpClientProvider);
    final kvStore = ref.watch(hiKeyValueStoreProvider);
    final linkSegments = HiLinkDetector.split(
      'Docs at https://hiflutter.dev (${HiFormat.fileSize(2048)})',
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Net, Store & Observability')),
      body: ListView(
        padding: const EdgeInsets.all(HiSuiteMetrics.horizontalSafeMargin),
        children: [
          HiListSection(
            header: const Text('Observability & Consent'),
            children: [
              HiListRow(
                title: Text('Consent: ${consent.status.name}'),
                subtitle: Text(
                  'Analytics delivered: ${widget.deps.analyticsSink.delivered.length}',
                ),
              ),
              HiListRow(
                title: const Text('Grant Consent'),
                onTap: () {
                  consent.grant();
                  setState(() {});
                },
              ),
              HiListRow(
                title: const Text('Track Demo Event'),
                onTap: () async {
                  await analytics.track('showcase_tap');
                  if (!mounted) return;
                  setState(() {});
                },
              ),
            ],
          ),
          const SizedBox(height: HiSuiteMetrics.spacingLarge),
          HiListSection(
            header: const Text('Network & Storage'),
            children: [
              HiListRow(
                title: const Text('Run Envelope Request'),
                subtitle: Text(_httpOutput),
                onTap: () async {
                  final user = await httpClient
                      .get('users/1')
                      .object(
                        (json) =>
                            'User #${HiConvert.asInt(json.pick('id'))}: '
                            '${HiConvert.asString(json.pick('name'))}',
                      );
                  if (!mounted) return;
                  setState(() => _httpOutput = user);
                },
              ),
              HiListRow(
                title: const Text('Test Credential Guard'),
                subtitle: Text(_storeOutput),
                onTap: () async {
                  try {
                    await kvStore.setString('api_token', 'bad');
                  } on HiStorageError catch (error) {
                    if (!mounted) return;
                    setState(() => _storeOutput = 'HiStorageError: $error');
                  }
                },
              ),
              HiListRow(
                title: const Text('User-Agent & Links'),
                subtitle: Text(
                  '$_deviceOutput | links=${linkSegments.where((s) => s.isLink).length}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Demonstrates optional UI adapters (`HiCachedImage`, `HiImageViewer`, and
/// `HiWebViewPage`).
class ShowcaseMediaPage extends ConsumerWidget {
  /// Creates the optional adapters demo page.
  const ShowcaseMediaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navigator = ref.watch(hiNavigatorProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Media & WebView')),
      body: ListView(
        padding: const EdgeInsets.all(HiSuiteMetrics.horizontalSafeMargin),
        children: [
          Center(
            child: HiCachedImage(
              imageUrl: '',
              width: 120,
              height: 120,
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              onTap: () => HiImageViewer.show(
                context,
                urls: const ['https://hiflutter.dev/logo.png'],
              ),
            ),
          ),
          const SizedBox(height: HiSuiteMetrics.spacingLarge),
          HiPrimaryButton(
            label: 'Open WebView Page',
            onPressed: () => navigator.push<Uri, void>(
              ShowcaseRoutes.webPage,
              Uri.parse('https://hiflutter.dev'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShowcaseWebViewScreen extends ConsumerWidget {
  const _ShowcaseWebViewScreen({required this.url});

  final Uri url;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opener = ref.watch(hiLinkOpenerProvider);
    return HiWebViewPage(
      initialUrl: url,
      linkOpener: opener,
      allowedHosts: const {'hiflutter.dev'},
    );
  }
}
