import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/models.dart';
import '../data/listing_repository.dart';
import 'feed_shimmer.dart';
import 'listing_card_tile.dart';

class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    // Wait for a pause in typing rather than firing a request per keystroke.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(feedQueryProvider.notifier).search(value);
    });
  }

  String _tagLabel(L l, ListingTag tag) => switch (tag) {
    ListingTag.agri => l.filterAgri,
    ListingTag.livestock => l.filterLivestock,
    ListingTag.machinery => l.filterMachinery,
    ListingTag.transport => l.filterTransport,
    ListingTag.electronics => l.filterElectronics,
    ListingTag.construction => l.filterConstruction,
  };

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final query = ref.watch(feedQueryProvider);
    final feed = ref.watch(feedProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 18,
                            color: p.give,
                          ),
                          const SizedBox(width: 4),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.feedTradingIn.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  letterSpacing: 1.4,
                                  fontWeight: FontWeight.w500,
                                  color: p.inkFaint,
                                ),
                              ),
                              const Text(
                                'Samarqand',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: l.feedNotifications,
                            onPressed: () => ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(content: Text(l.comingSoon)),
                              ),
                            icon: const Icon(Icons.notifications_none_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: l.feedSearchHint,
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: l.clear,
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    ref.read(feedQueryProvider.notifier).search('');
                                    setState(() {});
                                  },
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 44, // increased for text wrapping / premium tap target
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: ListingTag.values.length + 1,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final tag = index == 0
                                ? null
                                : ListingTag.values[index - 1];
                            final selected = query.tag == tag;
                            return ChoiceChip(
                              label: Text(
                                tag == null ? l.filterAll : _tagLabel(l, tag),
                              ),
                              selected: selected,
                              showCheckmark: false,
                              onSelected: (_) => ref
                                  .read(feedQueryProvider.notifier)
                                  .toggleTag(tag),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: feed.when(
                    loading: () => const FeedShimmer(),
                    error: (error, _) => ErrorState(
                      message: error is ApiException && error.isNetworkFailure
                          ? l.errorNetwork
                          : l.errorGeneric,
                      retryLabel: l.retry,
                      onRetry: () => ref.invalidate(feedProvider),
                    ),
                    data: (page) {
                      if (page.items.isEmpty) {
                        return EmptyState(
                          title: l.feedEmpty,
                          hint: l.feedEmptyHint,
                          actionLabel: query.isNarrowed ? l.clear : null,
                          onAction: query.isNarrowed
                              ? () {
                                  _searchController.clear();
                                  ref.read(feedQueryProvider.notifier).reset();
                                }
                              : null,
                        );
                      }
                      return RefreshIndicator(
                        onRefresh: () async => ref.invalidate(feedProvider),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                          itemCount: page.items.length + 1,
                          separatorBuilder: (_, _) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        l.feedHeading,
                                        style: const TextStyle(
                                          fontSize: 19,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.4,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      query.isNarrowed
                                          ? l.feedResults(page.items.length)
                                          : l.feedNearby(page.items.length),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: p.inkFaint,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            final listing = page.items[index - 1];
                            return ListingCardTile(
                              listing: listing,
                              onTap: () => context.push('/listing/${listing.id}'),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
