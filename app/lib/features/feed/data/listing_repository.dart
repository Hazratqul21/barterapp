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
    double? minPrice,
    double? maxPrice,
    String? region,
    String? sortBy,
  }) async {
    try {
      return await _api.get(
        '/listings',
        query: {
          'tag': ?categoryId,
          if (query != null && query.trim().isNotEmpty) 'q': query,
          'cursor': ?cursor,
          if (minPrice != null)
            'min_value': (minPrice * 100).round().toString(),
          if (maxPrice != null)
            'max_value': (maxPrice * 100).round().toString(),
          if (region != null && region.trim().isNotEmpty) 'region': region,
          if (sortBy != null && sortBy.trim().isNotEmpty) 'sort': sortBy,
        },
        parse: (data) =>
            Page.fromJson(data as Map<String, dynamic>, ListingCard.fromJson),
      );
    } catch (_) {
      rethrow;
    }
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
      rethrow;
    }
  }
}

final listingRepositoryProvider = Provider<ListingRepository>(
  (ref) => ListingRepository(ref.watch(apiClientProvider)),
);

final categoriesProvider = FutureProvider.autoDispose<List<CategoryModel>>((
  ref,
) {
  return ref.watch(listingRepositoryProvider).categories();
});

class FeedQuery {
  const FeedQuery({
    this.categoryId,
    this.search = '',
    this.minPrice,
    this.maxPrice,
    this.region,
    this.sortBy = 'new',
  });

  final String? categoryId;
  final String search;
  final double? minPrice;
  final double? maxPrice;
  final String? region;
  final String sortBy;

  bool get isNarrowed =>
      categoryId != null ||
      search.trim().isNotEmpty ||
      minPrice != null ||
      maxPrice != null ||
      region != null ||
      sortBy != 'new';

  FeedQuery copyWith({
    String? categoryId,
    bool clearCategory = false,
    String? search,
    double? minPrice,
    bool clearMinPrice = false,
    double? maxPrice,
    bool clearMaxPrice = false,
    String? region,
    bool clearRegion = false,
    String? sortBy,
  }) {
    return FeedQuery(
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      search: search ?? this.search,
      minPrice: clearMinPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
      region: clearRegion ? null : (region ?? this.region),
      sortBy: sortBy ?? this.sortBy,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FeedQuery &&
      other.categoryId == categoryId &&
      other.search == search &&
      other.minPrice == minPrice &&
      other.maxPrice == maxPrice &&
      other.region == region &&
      other.sortBy == sortBy;

  @override
  int get hashCode =>
      Object.hash(categoryId, search, minPrice, maxPrice, region, sortBy);
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

  void setFilters({
    double? minPrice,
    double? maxPrice,
    String? region,
    String? sortBy,
  }) {
    state = state.copyWith(
      minPrice: minPrice,
      clearMinPrice: minPrice == null,
      maxPrice: maxPrice,
      clearMaxPrice: maxPrice == null,
      region: region,
      clearRegion: region == null,
      sortBy: sortBy,
    );
  }

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
    this.loadMoreError,
  });

  final List<ListingCard> items;

  /// Null once the server has nothing left to give.
  final String? cursor;

  final bool loadingMore;
  final Object? loadMoreError;

  bool get hasMore => cursor != null;
}

/// The feed, page by page.
///
/// Only the first twenty listings were ever shown: `next_cursor` came back on
/// every response and nothing asked for it. On a marketplace whose whole
/// promise is "somebody out there wants what you have", stopping at twenty is
/// the difference between finding them and not.
class FeedNotifier extends AsyncNotifier<FeedState> {
  int _generation = 0;
  @override
  Future<FeedState> build() async {
    // Re-runs whenever the filter or the language changes, which is exactly
    // when the accumulated pages stop being valid.
    _generation++;
    final query = ref.watch(feedQueryProvider);
    final page = await ref
        .watch(listingRepositoryProvider)
        .feed(
          categoryId: query.categoryId,
          query: query.search,
          minPrice: query.minPrice,
          maxPrice: query.maxPrice,
          region: query.region,
          sortBy: query.sortBy,
        );
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

    final query = ref.read(feedQueryProvider);
    try {
      final next = await ref
          .read(listingRepositoryProvider)
          .feed(
            categoryId: query.categoryId,
            query: query.search,
            cursor: current.cursor,
            minPrice: query.minPrice,
            maxPrice: query.maxPrice,
            region: query.region,
            sortBy: query.sortBy,
          );
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

final feedProvider = AsyncNotifierProvider.autoDispose<FeedNotifier, FeedState>(
  FeedNotifier.new,
);

final listingDetailProvider = FutureProvider.autoDispose
    .family<ListingDetail, String>((ref, id) {
      return ref.watch(listingRepositoryProvider).detail(id);
    });
