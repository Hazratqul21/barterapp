import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';

class NotificationSettingsPage extends ConsumerWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.notificationSettings)),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text(l.pushNotifications),
            subtitle: Text(l.pushNotificationsDesc),
            value: true,
            onChanged: (v) {
              // TODO: PATCH /notification-settings
            },
          ),
        ],
      ),
    );
  }
}
