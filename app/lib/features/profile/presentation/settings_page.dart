import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_mode.dart';
import '../../../core/theme/tokens.dart';
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
    final locale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l.navSettings,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Align(
          key: ValueKey(locale),
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Sizes.contentMax),
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(Gap.x5),
              children: [
                _SectionHeading(l.settingsGeneral),
                BouncingClayCard(
                  clayMode: true,
                  borderRadius: Radii.rLg,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: Radii.rLg,
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(
                            Symbols.language_rounded,
                            color: p.give,
                          ),
                          title: Text(l.profileLanguage),
                          subtitle: Text(
                            l.createGiveHint,
                            style: TextStyle(fontSize: 11, color: p.inkFaint),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            Gap.x4,
                            0,
                            Gap.x4,
                            Gap.x4,
                          ),
                          child: SegmentedButton<String>(
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
                          ),
                        ),
                        const _Divider(),
                        Consumer(
                          builder: (context, ref, _) {
                            final isDark = ref.watch(darkModeProvider);
                            return ListTile(
                              leading: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 400),
                                transitionBuilder: (child, anim) =>
                                    RotationTransition(
                                      turns: child.key == const ValueKey('dark')
                                          ? Tween<double>(
                                              begin: 0.5,
                                              end: 1.0,
                                            ).animate(anim)
                                          : Tween<double>(
                                              begin: -0.5,
                                              end: 0.0,
                                            ).animate(anim),
                                      child: ScaleTransition(
                                        scale: anim,
                                        child: child,
                                      ),
                                    ),
                                child: Icon(
                                  isDark
                                      ? Symbols.dark_mode_rounded
                                      : Symbols.light_mode_rounded,
                                  key: ValueKey(isDark ? 'dark' : 'light'),
                                  color: p.give,
                                ),
                              ),
                              title: Text(l.actionDarkMode),
                              trailing: Switch(
                                value: isDark,
                                onChanged: (v) =>
                                    ref.read(darkModeProvider.notifier).set(v),
                              ),
                            );
                          },
                        ),
                        const _Divider(),
                        Consumer(
                          builder: (context, ref, _) => ListTile(
                            leading: const Icon(Symbols.notifications_rounded),
                            title: Text(l.notificationSettings),
                            trailing: const Icon(Symbols.chevron_right_rounded),
                            onTap: () {
                              context.push('/profile/notification-settings');
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Gap.h6,
                _SectionHeading(l.settingsSecurity),
                BouncingClayCard(
                  clayMode: true,
                  borderRadius: Radii.rLg,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: Radii.rLg,
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
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
                ),
                Gap.h6,
                const _SectionHeading('LEGAL'), // TODO: localize
                BouncingClayCard(
                  clayMode: true,
                  borderRadius: Radii.rLg,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: Radii.rLg,
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        _SettingsTile(
                          icon: Symbols.policy_rounded,
                          title: 'Privacy Policy', // TODO: localize
                          onTap: () => launchUrl(
                            Uri.parse('https://example.com/privacy'),
                          ),
                        ),
                        const _Divider(),
                        _SettingsTile(
                          icon: Symbols.description_rounded,
                          title: 'Terms of Service', // TODO: localize
                          onTap: () =>
                              launchUrl(Uri.parse('https://example.com/terms')),
                        ),
                      ],
                    ),
                  ),
                ),
                Gap.h10,
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.x2),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(
                        color: theme.colorScheme.error.withValues(alpha: 0.5),
                      ),
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
                Gap.h4,
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.x2),
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: Radii.rMd),
                    ),
                    icon: const Icon(Symbols.delete_forever_rounded),
                    label: Text(l.actionDeleteAccount),
                    onPressed: () async {
                      HapticFeedback.heavyImpact();
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) {
                          final tl = L.of(ctx);
                          return AlertDialog(
                            title: Text(tl.actionDeleteAccount),
                            content: const Text(
                              'Are you sure you want to delete your account? This action cannot be undone and your data will be permanently deleted.',
                            ), // TODO: localize
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: Text(tl.actionCancel),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: Theme.of(
                                    ctx,
                                  ).colorScheme.error,
                                ),
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: Text(tl.actionDelete),
                              ),
                            ],
                          );
                        },
                      );
                      if (confirm == true) {
                        await ref.read(authRepositoryProvider).deleteAccount();
                        ref.read(authStateProvider.notifier).signOut();
                        if (context.mounted) context.go('/home');
                      }
                    },
                  ),
                ),
              ],
            ).animate().fadeIn(duration: M3Motion.medium2),
          ),
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
    child: Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: palette(context).inkFaint,
        letterSpacing: 1.2,
      ),
    ),
  );
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, size: 22, color: palette(context).inkSoft),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    trailing: Icon(
      Symbols.chevron_right_rounded,
      color: palette(context).inkFaint,
    ),
    onTap: () {
      HapticFeedback.lightImpact();
      onTap();
    },
  );
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    indent: 56,
    color: palette(context).hair.withValues(alpha: 0.5),
  );
}
