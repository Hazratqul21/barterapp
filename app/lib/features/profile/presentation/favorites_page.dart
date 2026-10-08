import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../feed/data/listing_repository.dart' show FeedState;
import '../../feed/presentation/listing_card_tile.dart';
import '../../auth/data/auth_repository.dart';
import '../../trade/data/trade_repository.dart';

/// Saved listings, page by page.
///
/// The list used to be a single request capped at 50; anything saved beyond
/// that was unreachable. Same cursor rules as the feed.
class FavoritesNotifier extends AsyncNotifier<FeedState> {
  int _generation = 0;

  @override
  Future<FeedState> build() async {
    _generation++;
    final page = await ref.watch(tradeRepositoryProvider).getFavorites();
    return FeedState(items: page.items, cursor: page.nextCursor);
  }

  Future<void> loadMore({bool retry = false}) async {
    final current = state.value;
    if (state.isLoading ||
        current == null ||
        !current.hasMore ||
        current.loadingMore ||
        (current.loadMoreError != null && !retry)) {
      return;
    }
    final generation = _generation;

    state = AsyncData(
      FeedState(
        items: current.items,
        cursor: current.cursor,
        loadingMore: true,
      ),
    );

    try {
      final next = await ref
          .read(tradeRepositoryProvider)
          .getFavorites(cursor: current.cursor);
      if (!ref.mounted || generation != _generation) return;
      final ids = current.items.map((item) => item.id).toSet();
      state = AsyncData(
        FeedState(
          items: [
            ...current.items,
            ...next.items.where((item) => ids.add(item.id)),
          ],
          cursor: next.nextCursor,
        ),
      );
    } catch (error) {
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(
        FeedState(
          items: current.items,
          cursor: current.cursor,
          loadMoreError: error,
        ),
      );
    }
  }
}

final favoritesProvider =
    AsyncNotifierProvider.autoDispose<FavoritesNotifier, FeedState>(
      FavoritesNotifier.new,
    );

class FavoritesPage extends ConsumerStatefulWidget {
  const FavoritesPage({super.key});

  @override
  ConsumerState<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends ConsumerState<FavoritesPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 600) {
      ref.read(favoritesProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    if (!ref.watch(authStateProvider)) {
      return Scaffold(
        appBar: AppBar(title: Text(l.favSavedListings)),
        body: SignInPrompt(reason: l.accountSignIn),
      );
    }
    final async = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.favSavedListings)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: errorMessage(context, e),
          retryLabel: l.retry,
          onRetry: () => ref.invalidate(favoritesProvider),
        ),
        data: (value) {
          final listings = value.items;
          if (listings.isEmpty) {
            return EmptyState(
              title: l.favSavedListings,
              hint: l.favNoSavedListings,
              icon: Icons.bookmark_border,
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Sizes.contentMax),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        sliver: SliverGrid.builder(
                          gridDelegate: ListingGrid.delegate(
                            constraints.maxWidth - 40,
                            MediaQuery.textScalerOf(context),
                          ),
                          itemCount: listings.length,
                          itemBuilder: (context, index) {
                            final item = listings[index];
                            return ListingCardTile(
                              listing: item,
                              onTap: () => context.push('/listing/${item.id}'),
                            );
                          },
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: value.loadingMore
                                ? const CircularProgressIndicator()
                                : value.hasMore
                                ? OutlinedButton(
                                    onPressed: () => ref
                                        .read(favoritesProvider.notifier)
                                        .loadMore(retry: true),
                                    child: Text(
                                      value.loadMoreError != null
                                          ? l.retry
                                          : l.feedLoadMore,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
