import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

const kWebBreakpoint = 900.0;

class WebShell extends StatelessWidget {
  const WebShell({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.onDestination,
  });

  final Widget child;
  final int currentIndex;
  final ValueChanged<int> onDestination;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);

    final destinations = <({IconData icon, String label})>[
      (icon: Symbols.home_rounded, label: l.navHome),
      (icon: Symbols.auto_awesome_rounded, label: l.navMatches),
      (icon: Symbols.forum_rounded, label: l.navChat),
      (icon: Symbols.person_rounded, label: l.navProfile),
    ];

    return Scaffold(
      body: Row(
        children: [
          // ── Premium M3 Side Rail ───────────────────────────────────────────
          Container(
            width: 80,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              border: Border(right: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Gap.x6),
                    child: BrandMark(size: 44),
                  ),

                  // Create FAB - Rail version
                  Padding(
                    padding: const EdgeInsets.only(bottom: Gap.x4),
                    child: FloatingActionButton(
                      mini: true,
                      heroTag: 'rail-create',
                      onPressed: () => context.push('/create'),
                      child: const Icon(Symbols.add_rounded, size: 24),
                    ),
                  ),

                  for (final (index, d) in destinations.indexed)
                    _RailItem(
                      icon: d.icon,
                      label: d.label,
                      selected: index == currentIndex,
                      onTap: () => onDestination(index),
                    ),

                  const Spacer(),

                  _RailItem(
                    icon: Symbols.settings_rounded,
                    label: l.navSettings,
                    onTap: () => context.push('/settings'),
                  ),
                  Gap.h4,
                ],
              ),
            ),
          ),

          Expanded(
            child: Container(
              color: theme.colorScheme.surface,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = palette(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Tooltip(
        message: label,
        preferBelow: false,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 56,
                height: 32,
                decoration: BoxDecoration(
                  color: selected ? theme.colorScheme.secondaryContainer : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  fill: selected ? 1 : 0,
                  color: selected ? theme.colorScheme.onSecondaryContainer : p.inkSoft,
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  color: selected ? theme.colorScheme.onSurface : p.inkFaint,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
