import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/data/auth_repository.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.navSettings),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  l.settingsGeneral,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: p.inkSoft,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    ListTile(
                      title: Text(l.profileLanguage, style: theme.textTheme.bodyLarge),
                      leading: const Icon(Symbols.language_rounded),
                      trailing: Consumer(
                        builder: (context, ref, _) {
                          final locale = ref.watch(localeProvider);
                          return SegmentedButton<String>(
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment(value: 'uz', label: Text('UZ')),
                              ButtonSegment(value: 'ru', label: Text('RU')),
                              ButtonSegment(value: 'en', label: Text('EN')),
                            ],
                            selected: {locale},
                            onSelectionChanged: (set) =>
                                ref.read(localeProvider.notifier).set(set.first),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  l.settingsSecurity,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: p.inkSoft,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Symbols.verified_user_rounded),
                      title: Text(l.verifyTitle, style: theme.textTheme.bodyLarge),
                      trailing: const Icon(Symbols.chevron_right_rounded),
                      onTap: () => context.push('/settings/verify'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Symbols.account_balance_wallet_rounded),
                      title: Text(l.paymentsTitle, style: theme.textTheme.bodyLarge),
                      trailing: const Icon(Symbols.chevron_right_rounded),
                      onTap: () => context.push('/settings/payments'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    foregroundColor: p.take,
                    backgroundColor: p.take.withValues(alpha: 0.1),
                    padding: const EdgeInsets.all(16),
                  ),
                  icon: const Icon(Symbols.logout_rounded),
                  label: Text(l.authSignOut),
                  // Through the notifier, not the repository: the repository
                  // only clears storage, which left `authStateProvider` still
                  // reporting a signed-in session.
                  onPressed: () => ref.read(authStateProvider.notifier).signOut(),
                ),
              ),
            ],
          ).animate().fadeIn(duration: M3Motion.medium2, curve: M3Motion.standard),
        ),
      ),
    );
  }
}
