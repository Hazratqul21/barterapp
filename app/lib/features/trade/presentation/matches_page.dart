import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/router/web_shell.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/models.dart';
import '../../auth/data/auth_repository.dart';
import '../data/trade_repository.dart';

class MatchesPage extends ConsumerWidget {
  const MatchesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);
    final matches = ref.watch(matchesProvider);
    // iOS Safe Area uchun dinamik padding
    final bottomPadding = MediaQuery.paddingOf(context).bottom + Gap.x14;

    if (!ref.watch(authStateProvider)) {
      return Scaffold(
        appBar: AppBar(title: Text(l.matchesTitle)),
        body: SignInPrompt(reason: l.matchesSignIn),
      );
    }

    final wide = MediaQuery.sizeOf(context).width >= kWebBreakpoint;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.matchesTitle),
        actions: [
          IconButton(
            icon: const Icon(Symbols.info_rounded),
            onPressed: () {
              HapticFeedback.lightImpact();
              _showExplain(context, l);
            },
          ),
          Gap.w2,
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: wide ? 1320 : Sizes.contentMax),
          child: matches.fade(
            identity: matches.value?.length,
            loading: () => const _MatchesShimmer(),
            error: (e) => ErrorState(message: errorMessage(context, e), retryLabel: l.retry, onRetry: () => ref.invalidate(matchesProvider)),
            data: (items) => items.isEmpty
                ? EmptyState(icon: Symbols.auto_awesome_rounded, title: l.matchesEmpty, hint: l.matchesEmptyHint, actionLabel: l.matchesCreate, onAction: () => context.push('/create'))
                : RefreshIndicator(
                    onRefresh: () async {
                      HapticFeedback.mediumImpact();
                      return ref.invalidate(matchesProvider);
                    },
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = (constraints.maxWidth / 420).floor().clamp(1, 3);
                        return SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(Gap.x5, Gap.x4, Gap.x5, bottomPadding),
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.matchesLede, style: theme.textTheme.bodyMedium?.copyWith(color: p.inkSoft)),
                              Gap.h4,
                              if (columns == 1)
                                for (final (index, match) in items.indexed) ...[
                                  _MatchCard(match: match).animate().fadeIn(delay: (100 * index).ms).slideY(begin: 0.1, end: 0, curve: M3Motion.emphasizedDecelerate),
                                  Gap.h4,
                                ]
                              else
                                Wrap(
                                  spacing: Gap.x4,
                                  runSpacing: Gap.x4,
                                  children: [
                                    for (final (index, match) in items.indexed)
                                      SizedBox(
                                        width: (constraints.maxWidth - Gap.x5 * 2 - Gap.x4 * (columns - 1)) / columns,
                                        child: _MatchCard(match: match).animate().fadeIn(delay: (100 * index).ms).scale(begin: const Offset(0.95, 0.95), curve: M3Motion.emphasizedDecelerate),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  void _showExplain(BuildContext context, L l) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Symbols.auto_awesome_rounded),
        title: Text(l.matchesTitle),
        content: Text(l.matchesLede),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }
}

class _MatchCard extends ConsumerWidget {
  const _MatchCard({required this.match});
  final TradeMatch match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);
    final locale = l.localeName;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: Radii.rLg, side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
      child: Padding(
        padding: const EdgeInsets.all(Gap.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [_Score(score: match.score), Gap.w3, Expanded(child: Text(match.reason, style: theme.textTheme.bodyMedium?.copyWith(color: p.inkSoft, height: 1.3)))]),
            Gap.h4,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _Side(listing: match.mine, caption: l.matchesYours, color: p.give, tint: p.giveSoft, locale: locale)),
                Padding(padding: const EdgeInsets.symmetric(horizontal: Gap.x2), child: Padding(padding: const EdgeInsets.only(top: 48), child: Container(padding: const EdgeInsets.all(Gap.x1), decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, shape: BoxShape.circle), child: Icon(Symbols.swap_horiz_rounded, size: Sizes.iconMd, color: p.inkFaint)))),
                Expanded(child: _Side(listing: match.theirs, caption: l.matchesTheirs, color: p.take, tint: p.takeSoft, locale: locale)),
              ],
            ),
            Gap.h4,
            Divider(color: p.hair.withValues(alpha: 0.5)),
            Gap.h3,
            InkWell(
              onTap: () { HapticFeedback.lightImpact(); context.push('/trader/${match.owner.id}'); },
              borderRadius: Radii.rSm,
              child: Row(
                children: [
                  TraderAvatar(url: match.owner.avatarUrl, name: match.owner.name, size: Sizes.avatarSm),
                  Gap.w2,
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(match.owner.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall), if (match.owner.rating != null) Row(children: [Icon(Symbols.star_rounded, size: 14, color: p.money, fill: 1), Gap.w1, Text(match.owner.rating!.toStringAsFixed(1), style: theme.textTheme.labelSmall?.copyWith(color: p.inkSoft))])])),
                  Icon(Symbols.chevron_right_rounded, size: Sizes.iconMd, color: p.inkFaint),
                ],
              ),
            ),
            Gap.h4,
            Row(
              children: [
                Expanded(flex: 2, child: OutlinedButton(onPressed: () async { HapticFeedback.lightImpact(); await ref.read(tradeRepositoryProvider).dismissMatch(match.id); ref.invalidate(matchesProvider); }, child: Text(l.matchesSkip))),
                Gap.w3,
                Expanded(flex: 3, child: FilledButton.icon(onPressed: () { HapticFeedback.mediumImpact(); context.push('/offer/${match.theirs.id}'); }, icon: const Icon(Symbols.bolt_rounded, size: 18), label: Text(l.matchesOffer))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({required this.listing, required this.caption, required this.color, required this.tint, required this.locale});
  final ListingCard listing; final String caption; final Color color; final Color tint; final String locale;
  @override
  Widget build(BuildContext context) {
    final p = palette(context); final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(caption.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(color: color, letterSpacing: 1.1)),
        Gap.h2,
        ClipRRect(borderRadius: Radii.rSm, child: Container(height: 90, width: double.infinity, color: tint, child: RemoteImage(url: listing.imageUrl, semanticLabel: listing.imageAlt))),
        Gap.h2,
        Text(listing.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(height: 1.2)),
        Gap.h1,
        Text(listing.value.format(locale), style: theme.textTheme.labelMedium?.copyWith(color: p.inkSoft)),
      ],
    );
  }
}

