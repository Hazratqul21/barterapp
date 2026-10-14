import 'package:barter_app/core/theme/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('reduce-motion AnimatedSize does not trip layout', (
    tester,
  ) async {
    Widget app(bool big) => MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(
          builder: (context) => Material(
            child: Column(
              children: [
                AnimatedSize(
                  duration: Motion.standard.durationOf(context),
                  curve: Motion.standard.curve,
                  child: SizedBox(height: big ? 100 : 0, width: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(app(false));
    await tester.pumpWidget(app(true));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
