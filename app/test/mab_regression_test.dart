import 'package:barter_app/core/router/app_router.dart';
import 'package:barter_app/core/theme/app_theme.dart';
import 'package:barter_app/core/widgets/common.dart';
import 'package:barter_app/core/widgets/device_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Counter extends StatefulWidget {
  const _Counter();
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => setState(() => count++),
    child: Text('count:$count'),
  );
}

void main() {
  testWidgets('switching tabs preserves the previous screen state', (
    tester,
  ) async {
    var tab = 0;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, set) {
            update = set;
            return AnimatedBranchContainer(
              currentIndex: tab,
              children: const [_Counter(), Text('other')],
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('count:0'));
    await tester.pump();
    update(() => tab = 1);
    await tester.pump();
    expect(find.text('other'), findsOneWidget);
    update(() => tab = 0);
    await tester.pump();
    expect(find.text('count:1'), findsOneWidget);
  });

  testWidgets('resizing across frame boundary preserves state', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(719, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const DeviceFrame(child: _Counter()),
      ),
    );
    await tester.tap(find.text('count:0'));
    await tester.pump();
    for (final width in [721.0, 1440.0, 390.0]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pump();
      expect(find.text('count:1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  test('primary button colours remain readable in both themes', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      final a = theme.colorScheme.primary.computeLuminance();
      final b = theme.colorScheme.onPrimary.computeLuminance();
      final contrast = a > b
          ? (a + 0.05) / (b + 0.05)
          : (b + 0.05) / (a + 0.05);
      expect(contrast, greaterThanOrEqualTo(4.5));
    }
  });

  testWidgets('reduced motion shows late list content immediately', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: AnimatedListItem(index: 99, child: Text('ready')),
        ),
      ),
    );
    expect(find.text('ready').hitTestable(), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });
}
