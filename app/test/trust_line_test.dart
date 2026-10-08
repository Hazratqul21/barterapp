import 'package:barter_app/core/theme/app_theme.dart';
import 'package:barter_app/core/widgets/common.dart';
import 'package:barter_app/l10n/app_localizations.dart';
import 'package:barter_app/shared/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// The trust line never shows a fact the trader does not have, and never
/// makes a newcomer look like a bad record.
Future<String> _line(WidgetTester tester, TraderBrief trader) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('uz'),
      supportedLocales: L.supportedLocales,
      localizationsDelegates: const [
        L.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: TrustLine(trader: trader)),
    ),
  );
  final text = tester.widget<Text>(find.byType(Text));
  return text.textSpan!.toPlainText();
}

void main() {
  testWidgets('verified trader with history', (tester) async {
    final line = await _line(
      tester,
      const TraderBrief(
        id: 'a',
        name: 'Aziz',
        isVerified: true,
        rating: 4.8,
        deals: 12,
      ),
    );
    expect(line, contains('4.8'));
    expect(line, contains('12 ta savdo'));
    expect(line, contains('Hujjatlari tasdiqlangan'));
  });

  testWidgets('a newcomer reads as new, not as zeros', (tester) async {
    final line = await _line(
      tester,
      const TraderBrief(id: 'b', name: 'Bek', isVerified: false),
    );
    expect(line, contains('Yangi a’zo'));
    expect(line, isNot(contains('0 ta savdo')));
    expect(line, contains('Tasdiqlanmagan hisob'));
  });

  testWidgets('deals without a rating show no star', (tester) async {
    final line = await _line(
      tester,
      const TraderBrief(id: 'c', name: 'Sardor', isVerified: true, deals: 3),
    );
    expect(line, contains('3 ta savdo'));
    expect(find.byIcon(Icons.star), findsNothing);
    expect(line, isNot(contains('—')));
  });
}
