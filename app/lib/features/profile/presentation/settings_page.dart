import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
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
        title: Text(l.navSettings, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Sizes.contentMax),
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(Gap.x5),
            children: [
              _SectionHeading(l.settingsGeneral),
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerLow,
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Symbols.language_rounded, color: p.give),
                      title: Text(l.profileLanguage),
                      subtitle: Text(l.createGiveHint, style: TextStyle(fontSize: 11, color: p.inkFaint)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(Gap.x4, 0, Gap.x4, Gap.x4),
                      child: Consumer(
                        builder: (context, ref, _) {
                          final locale = ref.watch(localeProvider);
                          return SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'uz', label: Text('UZ')),
                              ButtonSegment(value: 'ru', label: Text('RU')),
                              ButtonSegment(value: 'en', label: Text('EN')),
                            ],
                            selected: {locale},
                            onSelectionChanged: (Set<String> v) {
                              HapticFeedback.lightImpact();
                              ref.read(localeProvider.notifier).set(v.first);
                            },
                            showSelectedIcon: false,
                            style: SegmentedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              selectedBackgroundColor: p.give,
                              selectedForegroundColor: Colors.white,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Gap.h6,
              _SectionHeading(l.settingsSecurity),
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerLow,
                child: Column(
                  children: [
                    _SettingsTile(
                      icon: Symbols.verified_user_rounded,
                      title: l.verifyTitle,
                      onTap: () => context.push('/settings/verify'),
                    ),
                    const _Divider(),
                    _SettingsTile(
                      icon: Symbols.account_balance_wallet_rounded,
                      title: l.paymentsTitle,
                      onTap: () => context.push('/settings/payments'),
                    ),
                  ],
                ),
              ),
              Gap.h10,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.x2),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: Radii.rMd),
                  ),
                  icon: const Icon(Symbols.logout_rounded),
                  label: Text(l.authSignOut),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    ref.read(authStateProvider.notifier).signOut();
                    context.go('/home');
                  },
                ),
              ),
            ],
          ).animate().fadeIn(duration: M3Motion.medium2),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.x2, Gap.x2, Gap.x2, Gap.x3),
        child: Text(text.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: palette(context).inkFaint, letterSpacing: 1.2)),
      );
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.icon, required this.title, required this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, size: 22, color: palette(context).inkSoft),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Icon(Symbols.chevron_right_rounded, color: palette(context).inkFaint),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
      );
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Divider(height: 1, indent: 56, color: palette(context).hair.withValues(alpha: 0.5));
}