class _Score extends StatelessWidget {
  const _Score({required this.score});
  final int score;
  @override
  Widget build(BuildContext context) {
    final p = palette(context); final theme = Theme.of(context);
    final strong = score >= 75;
    final colour = strong ? p.give : p.inkSoft;
    final tint = strong ? p.giveSoft : theme.colorScheme.surfaceContainerHighest;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.x3, vertical: Gap.x2),
      decoration: BoxDecoration(color: tint, borderRadius: Radii.rMd, border: strong ? Border.all(color: p.give.withValues(alpha: 0.2)) : null),
      child: Column(mainAxisSize: MainAxisSize.min, children: [Text('$score%', style: theme.textTheme.titleLarge?.copyWith(color: colour, fontWeight: FontWeight.w800)), Text('MATCH', style: theme.textTheme.labelSmall?.copyWith(color: colour, fontSize: 9, letterSpacing: 0.5))]),
    );
  }
}

class _MatchesShimmer extends StatelessWidget {
  const _MatchesShimmer();
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(Gap.x5, Gap.x5, Gap.x5, Gap.x14),
      itemCount: 3,
      separatorBuilder: (_, _) => Gap.h4,
      itemBuilder: (context, index) => Card(child: Padding(padding: const EdgeInsets.all(Gap.x4), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const SkeletonBox(width: 72, height: 44, radius: Radii.rSm), Gap.h4, const Row(children: [Expanded(child: SkeletonBox(height: 84, radius: Radii.rSm)), Gap.w4, Expanded(child: SkeletonBox(height: 84, radius: Radii.rSm))]), Gap.h3, const SkeletonBox(width: 160, height: 14)]))),
    );
  }
}
