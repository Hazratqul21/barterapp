import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/models.dart';
import '../data/trade_repository.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.notificationsTitle),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(tradeRepositoryProvider).markRead();
              ref.invalidate(notificationsProvider);
            },
            child: Text(l.notificationsMarkAll),
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => ErrorState(
          message: errorMessage(context, e),
          retryLabel: l.retry,
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return EmptyState(
              title: l.notificationsEmpty,
              hint: '',
            );
          }

          final now = DateTime.now();
          final today = <AppNotification>[];
          final earlier = <AppNotification>[];

          for (final n in notifications) {
            final date = n.createdAt.toLocal();
            if (date.day == now.day && date.month == now.month && date.year == now.year) {
              today.add(n);
            } else {
              earlier.add(n);
            }
          }

          final listItems = <Widget>[];
          if (today.isNotEmpty) {
            listItems.add(
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Text(
                  'Today',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: p.inkSoft,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            );
            listItems.addAll(today.map((n) => _NotificationTile(n)));
          }

          if (earlier.isNotEmpty) {
            listItems.add(
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Text(
                  'Earlier',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: p.inkSoft,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            );
            listItems.addAll(earlier.map((n) => _NotificationTile(n)));
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(notificationsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: listItems.length,
              itemBuilder: (context, index) {
                return AnimatedListItem(
                  index: index,
                  child: listItems[index],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile(this.notification);

  final AppNotification notification;

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = palette(context);
    final theme = Theme.of(context);

    Widget leading;
    if (notification.avatarUrl != null) {
      leading = TraderAvatar(
        url: notification.avatarUrl,
        name: '',
        size: 40,
      );
    } else {
      IconData icon;
      Color color;
      switch (notification.kind) {
        case 'offer':
          icon = Symbols.swap_horiz_rounded;
          color = p.give;
          break;
        case 'match':
          icon = Symbols.auto_awesome_rounded;
          color = p.money;
          break;
        case 'message':
          icon = Symbols.forum_rounded;
          color = p.take;
          break;
        default:
          icon = Symbols.shield_rounded;
          color = p.inkSoft;
      }
      leading = CircleAvatar(
        radius: 20,
        backgroundColor: color.withValues(alpha: 0.1),
        child: Icon(icon, color: color, size: 20),
      );
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: leading,
      title: Text(
        notification.title,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: notification.isUnread ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          notification.body,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: p.inkSoft,
          ),
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTimeAgo(notification.createdAt),
            style: theme.textTheme.labelMedium?.copyWith(
              color: p.inkFaint,
            ),
          ),
          if (notification.isUnread) ...[
            const SizedBox(height: 8),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.tertiary,
              ),
            ),
          ],
        ],
      ),
      onTap: () async {
        if (notification.isUnread) {
          await ref.read(tradeRepositoryProvider).markRead(ids: [notification.id]);
          ref.invalidate(notificationsProvider);
        }

        if (!context.mounted) return;

        switch (notification.targetType) {
          case NotifyTargetType.chat:
            if (notification.targetId != null) {
              context.push('/chat/${notification.targetId}');
            }
            break;
          case NotifyTargetType.matches:
            context.go('/matches');
            break;
          case NotifyTargetType.verification:
            context.push('/settings/verify');
            break;
          case NotifyTargetType.listing:
            if (notification.targetId != null) {
              context.push('/listing/${notification.targetId}');
            }
            break;
        }
      },
    );
  }
}
