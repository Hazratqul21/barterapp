import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/models.dart';
import '../../auth/data/auth_repository.dart';
import '../../feed/presentation/listing_card_tile.dart';
import '../../trade/data/trade_repository.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);
    final isAuthed = ref.watch(authStateProvider);

    if (!isAuthed) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l.profileTitle),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.authSignedOut, style: theme.textTheme.titleMedium),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.push('/signin'),
                child: Text(l.authSignIn),
              ),
            ],
          ).animate().fadeIn(duration: M3Motion.medium2, curve: M3Motion.standard),
        ),
      );
    }

    final meAsync = ref.watch(meProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.profileTitle),
      ),
      body: meAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: e.toString(),
          retryLabel: l.retry,
          onRetry: () => ref.invalidate(meProvider),
        ),
        data: (me) {
          if (me == null) {
            return EmptyState(
              title: 'Not Found',
              hint: 'Could not load profile.',
              actionLabel: l.retry,
              onAction: () => ref.invalidate(meProvider),
            );
          }

          final isVerified = me.trustScore >= 60;

          return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 700), child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                // HEADER
                Center(
                  child: TraderAvatar(
                    size: 72,
                    url: me.avatarUrl,
                    name: me.name,
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    me.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (me.handle != null)
                  Center(
                    child: Text(
                      '@${me.handle}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: p.inkSoft,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isVerified) ...[
                      Icon(Symbols.verified_rounded, size: 16, color: p.give),
                      const SizedBox(width: 4),
                      Text(
                        l.traderVerified,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: p.give,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    if (me.rating != null) ...[
                      Icon(Symbols.star_rounded, size: 18, color: p.money),
                      const SizedBox(width: 4),
                      Text(
                        me.rating!.toStringAsFixed(1),
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),

                // TRUST SCORE
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Card(
                    margin: EdgeInsets.zero,
                    color: p.giveSoft.withValues(alpha: 0.3),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                l.profileTrustLabel,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${me.trustScore}/100',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: me.trustScore / 100,
                            backgroundColor: p.inkFaint.withValues(alpha: 0.2),
                            color: p.give,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // STATS ROW
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _StatCard(label: l.profileStatActive, value: '${me.activeListings}'),
                      const SizedBox(width: 8),
                      _StatCard(label: l.profileStatCompleted, value: '${me.completedTrades}'),
                      const SizedBox(width: 8),
                      _StatCard(
                        label: l.profileStatCompletion,
                        value: me.completionRate != null ? '${me.completionRate}%' : '—',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // CONTENT TABS
                TabBar(
                  controller: _tabController,
                  labelColor: theme.textTheme.bodyLarge?.color,
                  unselectedLabelColor: p.inkSoft,
                  indicatorColor: p.give,
                  labelStyle: theme.textTheme.titleSmall,
                  unselectedLabelStyle: theme.textTheme.titleSmall,
                  tabs: [
                    Tab(text: l.profileMyListings),
                    Tab(text: l.profileReviews),
                  ],
                ),
                const SizedBox(height: 16),
                if (_tabController.index == 0)
                  _MyListingsSection(me: me)
                else
                  _MyReviewsSection(meId: me.id),
                
                const SizedBox(height: 40),
              ],
            ).animate().fadeIn(duration: M3Motion.medium2, curve: M3Motion.standard),
          )));
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(color: p.inkSoft, height: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyListingsSection extends ConsumerWidget {
  const _MyListingsSection({required this.me});
  final Me me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingsAsync = ref.watch(myListingsProvider);
    final l = L.of(context);

    return listingsAsync.when(
      loading: () => const Center(
        child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()),
      ),
      error: (e, _) => ErrorState(
        message: e.toString(),
        retryLabel: l.retry,
        onRetry: () => ref.invalidate(myListingsProvider),
      ),
      data: (listings) {
        if (listings.isEmpty) {
          return EmptyState(
            title: l.profileMyListings,
            hint: 'No listings yet', // fallback
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

class _MyReviewsSection extends ConsumerWidget {
  const _MyReviewsSection({required this.meId});
  final String meId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(traderReviewsProvider(meId));
    final l = L.of(context);

    return reviewsAsync.when(
      loading: () => const Center(
        child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()),
      ),
      error: (e, _) => ErrorState(
        message: e.toString(),
        retryLabel: l.retry,
        onRetry: () => ref.invalidate(traderReviewsProvider(meId)),
      ),
      data: (reviews) {
        if (reviews.isEmpty) {
          return EmptyState(
            title: l.profileReviews,
            hint: l.profileNoReviews,
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
            return AnimatedListItem(
              index: index,
              child: _ReviewCard(review: review),
            );
          },
        );
      },
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});
  final Review review;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final theme = Theme.of(context);
    // Simple time ago approximation
    final days = DateTime.now().difference(review.createdAt).inDays;
    final timeAgo = days == 0 ? 'Today' : '$days d';

    return Card(
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
    );
  }
}
