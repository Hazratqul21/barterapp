import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'web_shell.dart';

/// The four places this product is about, and the button that feeds it.
///
/// Two shapes for the same product. A tab bar exists because a thumb reaches
/// the bottom of a phone; on a laptop nothing reaches the bottom of the window,
/// so past [kWebBreakpoint] the destinations stand up the left-hand side
/// instead (`WebShell`). Same screens, same data, same design language.
///
/// Settings is absent from the phone bar: it is somewhere you go from your own
/// profile to change something, not a fifth destination. The desktop sidebar
/// has room for it at the foot, where it does not compete.
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

    if (MediaQuery.sizeOf(context).width >= kWebBreakpoint) {
      return WebShell(
        currentIndex: navigationShell.currentIndex,
        onDestination: _go,
        child: navigationShell,
      );
    }

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
