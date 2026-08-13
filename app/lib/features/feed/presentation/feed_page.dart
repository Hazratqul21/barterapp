import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/backgrounds.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/glass.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/models.dart';
import '../../auth/data/auth_repository.dart';
import '../data/listing_repository.dart';
import 'feed_banner.dart';
import 'feed_shimmer.dart';
import 'listing_card_tile.dart';

class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  /// Card indices whose entrance has already played. A card animates the first
  /// time its index is built and never again — not on recycle, not on rebuild —
  /// so the list settles instead of flickering. Cleared when the results change
  /// underneath it (a new search, a pull-to-refresh) so the fresh set reveals.
  final Set<int> _revealed = <int>{};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 600) {
      ref.read(feedProvider.notifier).loadMore();
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(feedQueryProvider.notifier).search(value);
    });
    setState(() {});
  }

  void _clearSearch() {
    HapticFeedback.lightImpact();
    _searchController.clear();
    ref.read(feedQueryProvider.notifier).search('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final query = ref.watch(feedQueryProvider);
    final feed = ref.watch(feedProvider);
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 80.0;

    // A different query is a different list; let its cards reveal afresh rather
    // than snapping in because their old indices were already marked seen.
    ref.listen(feedQueryProvider, (_, _) => _revealed.clear());

    return Scaffold(
      body: RefreshIndicator(
        displacement: 120,
        onRefresh: () async {
          HapticFeedback.mediumImpact();
          _revealed.clear();
          return ref.invalidate(feedProvider);
        },
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Sizes.contentMax),
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _Hero(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    onClear: _searchController.text.isEmpty
                        ? null
                        : _clearSearch,
                  ),
                ),
                // The header is the anchor and stays put; everything below it
                // settles in on first load — banner, then the category panel,
                // then the feed cards continue the same cascade downward.
                const SliverToBoxAdapter(
                  child: AnimatedListItem(index: 0, child: FeedBanner()),
                ),
                SliverToBoxAdapter(
                  child: AnimatedListItem(
                    index: 1,
                    child: _Categories(
                      selected: query.tag,
                      onSelect: (tag) {
                        HapticFeedback.selectionClick();
                        ref.read(feedQueryProvider.notifier).toggleTag(tag);
                      },
                    ),
                  ),
                ),
                ...switch (feed) {
                  AsyncLoading() => [
                    const SliverToBoxAdapter(child: FeedShimmer()),
                  ],
                  AsyncError(:final error) => [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: ErrorState(
                        message: errorMessage(context, error),
                        retryLabel: l.retry,
                        onRetry: () => ref.invalidate(feedProvider),
                      ),
                    ),
                  ],
                  AsyncData(:final value) when value.items.isEmpty => [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: Symbols.search_off_rounded,
                        title: l.feedEmpty,
                        hint: l.feedEmptyHint,
                        actionLabel: query.isNarrowed ? l.clear : null,
                        onAction: query.isNarrowed
                            ? () {
                                _clearSearch();
                                ref.read(feedQueryProvider.notifier).reset();
                              }
                            : null,
                      ),
                    ),
                  ],
                  AsyncData(:final value) => _results(
                    l,
                    query,
                    value,
                    bottomPadding,
                  ),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _results(
    L l,
    FeedQuery query,
    FeedState feed,
    double bottomPadding,
  ) {
    final theme = Theme.of(context);
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(Gap.x5, Gap.x5, Gap.x5, Gap.x3),
        sliver: SliverToBoxAdapter(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  l.feedHeading,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                query.isNarrowed
                    ? l.feedResults(feed.items.length)
                    : l.feedNearby(feed.items.length),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette(context).inkFaint,
                ),
              ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.x5),
        sliver: SliverList.separated(
          itemCount: feed.items.length,
          separatorBuilder: (_, _) => Gap.h4,
          itemBuilder: (context, index) {
            final listing = feed.items[index];
            // Router navigation, not OpenContainer. A container transform is
            // prettier, but it builds the detail page inside its own route —
            // so the URL never changes, and a listing opened from the feed
            // could not be shared or bookmarked, which is the whole reason the
            // app runs on path URLs. It also fought the image Hero, which fired
            // at the same time and produced two overlapping motions. The Hero
            // flight under `heroPage` gives one clean transition from every
            // entry point — feed, profile, a trader's listings — identically.
            final card = ListingCardTile(
              listing: listing,
              onTap: () {
                HapticFeedback.lightImpact();
                context.push('/listing/${listing.id}');
              },
            );
            // Reveal each card once. `add` returns false once the index has
            // been seen, so a card scrolled off and back — or the whole feed
            // rebuilt on a search keystroke — returns settled instead of
            // re-running the entrance, which is what used to make the list
            // flicker as it recycled. The set resets with the feed itself.
            final firstReveal = _revealed.add(index);
            return firstReveal
                ? AnimatedListItem(index: index, child: card)
                : card;
          },
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(Gap.x5, Gap.x6, Gap.x5, bottomPadding),
          child: Center(
            child: feed.loadingMore
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : feed.hasMore
                ? OutlinedButton(
                    onPressed: () => ref.read(feedProvider.notifier).loadMore(),
                    child: Text(l.feedLoadMore),
                  )
                : Text(
                    l.feedEnd,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette(context).inkFaint,
                    ),
                  ),
          ),
        ),
      ),
    ];
  }
}

