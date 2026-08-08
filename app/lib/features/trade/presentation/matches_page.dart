import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/models.dart';
import '../data/trade_repository.dart';

/// What the matcher found: your listing on one side, a stranger's on the other,
/// and how well they fit.
///
/// The card used to be an `IntrinsicHeight` row holding two full-width network
/// images. Intrinsic sizing has to measure a child before laying it out, and a
/// box declared `width: double.infinity` has no intrinsic width to give — so
/// the whole screen threw during layout and rendered nothing at all. The API
/// was returning matches the entire time.
///
/// It is a column now. Nothing here asks for an intrinsic measurement.
class MatchesPage extends ConsumerWidget {
  const MatchesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);
    final matches = ref.watch(matchesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.matchesTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Sizes.contentMax),
          child: matches.when(
            loading: () => const _MatchesShimmer(),
            error: (e, _) => ErrorState(
              message: errorMessage(context, e),
              retryLabel: l.retry,
              onRetry: () => ref.invalidate(matchesProvider),
            ),
            data: (items) => items.isEmpty
                ? EmptyState(
                    title: l.matchesEmpty,
                    hint: l.matchesEmptyHint,
                    actionLabel: l.matchesCreate,
                    onAction: () => context.push('/create'),
                  )
                : RefreshIndicator(
                    onRefresh: () async => ref.invalidate(matchesProvider),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        Gap.x5,
                        Gap.x4,
                        Gap.x5,
                        Gap.x14,
                      ),
                      itemCount: items.length + 1,
                      separatorBuilder: (_, _) => Gap.h4,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: Gap.x1),
                            child: Text(
                              l.matchesLede,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: p.inkSoft,
                              ),
                            ),
                          );
                        }
                        return _MatchCard(match: items[index - 1]);
                      },
                    ),
                  ),
          ),
        ),
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
      child: Padding(
        padding: const EdgeInsets.all(Gap.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The score leads. It is the reason this card exists, and the one
            // number that decides whether the rest is worth reading.
            Row(
              children: [
                _Score(score: match.score),
                Gap.w3,
                Expanded(
                  child: Text(
                    match.reason,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: p.inkSoft,
                    ),
                  ),
                ),
              ],
            ),
            Gap.h4,

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Side(
                    listing: match.mine,
                    caption: l.matchesYours,
                    color: p.give,
                    tint: p.giveSoft,
                    locale: locale,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.x2),
                  child: Padding(
                    // Sits level with the thumbnails rather than the captions.
                    padding: const EdgeInsets.only(top: 40),
                    child: Icon(
                      Symbols.swap_horiz_rounded,
                      size: Sizes.iconLg,
                      color: p.inkFaint,
                    ),
                  ),
                ),
                Expanded(
                  child: _Side(
                    listing: match.theirs,
                    caption: l.matchesTheirs,
                    color: p.take,
                    tint: p.takeSoft,
                    locale: locale,
                  ),
                ),
              ],
            ),

            Gap.h4,
            Divider(color: p.hair, height: 1),
            Gap.h3,

            // The owner is always the owner of `theirs` — the server decides
            // that, so no screen has to work it out.
            InkWell(
              onTap: () => context.push('/trader/${match.owner.id}'),
              borderRadius: Radii.rSm,
              child: Row(
                children: [
                  TraderAvatar(
                    url: match.owner.avatarUrl,
                    name: match.owner.name,
                    size: Sizes.avatarSm,
                  ),
                  Gap.w2,
                  Expanded(
                    child: Text(
                      match.owner.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  if (match.owner.rating != null) ...[
                    Icon(
                      Symbols.star_rounded,
                      size: Sizes.iconSm,
                      color: p.money,
                      fill: 1,
                    ),
                    Gap.w1,
                    Text(
                      match.owner.rating!.toStringAsFixed(1),
                      style: theme.textTheme.labelLarge,
                    ),
                  ],
                ],
              ),
            ),

            Gap.h4,
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      await ref
                          .read(tradeRepositoryProvider)
                          .dismissMatch(match.id);
                      ref.invalidate(matchesProvider);
                    },
                    child: Text(l.matchesSkip),
                  ),
                ),
                Gap.w3,
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      context.push('/offer/${match.theirs.id}');
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, Sizes.buttonMd),
                    ),
                    child: Text(l.matchesOffer),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One half of the pairing: a thumbnail, what it is, what it is worth.
class _Side extends StatelessWidget {
  const _Side({
    required this.listing,
    required this.caption,
    required this.color,
    required this.tint,
    required this.locale,
  });

  final ListingCard listing;
  final String caption;
  final Color color;
  final Color tint;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          caption.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: color),
        ),
        Gap.h2,
        ClipRRect(
          borderRadius: Radii.rSm,
          child: Container(
            height: 84,
            color: tint,
            // A fixed height and whatever width the column gives it. No
            // `double.infinity`, which is what broke the previous card.
            child: RemoteImage(
              url: listing.imageUrl,
              semanticLabel: listing.imageAlt,
            ),
          ),
        ),
        Gap.h2,
        Text(
          listing.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(height: 1.3),
        ),
        Gap.h1,
        Text(
          listing.value.format(locale),
          style: theme.textTheme.bodySmall?.copyWith(color: p.inkSoft),
        ),
      ],
    );
  }
}

/// The fit, as a number.
class _Score extends StatelessWidget {
  const _Score({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);

    // A strong fit earns the money colour; a weaker one stays quiet rather than
    // claiming more than it is.
    final strong = score >= 75;
    final colour = strong ? p.money : p.inkSoft;
    final tint = strong ? p.moneySoft : p.sunken;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.x3,
        vertical: Gap.x2,
      ),
      decoration: BoxDecoration(color: tint, borderRadius: Radii.rSm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$score%',
            style: theme.textTheme.titleLarge?.copyWith(color: colour),
          ),
          Text(
            l.matchesScore,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colour,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// The card's own shape while the matcher runs — it computes on read, so this
/// is a real wait rather than a token one.
class _MatchesShimmer extends StatelessWidget {
  const _MatchesShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(Gap.x5, Gap.x5, Gap.x5, Gap.x14),
      itemCount: 3,
      separatorBuilder: (_, _) => Gap.h4,
      itemBuilder: (context, index) => Card(
        child: Padding(
          padding: const EdgeInsets.all(Gap.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonBox(width: 72, height: 44, radius: Radii.rSm),
              Gap.h4,
              const Row(
                children: [
                  Expanded(
                    child: SkeletonBox(height: 84, radius: Radii.rSm),
                  ),
                  Gap.w4,
                  Expanded(
                    child: SkeletonBox(height: 84, radius: Radii.rSm),
                  ),
                ],
              ),
              Gap.h3,
              const SkeletonBox(width: 160, height: 14),
            ],
          ),
        ),
      ),
    );
  }
}
