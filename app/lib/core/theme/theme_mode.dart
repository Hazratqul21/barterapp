import 'dart:ui' show Brightness, PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart' show sharedPreferencesProvider;

/// Dark or light. Until someone picks, the phone's own setting decides; once
/// they do, the choice survives a restart — it used to reset to light on
/// every launch.
class _DarkModeNotifier extends Notifier<bool> {
  static const key = 'dark_mode';

  @override
  bool build() =>
      ref.read(sharedPreferencesProvider).getBool(key) ??
      PlatformDispatcher.instance.platformBrightness == Brightness.dark;

  void set(bool v) {
    state = v;
    ref.read(sharedPreferencesProvider).setBool(key, v);
  }
}

final darkModeProvider = NotifierProvider<_DarkModeNotifier, bool>(
  _DarkModeNotifier.new,
);