class _Hero extends ConsumerWidget {
  const _Hero({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final me = ref.watch(meProvider).value;
    final p = palette(context);

    return Stack(
      children: [
        const SwapBanner(height: 190, borderRadius: Radii.heroBottom),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.x5, Gap.x2, Gap.x5, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Symbols.location_on_rounded,
                      size: 18,
                      color: Colors.white,
                      fill: 1,
                    ),
                    Gap.w1,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.feedTradingIn.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            me?.region ?? l.feedRegionAny,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => context.push('/notifications'),
                      icon: const Icon(
                        Symbols.notifications_rounded,
                        color: Colors.white,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white24,
                      ),
                    ),
                    Gap.w2,
                    // Profile, reachable from the top as well — a quick tap to
                    // your own account without leaving home for the tab bar.
                    IconButton(
                      onPressed: () => context.go('/profile'),
                      icon: const Icon(
                        Symbols.account_circle_rounded,
                        color: Colors.white,
                        fill: 1,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white24,
                      ),
                    ),
                  ],
                ),
                Gap.h5,
                // Premium: Google M3 Search Bar style
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: Shadows.raised,
                  ),
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    decoration: InputDecoration(
                      hintText: l.feedSearchHint,
                      prefixIcon: Icon(
                        Symbols.search_rounded,
                        color: p.inkSoft,
                      ),
                      suffixIcon: onClear != null
                          ? IconButton(
                              icon: const Icon(Symbols.close_rounded),
                              onPressed: onClear,
                            )
                          : null,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Categories extends StatelessWidget {
  const _Categories({required this.selected, required this.onSelect});
  final ListingTag? selected;
  final ValueChanged<ListingTag?> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // The whole section sits on its own pane of frosted glass — the same
    // liquid-glass the bars are cut from, so it reads as a real window over the
    // wallpaper rather than a flat rectangle the colour of the page. A soft
    // fill (0.72 alpha of the near-white surface) was invisible against the
    // wallpaper; glass picks up the page's green and blue and lifts on a shadow.
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.x5, Gap.x5, Gap.x5, 0),
      child: GlassSurface(
        borderRadius: Radii.rXl,
        specular: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.x5,
                Gap.x4,
                Gap.x4,
                Gap.x3,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      L.of(context).feedCategories,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (selected != null)
                    TextButton(
                      onPressed: () => onSelect(null),
                      child: Text(L.of(context).filterAll),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(Gap.x4, 0, Gap.x4, Gap.x4),
                itemCount: ListingTag.values.length,
                separatorBuilder: (_, _) => Gap.w3,
                itemBuilder: (context, index) => CategoryCard(
                  tag: ListingTag.values[index],
                  selected: selected == ListingTag.values[index],
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelect(
                      selected == ListingTag.values[index]
                          ? null
                          : ListingTag.values[index],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
