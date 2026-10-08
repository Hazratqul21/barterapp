import re

with open('lib/features/auth/data/auth_repository.dart', 'r') as f:
    content = f.read()

methods = """
  Future<NotificationSettings> getNotificationSettings() =>
      _api.get('/notification-settings', parse: (data) => NotificationSettings.fromJson(data));

  Future<NotificationSettings> updateNotificationSettings(Map<String, dynamic> data) =>
      _api.patch('/notification-settings', body: data, parse: (d) => NotificationSettings.fromJson(d));
"""

# Insert before signOut() => _session.clear();
content = content.replace('  Future<void> signOut() => _session.clear();', methods + '\n  Future<void> signOut() => _session.clear();')

with open('lib/features/auth/data/auth_repository.dart', 'w') as f:
    f.write(content)
