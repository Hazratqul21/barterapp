import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_theme.dart';
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
          final locale = Localizations.localeOf(context).languageCode;
          
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // HEADER with cover and avatar in M3 surface
                      Container(
                        color: theme.colorScheme.surfaceContainerLow,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 200,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  if (profile.coverUrl != null)
                                    SizedBox(
                                      height: 160,
                                      width: double.infinity,
                                      child: RemoteImage(
                                        url: profile.coverUrl,
                                        semanticLabel: 'Cover',
                                      ),
                                    )
                                  else
                                    Container(
                                      height: 160,
                                      color: p.giveSoft.withValues(alpha: 0.5),
                                    ),
                                  Positioned(
                                    bottom: 0,
                                    left: 20,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: theme.colorScheme.surfaceContainerLow,
                                          width: 4,
                                        ),
                                      ),
                                      child: TraderAvatar(
                                        size: 72,
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
                              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    profile.brief.displayName,
                                    style: theme.textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      if (profile.brief.isVerified) ...[
                                        Icon(Symbols.verified_rounded, size: 16, color: p.give),
                                        const SizedBox(width: 4),
                                        Text(
                                          l.traderVerified,
                                          style: theme.textTheme.labelMedium?.copyWith(
                                            color: p.give,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                      ],
                                      if (profile.brief.isOnline)
                                        Text(
                                          l.traderOnline,
                                          style: theme.textTheme.labelMedium?.copyWith(
                                            color: BrandColors.brand500,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (profile.bio != null) ...[
                                    const SizedBox(height: 16),
                                    Text(
                                      profile.bio!,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: p.inkSoft,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // STATS ROW
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            _StatItem(
                              label: l.traderRating,
                              value: profile.brief.rating?.toStringAsFixed(1) ?? '—',
                              icon: Symbols.star_rounded,
                              iconColor: p.money,
                            ),
                            _StatItem(
                              label: l.traderDeals,
                              value: profile.brief.deals.toString(),
                            ),
                            _StatItem(
                              label: l.traderCompletion,
                              value: profile.completionRate != null 
                                ? '${profile.completionRate}%' 
                                : '—',
                            ),
                            _StatItem(
                              label: l.traderMemberSince,
                              value: DateFormat.yMMMd(locale).format(profile.joinedAt),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // ACTIVE LISTINGS
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        child: Text(
                          l.traderListings,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      _TraderListings(traderId: widget.traderId),
                      
                      const SizedBox(height: 32),
                      
                      // REVIEWS
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        child: Text(
                          l.traderReviews,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      _TraderReviews(traderId: widget.traderId),
                      
                      const SizedBox(height: 40),
                    ],
                  ).animate().fadeIn(duration: M3Motion.medium2, curve: M3Motion.standard),
                ),
              ),
              
              // No "message this trader" button here. A conversation is
              // created with an offer and cannot exist without one, so the
              // stub that used to sit in this spot could never have been
              // wired up. Their listings are right above; making an offer on
              // one is how you reach this person.
            ],
          );
        },
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    this.icon,
    this.iconColor,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: iconColor ?? theme.textTheme.bodyLarge?.color),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    value,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: p.inkSoft,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
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
    final l = L.of(context);

    return listingsAsync.when(
      loading: () => const Center(
        child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()),
      ),
      error: (e, _) => ErrorState(
        message: errorMessage(context, e),
        retryLabel: l.retry,
        onRetry: () => ref.invalidate(traderListingsProvider(traderId)),
      ),
      data: (listings) {
        if (listings.isEmpty) {
          return EmptyState(
            title: l.traderListingsEmpty,
            hint: '',
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.7,
          ),
          itemCount: listings.length,
          itemBuilder: (context, index) {
            final listing = listings[index];
            return AnimatedListItem(
              index: index,
              child: ListingCardTile(
                listing: listing,
                onTap: () => context.push('/listing/${listing.id}'),
              ),
            );
          },
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
    final l = L.of(context);

    return reviewsAsync.when(
      loading: () => const Center(
        child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()),
      ),
      error: (e, _) => ErrorState(
        message: errorMessage(context, e),
        retryLabel: l.retry,
        onRetry: () => ref.invalidate(traderReviewsProvider(traderId)),
      ),
      data: (reviews) {
        if (reviews.isEmpty) {
          return EmptyState(
            title: l.traderReviewsEmpty,
            hint: '',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: reviews.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final review = reviews[index];
            final p = palette(context);
            final theme = Theme.of(context);
            final days = DateTime.now().difference(review.createdAt).inDays;
            final timeAgo = days == 0 ? 'Today' : '$days d';

            return AnimatedListItem(
              index: index,
              child: Card(
                margin: EdgeInsets.zero,
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          TraderAvatar(
                            size: 32,
                            url: review.authorAvatarUrl,
                            name: review.authorName,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  review.authorName,
                                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                Row(
                                  children: [
                                    Icon(Symbols.star_rounded, size: 14, color: p.money),
                                    const SizedBox(width: 4),
                                    Text(
                                      review.rating.toString(),
                                      style: theme.textTheme.labelSmall?.copyWith(color: p.inkSoft),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Text(
                            timeAgo,
                            style: theme.textTheme.labelSmall?.copyWith(color: p.inkFaint),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        review.body,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
