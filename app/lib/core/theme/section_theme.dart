import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_theme.dart';

/// The four places the product is about, in the order the tab bar shows them.
///
/// The index matters: it is the same index `StatefulNavigationShell` uses, so
/// `AppSection.values[currentIndex]` maps a tab straight to its identity
/// without a lookup table that could drift out of order.
enum AppSection { home, matches, chat, profile }

/// Which section the app is currently showing.
///
/// Held globally because the thing that reads it — the wallpaper — sits above
/// the router in `main.dart`, so it cannot be told through the widget tree by
/// the shell that sits below it. The shell writes this on every navigation;
/// the wallpaper watches it and drifts to the new colours.
class SectionController extends Notifier<AppSection> {
  @override
  AppSection build() => AppSection.home;

  void set(AppSection section) {
    if (state != section) state = section;
  }
}

final sectionProvider = NotifierProvider<SectionController, AppSection>(
  SectionController.new,
);

/// The two glow colours the wallpaper wears in a given section.
///
/// The app used one gradient everywhere — green into blue — so moving between
/// tabs changed the content and nothing else, which read as flat. Now each
/// place has a colour of its own, and the background drifts between them:
///
/// * **Home** — green into blue, the barter idea itself (give into take).
/// * **Matches** — gold into green: a match is value found.
/// * **Chat** — blue into violet: conversation, a step away from the trade.
/// * **Profile** — green into gold: warm, personal, what you have earned.
///
/// Colours come from the palette so they are already right for the dark theme;
/// only the violet, which the palette has no slot for, is given per-brightness.
({Color a, Color b}) sectionAura(BarterPalette p, AppSection section) {
  final violet = p.isDark ? const Color(0xFF6D5BC7) : const Color(0xFF7C5CFF);
  return switch (section) {
    AppSection.home => (a: p.giveVivid, b: p.takeVivid),
    AppSection.matches => (a: p.moneyVivid, b: p.giveVivid),
    AppSection.chat => (a: p.takeVivid, b: violet),
    AppSection.profile => (a: p.giveVivid, b: p.moneyVivid),
  };
}
