import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../l10n/app_localizations.dart';
import '../theme/section_theme.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import '../theme/haptics.dart';

/// Keep the branch navigator at the same tree position across breakpoints.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final section = AppSection.values[navigationShell.currentIndex];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) ref.read(sectionProvider.notifier).set(section);
    });
    final destinations = <({IconData icon, String label})>[
      (icon: Symbols.home_rounded, label: l.navHome),
      (icon: Symbols.auto_awesome_rounded, label: l.navMatches),
      (icon: Symbols.forum_rounded, label: l.navChat),
      (icon: Symbols.person_rounded, label: l.navProfile),
    ];
    void create() => context.push('/create');
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1000;
        return Scaffold(
          body: Row(
            children: [
              SizedBox(
                width: wide ? 220 : 0,
                child: wide
                    ? SafeArea(
                        child: Column(
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(24),
                              child: BrandMark(size: 36),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        0,
                                        16,
                                        24,
                                      ),
                                      child: FilledButton.icon(
                                        onPressed: create,
                                        icon: const Icon(Icons.add),
                                        label: Text(l.navCreate),
                                      ),
                                    ),
                                    for (final (index, destination)
                                        in destinations.indexed)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 3,
                                        ),
                                        child: ListTile(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          selected:
                                              index ==
                                              navigationShell.currentIndex,
                                          selectedTileColor: Theme.of(
                                            context,
                                          ).colorScheme.primaryContainer,
                                          leading: Icon(destination.icon),
                                          title: Text(destination.label),
                                          onTap: () => _go(index),
                                        ),
                                      ),
                                    const Divider(
                                      indent: 24,
                                      endIndent: 24,
                                      height: 40,
                                    ),
                                    ListTile(
                                      leading: const Icon(
                                        Symbols.settings_rounded,
                                      ),
                                      title: Text(l.navSettings),
                                      onTap: () => context.push('/settings'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : null,
              ),
              Expanded(child: navigationShell),
            ],
          ),
          // Floating liquid glass: the page runs underneath and shows through
          // it, which is what makes it glass rather than a grey strip. Pages
          // keep their last item clear with MediaQuery.paddingOf(context).
          extendBody: true,
          bottomNavigationBar:
              wide || MediaQuery.viewInsetsOf(context).bottom > 0
              ? null
              : SafeArea(
                  top: false,
                  minimum: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                    child: GlassSurface(
                      level: GlassLevel.chrome,
                      specular: true,
                      borderRadius: const BorderRadius.all(Radius.circular(28)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            for (var slot = 0; slot < 5; slot++)
                              Expanded(
                                child: slot == 2
                                    // heightFactor 1: a bare Center grows
                                    // to the bar's full allowed height.
                                    ? Center(
                                        heightFactor: 1,
                                        child: _CreateButton(
                                          label: l.navPost,
                                          onTap: create,
                                        ),
                                      )
                                    : _Destination(
                                        icon:
                                            destinations[slot > 2
                                                    ? slot - 1
                                                    : slot]
                                                .icon,
                                        label:
                                            destinations[slot > 2
                                                    ? slot - 1
                                                    : slot]
                                                .label,
                                        selected:
                                            navigationShell.currentIndex ==
                                            (slot > 2 ? slot - 1 : slot),
                                        onTap: () =>
                                            _go(slot > 2 ? slot - 1 : slot),
                                      ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  void _go(int index) {
    Haptics.selection();
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

/// The one action in the bar: raised olive clay with the logo's gold, so it
/// reads as a button rather than a fifth tab.
class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: ClayTile(
          size: 52,
          radius: 18,
          tone: p.give,
          onTap: () {
            Haptics.light();
            onTap();
          },
          child: Icon(
            Symbols.add_rounded,
            size: 28,
            weight: 700,
            color: p.isDark ? BrandColors.olive900 : BrandColors.goldLight,
          ),
        ),
      ),
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = selected ? colors.primary : colors.onSurfaceVariant;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 30,
                decoration: BoxDecoration(
                  color: selected
                      ? colors.primaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 25,
                  fill: selected ? 1 : 0,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
