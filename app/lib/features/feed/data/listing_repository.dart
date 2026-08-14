import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/models/models.dart';

class ListingRepository {
  ListingRepository(this._api);

  final ApiClient _api;

  Future<Page<ListingCard>> feed({
    String? categoryId,
    String? query,
    String? cursor,
  }) {
    return _api.get(
      '/listings',
      query: {
        'category': ?categoryId,
        if (query != null && query.trim().isNotEmpty) 'q': query,
        'cursor': ?cursor,
      },
      parse: (data) => Page.fromJson(
        data as Map<String, dynamic>,
        ListingCard.fromJson,
      ),
    );
  }

  Future<ListingDetail> detail(String id) {
    return _api.get(
      '/listings/$id',
      parse: (data) => ListingDetail.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<List<ListingCard>> byTrader(String userId) {
    return _api.get(
      '/users/$userId/listings',
      parse: (data) => (data as List)
          .map((e) => ListingCard.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
  Future<List<CategoryModel>> categories() async {
    try {
      return await _api.get(
        '/categories',
        parse: (data) => (data as List)
            .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } catch (_) {
      // Mock for now until endpoint is officially available
      await Future.delayed(const Duration(milliseconds: 600));
      return const [
        CategoryModel(id: 'agri', name: 'Dehqonchilik', imageUrl: 'https://images.unsplash.com/photo-1592982537447-6f23f8510a26?auto=format&fit=crop&q=80&w=400'),
        CategoryModel(id: 'livestock', name: 'Chorvachilik', imageUrl: 'https://images.unsplash.com/photo-1516467508483-a7212febe31a?auto=format&fit=crop&q=80&w=400'),
        CategoryModel(id: 'construction', name: 'Qurilish', imageUrl: 'https://images.unsplash.com/photo-1503387762-592deb58ef4e?auto=format&fit=crop&q=80&w=400'),
        CategoryModel(id: 'machinery', name: 'Texnika', imageUrl: 'https://images.unsplash.com/photo-1581091226825-a6a2a5aee158?auto=format&fit=crop&q=80&w=400'),
        CategoryModel(id: 'transport', name: 'Transport', imageUrl: 'https://images.unsplash.com/photo-1494976388531-d1058494cdd8?auto=format&fit=crop&q=80&w=400'),
        CategoryModel(id: 'electronics', name: 'Elektronika', imageUrl: 'https://images.unsplash.com/photo-1498049794561-7780e7231661?auto=format&fit=crop&q=80&w=400'),
      ];
    }
  }
}

final listingRepositoryProvider = Provider<ListingRepository>(
  (ref) => ListingRepository(ref.watch(apiClientProvider)),
);

final categoriesProvider = FutureProvider.autoDispose<List<CategoryModel>>((ref) {
  return ref.watch(listingRepositoryProvider).categories();
});

class FeedQuery {
  const FeedQuery({this.categoryId, this.search = ''});

  final String? categoryId;
  final String search;

  bool get isNarrowed => categoryId != null || search.trim().isNotEmpty;

  FeedQuery copyWith({String? categoryId, bool clearCategory = false, String? search}) {
    return FeedQuery(
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      search: search ?? this.search,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FeedQuery && other.categoryId == categoryId && other.search == search;

  @override
  int get hashCode => Object.hash(categoryId, search);
}

class FeedQueryNotifier extends Notifier<FeedQuery> {
  @override
  FeedQuery build() => const FeedQuery();

  void toggleCategory(String? categoryId) {
    state = categoryId == null || state.categoryId == categoryId
        ? state.copyWith(clearCategory: true)
        : state.copyWith(categoryId: categoryId);
  }

  void search(String value) => state = state.copyWith(search: value);

  void reset() => state = const FeedQuery();
}

final feedQueryProvider = NotifierProvider<FeedQueryNotifier, FeedQuery>(
  FeedQueryNotifier.new,
);

/// Everything the feed has loaded so far, plus whether there is more.
///
/// Cursor pages, because the feed reorders constantly and an offset would
/// repeat or skip rows as listings are published underneath the reader.
class FeedState {
  const FeedState({
    this.items = const [],
    this.cursor,
    this.loadingMore = false,
  });

  final List<ListingCard> items;

  /// Null once the server has nothing left to give.
  final String? cursor;

  final bool loadingMore;

  bool get hasMore => cursor != null;
}

/// The feed, page by page.
///
/// Only the first twenty listings were ever shown: `next_cursor` came back on
/// every response and nothing asked for it. On a marketplace whose whole
/// promise is "somebody out there wants what you have", stopping at twenty is
/// the difference between finding them and not.
class FeedNotifier extends AsyncNotifier<FeedState> {
  @override
  Future<FeedState> build() async {
    // Re-runs whenever the filter or the language changes, which is exactly
    // when the accumulated pages stop being valid.
    final query = ref.watch(feedQueryProvider);
    final page = await ref
        .watch(listingRepositoryProvider)
        .feed(categoryId: query.categoryId, query: query.search);
    return FeedState(items: page.items, cursor: page.nextCursor);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;

    state = AsyncData(
      FeedState(
        items: current.items,
        cursor: current.cursor,
        loadingMore: true,
      ),
    );

    final query = ref.read(feedQueryProvider);
    try {
      final next = await ref
          .read(listingRepositoryProvider)
          .feed(categoryId: query.categoryId, query: query.search, cursor: current.cursor);
      state = AsyncData(
        FeedState(
          items: [...current.items, ...next.items],
          cursor: next.nextCursor,
        ),
      );
    } catch (_) {
      // Keep what is already on screen; the footer offers another try. Replacing
      // a loaded feed with an error page because page three failed would throw
      // away two pages the reader was in the middle of.
      state = AsyncData(
        FeedState(items: current.items, cursor: current.cursor),
      );
    }
  }
}

final feedProvider =
    AsyncNotifierProvider.autoDispose<FeedNotifier, FeedState>(
      FeedNotifier.new,
    );

final listingDetailProvider = FutureProvider.autoDispose
    .family<ListingDetail, String>((ref, id) {
      return ref.watch(listingRepositoryProvider).detail(id);
    });
