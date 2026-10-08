import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/network/api_client.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode.dart';
import 'core/widgets/device_frame.dart';
import 'l10n/app_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/notifications/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    if (kDebugMode) debugPrint('Firebase init failed: $e');
  }

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
  void initState() {
    super.initState();
    // The language is passed in so the server knows which one to send a
    // notification in. Without it every push would arrive in Uzbek,
    // including to someone reading the app in Russian.
    ref
        .read(notificationServiceProvider)
        .init(locale: ref.read(localeProvider));
  }

  @override
  Widget build(BuildContext context) {
    // One piece of state drives both the widgets and the Accept-Language
    // header, so the interface and the content can never end up in two
    // different languages on the same screen.
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'MAB',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(darkModeProvider) ? ThemeMode.dark : ThemeMode.light,
      // Ordinary routes share a quiet, opaque canvas. Decorative aurora is
      // opt-in for the few picture-free sheets that actually benefit from it;
      // keeping it out of the app root avoids a permanent animated layer under
      // every scrollable route.
      // The theme makes every Scaffold transparent so screens with their own
      // backdrop (aurora, glass) show through. This is what they show through
      // to: an opaque surface. It used to be scaffoldBackgroundColor — i.e.
      // transparent — so a page without its own backdrop (the listing
      // detail) was drawn over nothing.
      builder: (context, child) => ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: DeviceFrame(child: child ?? const SizedBox.shrink()),
      ),
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
