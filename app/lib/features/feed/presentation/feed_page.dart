import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/backgrounds.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/models.dart';
import '../../auth/data/auth_repository.dart';
import '../data/listing_repository.dart';
import 'feed_banner.dart';
import 'feed_shimmer.dart';
import 'listing_card_tile.dart';

/// The discovery feed.
///
/// Someone with a spare laptop who wants their flat painted does not read a row
/// of grey words — they look for the picture of the thing they have. So the
/// categories are drawn, the header states where they are trading, and the
/// search field floats over a green-to-blue field that is the swap itself.
class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

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

  /// Fetch the next page while there is still a screenful left to read, so the
  /// list never actually stops under the reader's thumb.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 600) {
      ref.read(feedProvider.notifier).loadMore();
    }
  }

  void _onSearchChanged(String value) {
    // Wait for a pause in typing rather than firing a request per keystroke.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(feedQueryProvider.notifier).search(value);
    });
    setState(() {}); // the clear button appears as soon as there is text
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(feedQueryProvider.notifier).search('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final query = ref.watch(feedQueryProvider);
    final feed = ref.watch(feedProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(feedProvider),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Sizes.contentMax),
            child: CustomScrollView(
              controller: _scrollController,
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
                const SliverToBoxAdapter(child: FeedBanner()),
                SliverToBoxAdapter(
                  child: _Categories(
                    selected: query.tag,
                    onSelect: (tag) =>
                        ref.read(feedQueryProvider.notifier).toggleTag(tag),
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
                                _searchController.clear();
                                ref.read(feedQueryProvider.notifier).reset();
                              }
                            : null,
                      ),
                    ),
                  ],
                  AsyncData(:final value) => _results(l, query, value),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _results(L l, FeedQuery query, FeedState feed) {
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
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text(
                query.isNarrowed
                    ? l.feedResults(feed.items.length)
                    : l.feedNearby(feed.items.length),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
            final card = ListingCardTile(
              listing: listing,
              onTap: () => context.push('/listing/${listing.id}'),
            );
            // Only the first screenful is staggered. Delaying by index all the
            // way down means page four arrives seconds after it is scrolled
            // to, which reads as the app being slow rather than as motion.
            if (index >= 4) return card;
            return card
                .animate()
                .fadeIn(
                  delay: Duration(milliseconds: 60 * index),
                  duration: M3Motion.medium3,
                )
                .slideY(
                  begin: 0.05,
                  end: 0,
                  delay: Duration(milliseconds: 60 * index),
                  duration: M3Motion.medium4,
                  curve: M3Motion.emphasizedDecelerate,
                );
          },
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          // Clear of the tab bar and the create button.
          padding: const EdgeInsets.fromLTRB(Gap.x5, Gap.x6, Gap.x5, Gap.x14),
          child: Center(
            child: feed.loadingMore
                ? const SizedBox(
                    width: Sizes.iconLg,
                    height: Sizes.iconLg,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : feed.hasMore
                ? OutlinedButton(
                    onPressed: () => ref.read(feedProvider.notifier).loadMore(),
                    child: Text(l.feedLoadMore),
                  )
                : Text(
                    l.feedEnd,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: palette(context).inkFaint,
                    ),
                  ),
          ),
        ),
      ),
    ];
  }
}

/// The header: where you are trading, what is new, and the search field.
///
/// The gradient is the product — green flows into blue, give into take — and
/// the search field sits on the seam between it and the page.
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

    // Where this person actually trades, not a name typed into the source. The
    // header used to read "Samarqand" for everybody, including a workshop in
    // Tashkent.
    final region = me?.region ?? l.feedRegionAny;

    return Stack(
      children: [
        const SwapBanner(height: 168, borderRadius: Radii.heroBottom),
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
                      size: Sizes.iconMd,
                      color: Colors.white,
                    ),
                    Gap.w1,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.feedTradingIn.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                          Text(
                            region,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: l.notificationsTitle,
                      // The notifications screen is finished and reachable from
                      // the inbox; this bell used to answer "coming soon".
                      onPressed: () => context.push('/notifications'),
                      icon: const Icon(Symbols.notifications_rounded),
                      style: IconButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                  ],
                ),
                Gap.h5,
                Material(
                  elevation: 0,
                  borderRadius: Radii.rMd,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: Radii.rMd,
                      boxShadow: Shadows.raised,
                      color: theme.colorScheme.surfaceContainerLowest,
                    ),
                    child: TextField(
                      controller: controller,
                      onChanged: onChanged,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: l.feedSearchHint,
                        fillColor: theme.colorScheme.surfaceContainerLowest,
                        prefixIcon: const Icon(Symbols.search_rounded),
                        suffixIcon: onClear == null
                            ? null
                            : IconButton(
                                tooltip: l.clear,
                                icon: const Icon(
                                  Symbols.close_rounded,
                                  size: Sizes.iconMd,
                                ),
                                onPressed: onClear,
                              ),
                      ),
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

/// Six categories, drawn.
class _Categories extends StatelessWidget {
  const _Categories({required this.selected, required this.onSelect});

  final ListingTag? selected;
  final ValueChanged<ListingTag?> onSelect;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.x5, Gap.x6, Gap.x5, Gap.x3),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.feedCategories,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              if (selected != null)
                TextButton(
                  onPressed: () => onSelect(null),
                  child: Text(l.filterAll),
                ),
            ],
          ),
        ),
        SizedBox(
          // Icon 56 + gap 8 + two lines of label + the tile's own padding.
          // Measured, not guessed: 108 clipped the second line by two pixels.
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Gap.x5),
            itemCount: ListingTag.values.length,
            separatorBuilder: (_, _) => Gap.w3,
            itemBuilder: (context, index) {
              final tag = ListingTag.values[index];
              return CategoryTile(
                tag: tag,
                selected: selected == tag,
                // Tapping the chosen one clears it, so the filter can always be
                // undone without hunting for a separate control.
                onTap: () => onSelect(selected == tag ? null : tag),
              );
            },
          ),
        ),
        Divider(color: p.hair, height: Gap.x8, indent: Gap.x5, endIndent: Gap.x5),
      ],
    );
  }
}
