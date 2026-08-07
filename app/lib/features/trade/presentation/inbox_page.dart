import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/models.dart';
import '../data/trade_repository.dart';

class InboxPage extends ConsumerWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = ref.watch(conversationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.inboxTitle),
        actions: [
          IconButton(
            icon: const Icon(Symbols.notifications_rounded),
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 700), child: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: e.toString(),
          retryLabel: l.retry,
          onRetry: () => ref.invalidate(conversationsProvider),
        ),
        data: (threads) {
          if (threads.isEmpty) {
            return EmptyState(title: l.inboxEmpty, hint: '');
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(conversationsProvider),
            child: ListView.separated(
              itemCount: threads.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final thread = threads[index];
                final isDead = thread.offerStatus == OfferStatus.completed ||
                    thread.offerStatus == OfferStatus.declined ||
                    thread.offerStatus == OfferStatus.expired;

                return AnimatedListItem(
                  index: index,
                  child: Card(
                    color: isDead ? scheme.surfaceContainerLow : scheme.surfaceContainer,
                    child: InkWell(
                      onTap: () => context.push('/chat/${thread.id}'),
                      borderRadius: BorderRadius.circular(20),
                      child: Opacity(
                        opacity: isDead ? 0.6 : 1.0,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Pill(
                                      label: thread.dealSummary,
                                      foreground: isDead ? p.inkSoft : p.give,
                                      background: isDead ? scheme.surfaceContainerHighest : p.giveSoft,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _StatusChip(status: thread.offerStatus),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  TraderAvatar(
                                    url: thread.peer.avatarUrl,
                                    name: thread.peer.name,
                                    isOnline: thread.peer.isOnline,
                                    showPresence: thread.offerStatus.isLive,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                thread.peer.displayName,
                                                style: theme.textTheme.titleMedium?.copyWith(
                                                  fontWeight: thread.unread > 0
                                                      ? FontWeight.bold
                                                      : FontWeight.w600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (thread.lastMessageAt != null)
                                              Text(
                                                _timeAgo(thread.lastMessageAt!, l.localeName),
                                                style: theme.textTheme.labelSmall?.copyWith(
                                                  color: p.inkFaint,
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                thread.lastMessage ?? '',
                                                style: theme.textTheme.bodyMedium?.copyWith(
                                                  color: thread.unread > 0
                                                      ? theme.colorScheme.onSurface
                                                      : p.inkSoft,
                                                  fontWeight: thread.unread > 0
                                                      ? FontWeight.w500
                                                      : FontWeight.normal,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (thread.unread > 0)
                                              Container(
                                                margin: const EdgeInsets.only(left: 8),
                                                padding: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: theme.colorScheme.primary,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Text(
                                                  thread.unread.toString(),
                                                  style: theme.textTheme.labelSmall?.copyWith(
                                                    color: theme.colorScheme.onPrimary,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ))),
    );
  }

  String _timeAgo(DateTime time, String locale) {
    final diff = DateTime.now().difference(time);
    if (diff.inDays > 7) {
      return DateFormat.yMMMd(locale).format(time);
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m';
    } else {
      return 'now';
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final OfferStatus status;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Color bg;
    Color fg;
    String text;

    switch (status) {
      case OfferStatus.pending:
        bg = p.moneySoft;
        fg = p.money;
        text = l.dealPending;
        break;
      case OfferStatus.talking:
        bg = p.giveSoft;
        fg = p.give;
        text = l.dealTalking;
        break;
      case OfferStatus.accepted:
        bg = p.giveSoft;
        fg = p.give;
        text = l.dealAccepted;
        break;
      case OfferStatus.declined:
        bg = scheme.errorContainer;
        fg = scheme.error;
        text = l.dealDeclined;
        break;
      case OfferStatus.expired:
      case OfferStatus.completed:
      case OfferStatus.disputed:
      case OfferStatus.refunded:
      case OfferStatus.draft:
        bg = scheme.surfaceContainerHighest;
        fg = p.inkSoft;
        text = status == OfferStatus.completed ? l.dealCompleted : l.dealExpired;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
