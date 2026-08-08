import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// The four places this product is about, and the button that feeds it.
///
/// One layout, on every platform. Past 700px the app used to grow a left-hand
/// drawer instead — a second navigation model, with its own chrome and its own
/// layouts to keep in step with the first. A person opening the site on a
/// laptop is looking at the same marketplace, not a different product, so the
/// desktop shows the phone (see `DeviceFrame`) rather than rearranging itself.
///
/// Settings is deliberately absent: it is somewhere you go from your own
/// profile to change something, not a fifth destination.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    final destinations = <({IconData icon, String label})>[
      (icon: Symbols.home_rounded, label: l.navHome),
      (icon: Symbols.auto_awesome_rounded, label: l.navMatches),
      (icon: Symbols.forum_rounded, label: l.navChat),
      (icon: Symbols.person_rounded, label: l.navProfile),
    ];

    return Scaffold(
      body: navigationShell,
      floatingActionButton:
          FloatingActionButton(
                heroTag: 'create-fab',
                tooltip: l.navCreate,
                onPressed: () => context.push('/create'),
                child: const Icon(Symbols.add_rounded, size: 26, weight: 600),
              )
              .animate()
              .scale(
                begin: Offset.zero,
                end: const Offset(1, 1),
                duration: M3Motion.medium4,
                curve: M3Motion.emphasizedDecelerate,
              )
              .fadeIn(duration: M3Motion.medium2),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _go,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          for (final d in destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.icon, fill: 1),
              label: d.label,
            ),
        ],
      ),
    );
  }

  void _go(int index) {
    // Tapping the active tab pops that branch back to its root, the way every
    // native tab bar behaves.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}
