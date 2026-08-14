import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/router/web_shell.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
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

class _ProfilePageState extends ConsumerState<ProfilePage> with SingleTickerProviderStateMixin {
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

    final showSettings = MediaQuery.sizeOf(context).width < kWebBreakpoint;

    if (!isAuthed) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l.profileTitle),
          actions: [if (showSettings) _SettingsAction(label: l.navSettings)],
        ),
        body: Center(
          child: Padding(
            padding: Gap.screen,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StateArt(icon: Symbols.person_rounded),
                Gap.h5,
                Text(l.authSignedOut, style: theme.textTheme.titleLarge),
                Gap.h6,
                FilledButton(
                  onPressed: () => context.push('/signin'),
                  child: Text(l.authSignIn),
                ),
              ],
            ).animate().fadeIn(duration: M3Motion.medium2, curve: M3Motion.standard),
          ),
        ),
      );
    }

    final meAsync = ref.watch(meProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.profileTitle),
        actions: [if (showSettings) _SettingsAction(label: l.navSettings)],
      ),
      body: meAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: errorMessage(context, e),
          retryLabel: l.retry,
          onRetry: () => ref.invalidate(meProvider),
        ),
        data: (me) {
          if (me == null) {
            return EmptyState(title: l.notFound, hint: '', actionLabel: l.retry, onAction: () => ref.invalidate(meProvider));
          }

          final isVerified = me.trustScore >= 60;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Sizes.contentMax),
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverList(
                    delegate: SliverChildListDelegate([
                      Gap.h6,
                      Center(child: TraderAvatar(size: Sizes.avatarLg, url: me.avatarUrl, name: me.name)),
                      Gap.h3,
                      Center(child: Text(me.name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800))),
                      if (me.handle != null)
                        Center(child: Text('@${me.handle}', style: theme.textTheme.bodyMedium?.copyWith(color: p.inkSoft))),
                      Gap.h2,
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isVerified) ...[
                            Icon(Symbols.verified_rounded, size: Sizes.iconSm, color: p.give, fill: 1),
                            Gap.w1,
                            Text(l.traderVerified, style: theme.textTheme.labelMedium?.copyWith(color: p.give)),
                            Gap.w4,
                          ],
                          if (me.rating != null) ...[
                            Icon(Symbols.star_rounded, size: 18, color: p.money, fill: 1),
                            Gap.w1,
                            Text(me.rating!.toStringAsFixed(1), style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                          ],
                        ],
                      ),
                      Gap.h6,
                    ]),
                  ),

                  // TRUST SCORE
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _TrustScoreHeaderDelegate(me: me),
                  ),

                  SliverList(
                    delegate: SliverChildListDelegate([
                      Gap.h4,
                      // STATS ROW
                      Padding(
                        padding: Gap.screen,
                        child: Row(
                          children: [
                            _StatCard(label: l.profileStatActive, value: '${me.activeListings}'),
                            Gap.w2,
                            _StatCard(label: l.profileStatCompleted, value: '${me.completedTrades}'),
                            Gap.w2,
                            _StatCard(label: l.profileStatCompletion, value: me.completionRate != null ? '${me.completionRate}%' : '—'),
                          ],
                        ),
                      ),
                      Gap.h6,

                      // CONTENT TABS
                      TabBar(
                        controller: _tabController,
                        indicatorColor: p.give,
                        labelColor: theme.colorScheme.onSurface,
                        unselectedLabelColor: p.inkSoft,
                        labelStyle: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        tabs: [Tab(text: l.profileMyListings), Tab(text: l.profileReviews)],
                      ),
                      Gap.h4,
                    ]),
                  ),
                  if (_tabController.index == 0) _MyListingsSection(me: me) else _MyReviewsSection(meId: me.id),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)), // Space for FAB
                ],
              ),
            ).animate().fadeIn(duration: M3Motion.medium2, curve: M3Motion.standard),
          );
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
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Gap.x4, horizontal: Gap.x2),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: Radii.rLg,
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            Gap.h1,
            Text(label, textAlign: TextAlign.center, style: theme.textTheme.labelSmall?.copyWith(color: p.inkSoft, fontSize: 9)),
          ],
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
      loading: () => const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(Gap.x8), child: CircularProgressIndicator()))),
      error: (e, _) => SliverToBoxAdapter(child: ErrorState(message: errorMessage(context, e), retryLabel: l.retry, onRetry: () => ref.invalidate(myListingsProvider))),
      data: (listings) {
        if (listings.isEmpty) return SliverToBoxAdapter(child: EmptyState(title: l.profileMyListings, hint: 'Hozircha e’lonlar yo‘q'));
        return SliverPadding(
          padding: Gap.screen,
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: Gap.x4, crossAxisSpacing: Gap.x4, childAspectRatio: 0.75),
            delegate: SliverChildBuilderDelegate(
              (context, index) => AnimatedListItem(
                index: index,
                child: ListingCardTile(listing: listings[index], onTap: () => context.push('/listing/${listings[index].id}')),
              ),
              childCount: listings.length,
            ),
          ),
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
      loading: () => const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(Gap.x8), child: CircularProgressIndicator()))),
      error: (e, _) => SliverToBoxAdapter(child: ErrorState(message: errorMessage(context, e), retryLabel: l.retry, onRetry: () => ref.invalidate(traderReviewsProvider(meId)))),
      data: (reviews) {
        if (reviews.isEmpty) return SliverToBoxAdapter(child: EmptyState(title: l.profileReviews, hint: l.profileNoReviews));
        return SliverPadding(
          padding: Gap.screen,
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index.isOdd) return Gap.h3;
                final itemIndex = index ~/ 2;
                return AnimatedListItem(index: itemIndex, child: _ReviewCard(review: reviews[itemIndex]));
              },
              childCount: reviews.isNotEmpty ? reviews.length * 2 - 1 : 0,
            ),
          ),
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
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: Radii.rLg, side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
      child: Padding(
        padding: const EdgeInsets.all(Gap.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TraderAvatar(size: Sizes.avatarSm, url: review.authorAvatarUrl, name: review.authorName),
                Gap.w3,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(review.authorName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      Row(
                        children: [
                          Icon(Symbols.star_rounded, size: 14, color: p.money, fill: 1),
                          Gap.w1,
                          Text(review.rating.toString(), style: theme.textTheme.labelSmall),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(timeAgo(context, review.createdAt), style: theme.textTheme.labelSmall?.copyWith(color: p.inkFaint)),
              ],
            ),
            Gap.h3,
            Text(review.body, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _SettingsAction extends StatelessWidget {
  const _SettingsAction({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: Gap.x2),
      child: IconButton(tooltip: label, onPressed: () => context.push('/settings'), icon: const Icon(Symbols.settings_rounded, size: Sizes.iconLg)),
    );
  }
}

class _TrustScoreHeaderDelegate extends SliverPersistentHeaderDelegate {
  _TrustScoreHeaderDelegate({required this.me});

  final Me me;

  @override
  double get minExtent => 104.0;
  @override
  double get maxExtent => 104.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surface,
      alignment: Alignment.center,
      child: Padding(
        padding: Gap.screen,
        child: Container(
          padding: const EdgeInsets.all(Gap.x4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: Radii.rLg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l.profileTrustLabel, style: theme.textTheme.titleSmall),
                  Text('${me.trustScore}/100', style: theme.textTheme.titleSmall?.copyWith(color: p.give, fontWeight: FontWeight.w800)),
                ],
              ),
              Gap.h2,
              LinearProgressIndicator(
                value: me.trustScore / 100,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: p.give,
                borderRadius: Radii.rFull,
                minHeight: 6,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TrustScoreHeaderDelegate oldDelegate) {
    return oldDelegate.me != me;
  }
}
