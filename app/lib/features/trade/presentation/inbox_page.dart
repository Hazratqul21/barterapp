import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/router/web_shell.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/models.dart';
import '../../auth/data/auth_repository.dart';
import '../data/trade_repository.dart';
import 'chat_page.dart';

/// Threads, each one anchored to the trade that opened it.
///
/// The deal sits above the message on every row. A conversation here exists
/// because somebody made an offer — it is not a chat that happens to mention
/// goods — and the row says so before it says anything else.
class InboxPage extends ConsumerStatefulWidget {
  const InboxPage({super.key});

  @override
  ConsumerState<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends ConsumerState<InboxPage> {
  /// The thread open in the right-hand pane. Desktop only — on a phone a row
  /// pushes a screen instead.
  String? _open;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final threads = ref.watch(conversationsProvider);
    final wide = MediaQuery.sizeOf(context).width >= kWebBreakpoint;

    // Checked before the data, not after: without an account there is nothing
    // to fetch, and "no conversations" would be a claim about an account that
    // does not exist.
    if (!ref.watch(authStateProvider)) {
      return Scaffold(
        appBar: AppBar(title: Text(l.inboxTitle)),
        body: SignInPrompt(reason: l.inboxSignIn),
      );
    }

    // Two panes on a desktop: the list stays put and the conversation opens
    // beside it. Replacing the whole window with one thread — and making the
    // reader navigate back to see the next — is a phone's compromise, not a
    // desk's.
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            SizedBox(
              width: 380,
              child: _ThreadList(
                threads: threads,
                selectedId: _open,
                onSelect: (id) => setState(() => _open = id),
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
            onPressed: () => context.push('/notifications'),
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
            onSelect: (id) => context.push('/chat/$id'),
            onRetry: () => ref.invalidate(conversationsProvider),
          ),
        ),
      ),
    );
  }
}

/// The list of threads, shared by both shapes: a whole screen on a phone, the
/// left pane on a desktop.
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
                padding: const EdgeInsets.fromLTRB(
                  Gap.x4,
                  Gap.x4,
                  Gap.x4,
                  Gap.x14,
                ),
                itemCount: items.length,
                separatorBuilder: (_, _) => Gap.h3,
                itemBuilder: (context, index) => _ThreadCard(
                  thread: items[index],
                  selected: items[index].id == selectedId,
                  onTap: () => onSelect(items[index].id),
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

  /// Marked in the desktop list so it is clear which thread the right-hand
  /// pane is showing.
  final bool selected;

  final VoidCallback onTap;

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
      shape: RoundedRectangleBorder(
        borderRadius: Radii.rLg,
        side: BorderSide(
          color: selected ? p.give : p.hair,
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
                      // Two halves with the product's own arrow between them.
                      // A `↔` in the string rendered as an empty box: neither
                      // Rubik nor Manrope carries that glyph.
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: Gap.x2,
                        children: [
                          Text(
                            thread.gives,
                            style: theme.textTheme.titleSmall,
                          ),
                          Icon(
                            Symbols.swap_horiz_rounded,
                            size: Sizes.iconMd,
                            color: p.inkFaint,
                          ),
                          Text(
                            thread.receives,
                            style: theme.textTheme.titleSmall,
                          ),
                        ],
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
