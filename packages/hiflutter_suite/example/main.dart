import 'package:hiflutter_suite/hiflutter_suite.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  runApp(const _SuiteExampleApp());
}

class _SuiteExampleApp extends StatelessWidget {
  const _SuiteExampleApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      supportedLocales: HiSuiteLocalizations.supportedLocales,
      localizationsDelegates: HiSuiteLocalizations.localizationsDelegates,
      home: const _SuiteShowcasePage(),
    );
  }
}

class _SuiteShowcasePage extends StatefulWidget {
  const _SuiteShowcasePage();

  @override
  State<_SuiteShowcasePage> createState() => _SuiteShowcasePageState();
}

class _SuiteShowcasePageState extends State<_SuiteShowcasePage> {
  final TextEditingController _searchController = TextEditingController();
  late final HiPaginationController<String> _controller;
  String _selectedOption = 'All';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _controller = HiPaginationController<String>(
      loader: (page) async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
        return HiPageSlice(
          items: List.generate(15, (i) => 'Row ${(page - 1) * 15 + i + 1}'),
          hasMore: page < 3,
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleClearFilter() async {
    final confirmed = await HiConfirmDialog.show(
      context,
      title: 'Reset filter?',
      message: 'Clear the active search text and restore default selection.',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _submitting = true;
      _searchController.clear();
      _selectedOption = 'All';
    });
    await _controller.refresh();
    if (!mounted) return;
    setState(() => _submitting = false);
    HiToast.show(context, 'Filters cleared');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HiFlutter Suite Example')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(HiSuiteMetrics.horizontalSafeMargin),
            child: HiSearchField(
              controller: _searchController,
              onSubmitted: (query) =>
                  HiToast.show(context, 'Searching: $query'),
            ),
          ),
          HiListSection(
            header: const Text('Scope'),
            margin: const EdgeInsets.symmetric(
              horizontal: HiSuiteMetrics.horizontalSafeMargin,
            ),
            children: [
              HiSelectableListRow(
                title: const Text('All'),
                selected: _selectedOption == 'All',
                onTap: () => setState(() => _selectedOption = 'All'),
              ),
              HiSelectableListRow(
                title: const Text('Favorites'),
                selected: _selectedOption == 'Favorites',
                onTap: () => setState(() => _selectedOption = 'Favorites'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(HiSuiteMetrics.horizontalSafeMargin),
            child: HiPrimaryButton(
              label: 'Reset Filters',
              shape: HiButtonShape.capsule,
              loading: _submitting,
              onPressed: _handleClearFilter,
            ),
          ),
          Expanded(
            child: HiPaginatedListView<String>(
              controller: _controller,
              itemBuilder: (context, item, index) => HiListRow(
                title: Text(item),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => HiToast.show(context, 'Tapped $item'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
