import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// One breakpoint decides the whole layout. Below it the app is a phone with a
/// tab bar; above it — tablet, desktop, wide browser — the same destinations
/// move to a side rail, which is all "Flutter for web and mobile" really means
/// once the screens themselves are responsive.
const kRailBreakpoint = 700.0;

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final scheme = Theme.of(context).colorScheme;

    final destinations = <({IconData icon, IconData active, String label})>[
      (
        icon: Symbols.home_rounded,
        active: Symbols.home_rounded,
        label: l.navHome,
      ),
      (
        icon: Symbols.auto_awesome_rounded,
        active: Symbols.auto_awesome_rounded,
        label: l.navMatches,
      ),
      (
        icon: Symbols.forum_rounded,
        active: Symbols.forum_rounded,
        label: l.navChat,
      ),
      (
        icon: Symbols.person_rounded,
        active: Symbols.person_rounded,
        label: l.navProfile,
      ),
      // Settings is not a destination. It is somewhere you go from your own
      // profile, once, to change something — not one of the four places the
      // product is actually about. Giving it a fifth of the bar put a gear icon
      // next to the trades it exists to support.
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= kRailBreakpoint;

        if (wide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationDrawer(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: _go,
                  backgroundColor: scheme.surfaceContainer,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                      child: FloatingActionButton.extended(
                        heroTag: 'create-rail',
                        tooltip: l.navCreate,
                        onPressed: () => context.push('/create'),
                        icon: const Icon(Symbols.add_rounded, size: 24),
                        label: Text(l.navCreate),
                        elevation: 0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final d in destinations)
                      NavigationDrawerDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.active),
                        label: Text(d.label),
                      ),
                  ],
                ),
                VerticalDivider(
                  width: 1,
                  color: scheme.outlineVariant.withValues(alpha: 0.4),
                ),
                Expanded(
                  child: navigationShell,
                ),
              ],
            ),
          );
        }

        // ── Mobile Layout ─────────────────────────────────────────────────
        return Scaffold(
          body: navigationShell,
          floatingActionButton: FloatingActionButton(
            heroTag: 'create-fab',
            tooltip: l.navCreate,
            onPressed: () => context.push('/create'),
            child: const Icon(Symbols.add_rounded, size: 24),
          )
              .animate()
              .scale(
                begin: const Offset(0, 0),
                end: const Offset(1, 1),
                duration: M3Motion.medium4,
                curve: M3Motion.emphasizedDecelerate,
              )
              .fadeIn(duration: M3Motion.medium2),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.endFloat,
          bottomNavigationBar: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _go,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              for (final d in destinations)
                NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.active),
                  label: d.label,
                ),
            ],
          ),
        );
      },
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
