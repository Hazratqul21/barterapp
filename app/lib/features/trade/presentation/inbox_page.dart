import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/router/web_shell.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/models.dart';
import '../../auth/data/auth_repository.dart';
import '../data/trade_repository.dart';
import 'chat_page.dart';

class InboxPage extends ConsumerStatefulWidget {
  const InboxPage({super.key});

  @override
  ConsumerState<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends ConsumerState<InboxPage> {
  String? _open;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final threads = ref.watch(conversationsProvider);
    final wide = MediaQuery.sizeOf(context).width >= kWebBreakpoint;

    if (!ref.watch(authStateProvider)) {
      return Scaffold(
        appBar: AppBar(title: Text(l.inboxTitle)),
        body: SignInPrompt(reason: l.inboxSignIn),
      );
    }

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            SizedBox(
              width: 380,
              child: _ThreadList(
                threads: threads,
                selectedId: _open,
                onSelect: (id) {
                  HapticFeedback.selectionClick();
                  setState(() => _open = id);
                },
                onRetry: () => ref.invalidate(conversationsProvider),
              ),
            ),
            VerticalDivider(width: 1, color: p.hair),
            Expanded(
              child: _open == null
                  ? EmptyState(
                      title: l.inboxTitle,
                      hint: l.inboxPickThread,
                    )
                  : ChatPage(
                      key: ValueKey(_open),
                      conversationId: _open!,
                      embedded: true,
                    ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.inboxTitle),
        actions: [
          IconButton(
            tooltip: l.notificationsTitle,
            icon: const Icon(Symbols.notifications_rounded),
            onPressed: () {
              HapticFeedback.lightImpact();
              context.push('/notifications');
            },
          ),
          Gap.w2,
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Sizes.contentMax),
          child: _ThreadList(
            threads: threads,
            selectedId: null,
            onSelect: (id) {
              HapticFeedback.lightImpact();
              context.push('/chat/$id');
            },
            onRetry: () => ref.invalidate(conversationsProvider),
          ),
        ),
      ),
    );
  }
}

class _ThreadList extends StatelessWidget {
  const _ThreadList({
    required this.threads,
    required this.selectedId,
    required this.onSelect,
    required this.onRetry,
  });

  final AsyncValue<List<ConversationSummary>> threads;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final bottomPadding = MediaQuery.paddingOf(context).bottom + Gap.x14;

    return threads.fade(
      identity: threads.value?.length,
      loading: () => const _InboxShimmer(),
      error: (e) => ErrorState(
        message: errorMessage(context, e),
        retryLabel: l.retry,
        onRetry: onRetry,
      ),
      data: (items) => items.isEmpty
          ? EmptyState(title: l.inboxEmpty, hint: l.inboxEmptyHint)
          : RefreshIndicator(
              onRefresh: () async => onRetry(),
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(Gap.x4, Gap.x4, Gap.x4, bottomPadding),
                itemCount: items.length,
                separatorBuilder: (_, _) => Gap.h3,
                itemBuilder: (context, index) => AnimatedListItem(
                  index: index,
                  child: Dismissible(
                    key: ValueKey(items[index].id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: Gap.x4),
                      color: Theme.of(context).colorScheme.error,
                      child: const Icon(Symbols.archive_rounded, color: Colors.white),
                    ),
                    onDismissed: (_) {
                      debugPrint('Archived ${items[index].id}');
                    },
                    child: _ThreadCard(
                      thread: items[index],
                      selected: items[index].id == selectedId,
                      onTap: () => onSelect(items[index].id),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _ThreadCard extends StatelessWidget {
  const _ThreadCard({
    required this.thread,
    required this.selected,
    required this.onTap,
  });

  final ConversationSummary thread;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);

    final live = thread.offerStatus.isLive;
    final unread = thread.unread > 0;

    return Card(
      elevation: 0,
      color: selected ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5) : theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.rLg,
        side: BorderSide(
          color: selected ? p.give : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.rLg,
        child: Opacity(
          opacity: live ? 1 : 0.62,
          child: Padding(
            padding: const EdgeInsets.all(Gap.x4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: Gap.x2,
                        children: [
                          Text(thread.gives, style: theme.textTheme.titleSmall),
                          Icon(Symbols.swap_horiz_rounded, size: Sizes.iconMd, color: p.inkFaint),
                          Text(thread.receives, style: theme.textTheme.titleSmall),
                        ],
                      ),
                    ),
                    Gap.w2,
                    _StatusPill(status: thread.offerStatus),
                  ],
                ),
                if (thread.cash.minor > 0) ...[
                  Gap.h2,
                  Row(
                    children: [
                      Icon(Symbols.payments_rounded, size: Sizes.iconSm, color: p.money),
                      Gap.w1,
                      Text(
                        thread.cash.format(l.localeName),
                        style: theme.textTheme.labelLarge?.copyWith(color: p.money),
                      ),
                    ],
                  ),
                ],
                Gap.h3,
                Divider(color: p.hair.withValues(alpha: 0.5), height: 1),
                Gap.h3,
                Row(
                  children: [
                    TraderAvatar(
                      url: thread.peer.avatarUrl,
                      name: thread.peer.name,
                      size: Sizes.avatarMd,
                      isOnline: thread.peer.isOnline,
                      showPresence: live,
                    ),
                    Gap.w3,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (unread) ...[
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(color: p.money, shape: BoxShape.circle),
                                ),
                                Gap.w2,
                              ],
                              Expanded(
                                child: Text(
                                  thread.peer.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (thread.lastMessageAt != null) ...[
                                Gap.w2,
                                Text(
                                  timeAgo(context, thread.lastMessageAt!),
                                  style: theme.textTheme.bodySmall?.copyWith(color: p.inkFaint, fontSize: 11),
                                ),
                              ],
                            ],
                          ),
                          Gap.h1,
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  thread.lastMessage ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: unread ? theme.colorScheme.onSurface : p.inkSoft,
                                    fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                                  ),
                                ),
                              ),
                              if (unread) ...[
                                Gap.w2,
                                _UnreadBadge(count: thread.unread),
                              ],
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
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final OfferStatus status;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final (label, colour, tint) = switch (status) {
      OfferStatus.pending => (l.dealPending, p.money, p.moneySoft),
      OfferStatus.talking => (l.dealTalking, p.take, p.takeSoft),
      OfferStatus.accepted => (l.dealAccepted, p.give, p.giveSoft),
      OfferStatus.completed => (l.dealCompleted, p.give, p.giveSoft),
      OfferStatus.declined => (l.dealDeclined, Theme.of(context).colorScheme.error, Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.5)),
      _ => (l.dealExpired, p.inkSoft, p.sunken),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.x2, vertical: 2),
      decoration: BoxDecoration(color: tint, borderRadius: Radii.rFull),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colour, fontSize: 9, fontWeight: FontWeight.w800)),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: palette(context).money, shape: BoxShape.circle),
      child: Text('$count', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

class _InboxShimmer extends StatelessWidget {
  const _InboxShimmer();
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(Gap.x4),
      itemCount: 5,
      separatorBuilder: (_, _) => Gap.h3,
      itemBuilder: (context, index) => Card(
        child: Padding(
          padding: const EdgeInsets.all(Gap.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonBox(height: 16, width: 200),
              Gap.h4,
              Row(
                children: [
                  const SkeletonBox(width: 44, height: 44, radius: Radii.rFull),
                  Gap.w3,
                  const Expanded(child: SkeletonBox(height: 14)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
