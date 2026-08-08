import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/network/api_client.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Real paths on the web: a listing link has no "#" in it, so it can be shared.
  usePathUrlStrategy();

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const BarterApp(),
    ),
  );
}

class BarterApp extends ConsumerStatefulWidget {
  const BarterApp({super.key});

  @override
  ConsumerState<BarterApp> createState() => _BarterAppState();
}

class _BarterAppState extends ConsumerState<BarterApp> {
  late final _router = buildRouter();

  @override
  Widget build(BuildContext context) {
    // One piece of state drives both the widgets and the Accept-Language
    // header, so the interface and the content can never end up in two
    // different languages on the same screen.
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'BarterApp',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: Locale(locale),
      supportedLocales: L.supportedLocales,
      localizationsDelegates: const [
        L.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
