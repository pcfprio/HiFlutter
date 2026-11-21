import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiflutter_core/hiflutter_core.dart';

void main() {
  test('notifies listeners when the value changes', () {
    final notifier = HiSafeValueNotifier(0);
    final seen = <int>[];
    notifier.addListener(() => seen.add(notifier.value));

    notifier.value = 1;
    notifier.value = 1;
    notifier.value = 2;

    expect(seen, [1, 2]);
  });

  test('setting the value after dispose does not throw', () {
    final notifier = HiSafeValueNotifier(0);
    notifier.dispose();

    expect(() => notifier.value = 1, returnsNormally);
  });

  test('disposing twice does not throw', () {
    final notifier = HiSafeValueNotifier(0)..dispose();

    expect(notifier.dispose, returnsNormally);
  });

  testWidgets('a change made during build reaches listeners after the frame', (
    tester,
  ) async {
    final notifier = HiSafeValueNotifier(0);
    addTearDown(notifier.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            ValueListenableBuilder<int>(
              valueListenable: notifier,
              builder: (context, value, _) => Text('value $value'),
            ),
            Builder(
              builder: (context) {
                notifier.value = 1;
                return const SizedBox();
              },
            ),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.pump();

    expect(find.text('value 1'), findsOneWidget);
  });

  testWidgets('a change deferred past dispose is dropped', (tester) async {
    final notifier = HiSafeValueNotifier(0);
    var notified = false;
    notifier.addListener(() => notified = true);

    await tester.pumpWidget(
      Builder(
        builder: (context) {
          notifier
            ..value = 1
            ..dispose();
          return const SizedBox();
        },
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(notified, isFalse);
  });
}
