import 'package:barter_app/core/network/api_client.dart';
import 'package:barter_app/core/theme/app_theme.dart';
import 'package:barter_app/core/theme/theme_mode.dart';
import 'package:barter_app/features/auth/data/auth_repository.dart';
import 'package:barter_app/features/auth/presentation/sign_in_page.dart';
import 'package:barter_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Found by running the app: a mistyped number left no way back, the
/// keyboard's Done did nothing, and dark mode reset on every launch.
class _Auth implements AuthRepository {
  _Auth({this.phone = true});
  final bool phone;
  final requested = <String>[];

  @override
  Future<Map<String, dynamic>> methods() async => {
    'phone': phone,
    'google': false,
    'password': true,
  };

  @override
  Future<String?> requestCode(String phone) async {
    requested.add(phone);
    return '123456';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_Auth> _pump(WidgetTester tester, {bool phone = true}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final auth = _Auth(phone: phone);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authRepositoryProvider.overrideWithValue(auth),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('uz'),
        supportedLocales: L.supportedLocales,
        localizationsDelegates: const [
          L.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const SignInPage(),
      ),
    ),
  );
  await tester.pump();
  return auth;
}

void main() {
  testWidgets('Done on the phone field sends the code', (tester) async {
    final auth = await _pump(tester);
    await tester.enterText(find.byType(TextField).first, '+998901234122');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(auth.requested, ['+998901234122']);
    expect(find.text('Kodni kiriting'), findsOneWidget);
  });

  testWidgets('the number can be changed and the code resent after a wait', (
    tester,
  ) async {
    final auth = await _pump(tester);
    await tester.enterText(find.byType(TextField).first, '+998901234122');
    await tester.pump();
    await tester.tap(find.text('Kod yuborish'));
    await tester.pump();

    expect(find.text('Qayta yuborish: 60 s'), findsOneWidget);
    await tester.tap(find.text('Qayta yuborish: 60 s'));
    await tester.pump();
    expect(auth.requested, hasLength(1), reason: 'disabled while counting');

    await tester.pump(const Duration(seconds: 60));
    await tester.tap(find.text('Kodni qayta yuborish'));
    await tester.pump();
    expect(auth.requested, hasLength(2));

    await tester.tap(find.text('Raqamni o‘zgartirish'));
    await tester.pump();
    expect(find.text('Telefon raqamingiz'), findsOneWidget);
    final phone = tester.widget<TextField>(find.byType(TextField).first);
    expect(phone.enabled, isTrue);
  });

  testWidgets('unconfigured SMS is disabled rather than pretending to send', (
    tester,
  ) async {
    final auth = await _pump(tester, phone: false);
    await tester.pump();
    expect(
      find.text('SMS orqali kirish va parolni tiklash hozircha mavjud emas.'),
      findsOneWidget,
    );
    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.enabled, isFalse);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Kod yuborish'),
    );
    expect(button.onPressed, isNull);
    expect(auth.requested, isEmpty);
  });

  test('dark mode survives a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    ProviderContainer launch() => ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );

    final first = launch();
    first.read(darkModeProvider.notifier).set(true);
    first.dispose();

    final second = launch();
    addTearDown(second.dispose);
    expect(second.read(darkModeProvider), isTrue);
  });
}
