import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';

import '../../feed/presentation/listing_card_tile.dart';
import '../data/trade_repository.dart';

class TraderProfilePage extends ConsumerStatefulWidget {
  const TraderProfilePage({super.key, required this.traderId});
  final String traderId;

  @override
  ConsumerState<TraderProfilePage> createState() => _TraderProfilePageState();
}

class _TraderProfilePageState extends ConsumerState<TraderProfilePage> {
  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);
    final profileAsync = ref.watch(traderProvider(widget.traderId));

    return Scaffold(
      appBar: AppBar(
        title: profileAsync.maybeWhen(
          data: (profile) => Text(profile.brief.displayName),
          orElse: () => const Text(''),
        ),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: errorMessage(context, e),
          retryLabel: l.retry,
          onRetry: () => ref.invalidate(traderProvider(widget.traderId)),
        ),
        data: (profile) {
          final isVerified = profile.brief.isVerified;

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Premium Header
                Container(
                  color: theme.colorScheme.surfaceContainerLow,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 180,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            if (profile.coverUrl != null)
                              SizedBox(
                                height: 140,
                                width: double.infinity,
                                child: RemoteImage(url: profile.coverUrl, semanticLabel: 'Cover'),
                              )
                            else
                              Container(height: 140, color: p.giveSoft),
                            Positioned(
                              bottom: 0,
                              left: Gap.x5,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: theme.colorScheme.surfaceContainerLow, width: 4),
                                ),
                                child: TraderAvatar(
                                  size: Sizes.avatarLg,
                                  url: profile.brief.avatarUrl,
                                  name: profile.brief.name,
                                  isOnline: profile.brief.isOnline,
                                  showPresence: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(Gap.x5, Gap.x3, Gap.x5, Gap.x6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.brief.displayName,
                              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Gap.h2,
                            Row(
                              children: [
                                if (isVerified) ...[
                                  Icon(Symbols.verified_rounded, size: Sizes.iconSm, color: p.give, fill: 1),
                                  Gap.w1,
                                  Text(l.traderVerified, style: theme.textTheme.labelMedium?.copyWith(color: p.give)),
                                  Gap.w3,
                                ],
                                if (profile.brief.isOnline)
                                  Text(l.traderOnline, style: theme.textTheme.labelMedium?.copyWith(color: p.give, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            if (profile.bio != null) ...[
                              Gap.h4,
                              Text(profile.bio!, style: theme.textTheme.bodyMedium?.copyWith(color: p.inkSoft, height: 1.4)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Gap.h4,

                // Stats
                Padding(
                  padding: Gap.screen,
                  child: Row(
                    children: [
                      _StatCard(label: l.traderRating, value: profile.brief.rating?.toStringAsFixed(1) ?? '—', icon: Symbols.star_rounded, iconColor: p.money),
                      Gap.w2,
                      _StatCard(label: l.traderDeals, value: profile.brief.deals.toString()),
                      Gap.w2,
                      _StatCard(label: l.traderCompletion, value: profile.completionRate != null ? '${profile.completionRate}%' : '—'),
                    ],
                  ),
                ),
                Gap.h8,

                // Listings Section
                Padding(
                  padding: const EdgeInsets.fromLTRB(Gap.x5, 0, Gap.x5, Gap.x4),
                  child: Text(l.traderListings, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                ),
                _TraderListings(traderId: widget.traderId),

                Gap.h8,
                // Reviews Section
                Padding(
                  padding: const EdgeInsets.fromLTRB(Gap.x5, 0, Gap.x5, Gap.x4),
                  child: Text(l.traderReviews, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                ),
                _TraderReviews(traderId: widget.traderId),

                const SizedBox(height: 60),
              ],
            ).animate().fadeIn(duration: M3Motion.medium2),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, this.icon, this.iconColor});
  final String label;
  final String value;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Gap.x4, horizontal: Gap.x2),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: Radii.rLg,
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[Icon(icon, size: 14, color: iconColor, fill: 1), Gap.w1],
                Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
            Gap.h1,
            Text(label, textAlign: TextAlign.center, style: theme.textTheme.labelSmall?.copyWith(color: palette(context).inkSoft, fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

class _TraderListings extends ConsumerWidget {
  const _TraderListings({required this.traderId});
  final String traderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingsAsync = ref.watch(traderListingsProvider(traderId));
    return listingsAsync.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
      error: (e, _) => ErrorState(message: errorMessage(context, e), retryLabel: L.of(context).retry, onRetry: () => ref.invalidate(traderListingsProvider(traderId))),
      data: (listings) {
        if (listings.isEmpty) return EmptyState(title: L.of(context).traderListingsEmpty, hint: '');
        return GridView.builder(
          padding: Gap.screen,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: Gap.x4, crossAxisSpacing: Gap.x4, childAspectRatio: 0.75),
          itemCount: listings.length,
          itemBuilder: (context, index) => AnimatedListItem(index: index, child: ListingCardTile(listing: listings[index], onTap: () => context.push('/listing/${listings[index].id}'))),
        );
      },
    );
  }
}

class _TraderReviews extends ConsumerWidget {
  const _TraderReviews({required this.traderId});
  final String traderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(traderReviewsProvider(traderId));
    return reviewsAsync.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
      error: (e, _) => ErrorState(message: errorMessage(context, e), retryLabel: L.of(context).retry, onRetry: () => ref.invalidate(traderReviewsProvider(traderId))),
      data: (reviews) {
        if (reviews.isEmpty) return EmptyState(title: L.of(context).traderReviewsEmpty, hint: '');
        return ListView.separated(
          padding: Gap.screen,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: reviews.length,
          separatorBuilder: (_, _) => Gap.h3,
          itemBuilder: (context, index) => AnimatedListItem(
            index: index,
            child: Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(borderRadius: Radii.rLg, side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5))),
              child: Padding(
                padding: const EdgeInsets.all(Gap.x4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        TraderAvatar(size: Sizes.avatarSm, url: reviews[index].authorAvatarUrl, name: reviews[index].authorName),
                        Gap.w3,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(reviews[index].authorName, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                              Row(children: [const Icon(Symbols.star_rounded, size: 14, color: Color(0xFFF0A82A), fill: 1), Gap.w1, Text(reviews[index].rating.toString(), style: Theme.of(context).textTheme.labelSmall)]),
                            ],
                          ),
                        ),
                        Text(timeAgo(context, reviews[index].createdAt), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: palette(context).inkFaint)),
                      ],
                    ),
                    Gap.h3,
                    Text(reviews[index].body, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
