import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../auth/data/auth_repository.dart';
import '../../../shared/models/models.dart';
import '../../../core/theme/tokens.dart';

final notificationSettingsProvider =
    FutureProvider.autoDispose<NotificationSettings>((ref) {
      return ref.watch(authRepositoryProvider).getNotificationSettings();
    });

class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  ConsumerState<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState
    extends ConsumerState<NotificationSettingsPage> {
  Future<void> _update(Map<String, dynamic> data) async {
    try {
      await ref.read(authRepositoryProvider).updateNotificationSettings(data);
      ref.invalidate(notificationSettingsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(L.of(context).errorGeneric)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final asyncSettings = ref.watch(notificationSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.notificationSettings),
        backgroundColor: Colors.transparent,
      ),
      body: asyncSettings.when(
        data: (settings) => ListView(
          padding: const EdgeInsets.all(Gap.x4),
          children: [
            SwitchListTile(
              title: Text(l.notifOffers),
              subtitle: Text(l.notifOffersDesc),
              value: settings.offers,
              onChanged: (v) => _update({'offers': v}),
            ),
            SwitchListTile(
              title: Text(l.notifMatches),
              subtitle: Text(l.notifMatchesDesc),
              value: settings.matches,
              onChanged: (v) => _update({'matches': v}),
            ),
            SwitchListTile(
              title: Text(l.notifMessages),
              subtitle: Text(l.notifMessagesDesc),
              value: settings.messages,
              onChanged: (v) => _update({'messages': v}),
            ),
            SwitchListTile(
              title: Text(l.notifSystem),
              subtitle: Text(l.notifSystemDesc),
              value: settings.system,
              onChanged: (v) => _update({'system': v}),
            ),
            const Divider(),
            ListTile(
              title: Text(l.notifQuietHours),
              subtitle: Text(
                settings.quietFrom != null && settings.quietTo != null
                    ? '${settings.quietFrom}:00 dan ${settings.quietTo}:00 gacha'
                    : l.notifOff,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final TimeOfDay? from = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(
                    hour: settings.quietFrom ?? 22,
                    minute: 0,
                  ),
                  helpText: l.notifQuietHoursStart,
                );
                if (from == null) return;

                if (context.mounted) {
                  final TimeOfDay? to = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                      hour: settings.quietTo ?? 7,
                      minute: 0,
                    ),
                    helpText: l.notifQuietHoursEnd,
                  );
                  if (to != null) {
                    _update({'quiet_from': from.hour, 'quiet_to': to.hour});
                  }
                }
              },
            ),
            if (settings.quietFrom != null || settings.quietTo != null)
              TextButton(
                onPressed: () =>
                    _update({'quiet_from': null, 'quiet_to': null}),
                child: Text(l.notifQuietHoursDisable),
              ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Text(
            l.errorGeneric,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ),
      ),
    );
  }
}
