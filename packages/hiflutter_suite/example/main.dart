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
      home: const _PaginatedExamplePage(),
    );
  }
}

class _PaginatedExamplePage extends StatefulWidget {
  const _PaginatedExamplePage();

  @override
  State<_PaginatedExamplePage> createState() => _PaginatedExamplePageState();
}

class _PaginatedExamplePageState extends State<_PaginatedExamplePage> {
  late final HiPaginationController<String> _controller;

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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HiFlutter Suite Example')),
      body: HiPaginatedListView<String>(
        controller: _controller,
        itemBuilder: (context, item, index) => ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: HiSuiteMetrics.listRowMinHeight,
          ),
          child: ListTile(title: Text(item)),
        ),
      ),
    );
  }
}
