import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/models.dart';
import '../../auth/data/auth_repository.dart';
import '../data/trade_repository.dart';

/// What happened while you were away.
///
/// Grouped into today and earlier, because "an offer arrived" means something
/// different at ten minutes old than at four days old.
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final items = ref.watch(notificationsProvider);

    if (!ref.watch(authStateProvider)) {
      return Scaffold(
        appBar: AppBar(title: Text(l.notificationsTitle)),
        body: SignInPrompt(reason: l.inboxSignIn),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.notificationsTitle),
        actions: [
          // An icon, not the label. "Hammasini o‘qilgan qilish" is 26
          // characters and pushed the title into an ellipsis — the screen was
          // named "Bildirishnoma…" by its own action button.
          items.maybeWhen(
            data: (rows) => rows.any((n) => n.isUnread)
                ? IconButton(
                    tooltip: l.notificationsMarkAll,
                    icon: const Icon(Symbols.done_all_rounded),
                    onPressed: () async {
                      await ref.read(tradeRepositoryProvider).markRead();
                      ref.invalidate(notificationsProvider);
                    },
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
          Gap.w2,
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Sizes.contentMax),
          child: items.fade(
            loading: () => const _NotificationsShimmer(),
            error: (e) => ErrorState(
              message: errorMessage(context, e),
              retryLabel: l.retry,
              onRetry: () => ref.invalidate(notificationsProvider),
            ),
            identity: items.value?.length,
            data: (rows) => rows.isEmpty
                ? EmptyState(
                    icon: Symbols.notifications_rounded,
                    title: l.notificationsEmpty,
                    hint: l.notificationsEmptyHint,
                  )
                : RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(notificationsProvider),
                    child: _Grouped(rows: rows),
                  ),
          ),
        ),
      ),
    );
  }
}

class _Grouped extends StatelessWidget {
  const _Grouped({required this.rows});

  final List<AppNotification> rows;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final now = DateTime.now();

    bool isToday(AppNotification n) {
      final at = n.createdAt.toLocal();
      return at.year == now.year && at.month == now.month && at.day == now.day;
    }

    final today = rows.where(isToday).toList();
    final earlier = rows.where((n) => !isToday(n)).toList();

    final children = <Widget>[
      if (today.isNotEmpty) ...[
        _Heading(l.notifyToday),
        for (final n in today) _Row(notification: n),
      ],
      if (earlier.isNotEmpty) ...[
        _Heading(l.notifyEarlier),
        for (final n in earlier) _Row(notification: n),
      ],
    ];

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: Gap.x14),
      itemCount: children.length,
      // Staggered only near the top; further down it reads as lag, not motion.
      itemBuilder: (context, index) {
        final child = children[index];
        if (index >= 5) return child;
        return child
            .animate()
            .fadeIn(
              delay: Duration(milliseconds: 40 * index),
              duration: M3Motion.medium2,
            )
            .slideY(
              begin: 0.05,
              end: 0,
              delay: Duration(milliseconds: 40 * index),
              duration: M3Motion.medium3,
              curve: M3Motion.emphasizedDecelerate,
            );
      },
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.x5, Gap.x6, Gap.x5, Gap.x2),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: p.inkFaint),
      ),
    );
  }
}

class _Row extends ConsumerWidget {
  const _Row({required this.notification});

  final AppNotification notification;

  /// Where tapping lands. Carried by the row, never guessed from `kind` — the
  /// prototype guessed, and sent two unrelated offers into the same thread.
  void _follow(BuildContext context) {
    final id = notification.targetId;
    switch (notification.targetType) {
      case NotifyTargetType.chat:
        if (id != null) context.push('/chat/$id');
      case NotifyTargetType.matches:
        context.go('/matches');
      case NotifyTargetType.verification:
        context.push('/settings/verify');
      case NotifyTargetType.listing:
        if (id != null) context.push('/listing/$id');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);

    // `kind` decides only how the row looks. Colour follows the product's own
    // vocabulary: an offer is something given, a message something wanted,
    // a match is worth money.
    final (icon, colour, tint) = switch (notification.kind) {
      'offer' => (Symbols.swap_horiz_rounded, p.give, p.giveSoft),
      'match' => (Symbols.auto_awesome_rounded, p.money, p.moneySoft),
      'message' => (Symbols.forum_rounded, p.take, p.takeSoft),
      _ => (Symbols.shield_rounded, p.inkSoft, p.sunken),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.x5,
        vertical: Gap.x1,
      ),
      child: Pressable(
        onTap: () async {
          if (notification.isUnread) {
            await ref
                .read(tradeRepositoryProvider)
                .markRead(ids: [notification.id]);
            ref.invalidate(notificationsProvider);
          }
          if (context.mounted) _follow(context);
        },
        child: Container(
          padding: const EdgeInsets.all(Gap.x3),
          decoration: BoxDecoration(
            // Unread rows sit on a surface; read ones fade into the page.
            color: notification.isUnread
                ? theme.colorScheme.surfaceContainerLowest
                : Colors.transparent,
            borderRadius: Radii.rMd,
            border: Border.all(
              color: notification.isUnread ? p.hair : Colors.transparent,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (notification.avatarUrl != null)
                TraderAvatar(
                  // The title so that a photo which fails to load falls back
                  // to initials rather than a question mark.
                  url: notification.avatarUrl,
                  name: notification.title,
                  size: Sizes.avatarMd,
                )
              else
                Container(
                  width: Sizes.avatarMd,
                  height: Sizes.avatarMd,
                  decoration: BoxDecoration(
                    color: tint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: colour, size: Sizes.iconMd),
                ),
              Gap.w3,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: notification.isUnread
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                    Gap.h1,
                    Text(
                      notification.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: p.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              Gap.w2,
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _ago(l, notification.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: p.inkFaint,
                    ),
                  ),
                  if (notification.isUnread) ...[
                    Gap.h2,
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colour,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The old row wrote "3d", "5h", "now" — English abbreviations on a Russian
  /// screen.
  String _ago(L l, DateTime at) {
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

class _NotificationsShimmer extends StatelessWidget {
  const _NotificationsShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(Gap.x5, Gap.x6, Gap.x5, Gap.x14),
      itemCount: 5,
      separatorBuilder: (_, _) => Gap.h3,
      itemBuilder: (context, index) => Row(
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
    );
  }
}
