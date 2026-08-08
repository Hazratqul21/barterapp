import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/models.dart';
import '../data/trade_repository.dart';

/// Threads, each one anchored to the trade that opened it.
///
/// The deal sits above the message on every row. A conversation here exists
/// because somebody made an offer — it is not a chat that happens to mention
/// goods — and the row says so before it says anything else.
class InboxPage extends ConsumerWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final threads = ref.watch(conversationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.inboxTitle),
        actions: [
          IconButton(
            tooltip: l.notificationsTitle,
            icon: const Icon(Symbols.notifications_rounded),
            onPressed: () => context.push('/notifications'),
          ),
          Gap.w2,
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Sizes.contentMax),
          child: threads.when(
            loading: () => const _InboxShimmer(),
            error: (e, _) => ErrorState(
              message: errorMessage(context, e),
              retryLabel: l.retry,
              onRetry: () => ref.invalidate(conversationsProvider),
            ),
            data: (items) => items.isEmpty
                ? EmptyState(title: l.inboxEmpty, hint: l.inboxEmptyHint)
                : RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(conversationsProvider),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        Gap.x5,
                        Gap.x4,
                        Gap.x5,
                        Gap.x14,
                      ),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => Gap.h3,
                      itemBuilder: (context, index) =>
                          _ThreadCard(thread: items[index]),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ThreadCard extends StatelessWidget {
  const _ThreadCard({required this.thread});

  final ConversationSummary thread;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);

    // A finished, refused or lapsed trade is history: the row stays readable
    // but stops asking for attention.
    final live = thread.offerStatus.isLive;
    final unread = thread.unread > 0;

    return Card(
      child: InkWell(
        onTap: () => context.push('/chat/${thread.id}'),
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
                      child: Text(
                        thread.dealSummary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          height: 1.35,
                        ),
                      ),
                    ),
                    Gap.w2,
                    _StatusPill(status: thread.offerStatus),
                  ],
                ),

                // Formatted here, in the reader's language. The server used to
                // append "1260000 USD" to the sentence above.
                if (thread.cash.minor > 0) ...[
                  Gap.h2,
                  Row(
                    children: [
                      Icon(
                        Symbols.payments_rounded,
                        size: Sizes.iconSm,
                        color: p.money,
                      ),
                      Gap.w1,
                      Text(
                        thread.cash.format(l.localeName),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: p.money,
                        ),
                      ),
                    ],
                  ),
                ],

                Gap.h3,
                Divider(color: p.hair, height: 1),
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
                              Expanded(
                                child: Text(
                                  thread.peer.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: unread
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (thread.lastMessageAt != null) ...[
                                Gap.w2,
                                Text(
                                  _ago(context, thread.lastMessageAt!),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: p.inkFaint,
                                  ),
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
                                    color: unread
                                        ? theme.colorScheme.onSurface
                                        : p.inkSoft,
                                    fontWeight: unread
                                        ? FontWeight.w500
                                        : FontWeight.w400,
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

  /// How long ago, in words the reader's language has.
  ///
  /// The old row wrote "3d", "5h", "now" straight into the widget — English
  /// abbreviations on a Russian screen.
  String _ago(BuildContext context, DateTime at) {
    final l = L.of(context);
    final diff = DateTime.now().difference(at);

    if (diff.inDays > 6) {
      return DateFormat.MMMd(l.localeName).format(at.toLocal());
    }
    if (diff.inDays >= 1) return l.agoDays(diff.inDays);
    if (diff.inHours >= 1) return l.agoHours(diff.inHours);
    if (diff.inMinutes >= 1) return l.agoMinutes(diff.inMinutes);
    return l.agoNow;
  }
}

/// Where the trade stands, in one word.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final OfferStatus status;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final scheme = Theme.of(context).colorScheme;

    final (label, colour, tint) = switch (status) {
      OfferStatus.pending => (l.dealPending, p.money, p.moneySoft),
      OfferStatus.talking => (l.dealTalking, p.take, p.takeSoft),
      OfferStatus.accepted => (l.dealAccepted, p.give, p.giveSoft),
      OfferStatus.completed => (l.dealCompleted, p.give, p.giveSoft),
      OfferStatus.declined => (
        l.dealDeclined,
        scheme.error,
        scheme.errorContainer,
      ),
      _ => (l.dealExpired, p.inkSoft, p.sunken),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.x2 + 2,
        vertical: Gap.x1 + 1,
      ),
      decoration: BoxDecoration(color: tint, borderRadius: Radii.rFull),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: colour),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: p.money, borderRadius: Radii.rFull),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _InboxShimmer extends StatelessWidget {
  const _InboxShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(Gap.x5, Gap.x4, Gap.x5, Gap.x14),
      itemCount: 4,
      separatorBuilder: (_, _) => Gap.h3,
      itemBuilder: (context, index) => Card(
        child: Padding(
          padding: const EdgeInsets.all(Gap.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonBox(height: 16),
              Gap.h4,
              Row(
                children: [
                  const SkeletonBox(
                    width: Sizes.avatarMd,
                    height: Sizes.avatarMd,
                    radius: Radii.rFull,
                  ),
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
