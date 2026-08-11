import 'package:barter_app/core/theme/app_theme.dart';
import 'package:barter_app/core/widgets/glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The sheet system, checked at both window sizes.
///
/// These exist because the sheets are the one part of the interface that
/// cannot be seen in a screenshot without driving the app: they only appear
/// after a tap, and a tap on the Flutter web canvas is not something the
/// browser tooling can be relied on to deliver. A test pumps them directly.
void main() {
  /// Opens [child] over a button, at a fixed window size.
  Future<void> pumpAt(
    WidgetTester tester,
    Size size,
    Future<void> Function(BuildContext) open,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => open(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('showBarterPanel', () {
    testWidgets('on a phone it is a bottom sheet with a drag handle', (
      tester,
    ) async {
      await pumpAt(
        tester,
        const Size(390, 844),
        (context) => showBarterPanel<void>(
          context: context,
          title: 'Qarshi taklif',
          subtitle: 'Javob berish navbati narigi tomonga o‘tadi.',
          builder: (context) => const Text('body'),
        ),
      );

      expect(find.text('Qarshi taklif'), findsOneWidget);
      expect(
        find.text('Javob berish navbati narigi tomonga o‘tadi.'),
        findsOneWidget,
      );
      expect(find.text('body'), findsOneWidget);

      // The handle is what tells someone the sheet moves, so its absence is a
      // defect rather than a detail.
      expect(_handleFinder, findsOneWidget);

      // A phone sheet is dismissed by dragging, not by a button.
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets('on a wide window it is a centred panel with a close button', (
      tester,
    ) async {
      await pumpAt(
        tester,
        const Size(1280, 900),
        (context) => showBarterPanel<void>(
          context: context,
          title: 'Qarshi taklif',
          builder: (context) => const Text('body'),
        ),
      );

      expect(find.text('Qarshi taklif'), findsOneWidget);
      expect(find.text('body'), findsOneWidget);

      // Reversed from the phone: a mouse gets a target, and the drag
      // affordance would be a lie because there is nothing to drag.
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(_handleFinder, findsNothing);
    });

    testWidgets('closing returns the value the body popped', (tester) async {
      String? result;

      await pumpAt(tester, const Size(390, 844), (context) async {
        result = await showBarterPanel<String>(
          context: context,
          title: 'Surat',
          builder: (context) => TextButton(
            onPressed: () => Navigator.pop(context, 'kamera'),
            child: const Text('Kamera'),
          ),
        );
      });

      await tester.tap(find.text('Kamera'));
      await tester.pumpAndSettle();

      expect(result, 'kamera');
    });
  });

  group('showBarterSheet', () {
    testWidgets('hands the body a controller wired to the sheet', (
      tester,
    ) async {
      ScrollController? handed;

      await pumpAt(
        tester,
        const Size(390, 844),
        (context) => showBarterSheet<void>(
          context: context,
          title: 'E‘lonlaringiz',
          builder: (context, controller) {
            handed = controller;
            return ListView(
              controller: controller,
              children: const [Text('first')],
            );
          },
        ),
      );

      expect(find.text('E‘lonlaringiz'), findsOneWidget);
      expect(find.text('first'), findsOneWidget);
      expect(_handleFinder, findsOneWidget);

      // The whole point of the draggable sheet: the list scrolls on the
      // sheet's own controller, so dragging the list and dragging the sheet
      // are one continuous gesture rather than two that fight.
      expect(handed, isNotNull);
      expect(handed!.hasClients, isTrue);
    });

    testWidgets('on a wide window it becomes a panel, not a drag sheet', (
      tester,
    ) async {
      await pumpAt(
        tester,
        const Size(1280, 900),
        (context) => showBarterSheet<void>(
          context: context,
          title: 'E‘lonlaringiz',
          builder: (context, controller) =>
              ListView(controller: controller, children: const [Text('first')]),
        ),
      );

      expect(find.byType(DraggableScrollableSheet), findsNothing);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });
  });
}

/// The 40×5 bar at the top of a phone sheet.
final _handleFinder = find.byWidgetPredicate(
  (w) =>
      w is Container &&
      w.constraints?.maxWidth == 40 &&
      w.constraints?.maxHeight == 5,
  description: 'drag handle',
);
