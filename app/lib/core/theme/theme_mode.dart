import 'package:flutter_riverpod/flutter_riverpod.dart';

class _DarkModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool v) => state = v;
}

final darkModeProvider = NotifierProvider<_DarkModeNotifier, bool>(
  _DarkModeNotifier.new,
);
