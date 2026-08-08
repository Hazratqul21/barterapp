import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/models/models.dart';

class ListingRepository {
  ListingRepository(this._api);

  final ApiClient _api;

  Future<Page<ListingCard>> feed({
    ListingTag? tag,
    String? query,
    String? cursor,
  }) {
    return _api.get(
      '/listings',
      query: {
        'tag': ?tag?.name,
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
}

final listingRepositoryProvider = Provider<ListingRepository>(
  (ref) => ListingRepository(ref.watch(apiClientProvider)),
);

/// What the feed is currently narrowed to. Kept separate from the results so a
/// filter tap does not rebuild the whole screen twice.
class FeedQuery {
  const FeedQuery({this.tag, this.search = ''});

  final ListingTag? tag;
  final String search;

  bool get isNarrowed => tag != null || search.trim().isNotEmpty;

  FeedQuery copyWith({ListingTag? tag, bool clearTag = false, String? search}) {
    return FeedQuery(
      tag: clearTag ? null : (tag ?? this.tag),
      search: search ?? this.search,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FeedQuery && other.tag == tag && other.search == search;

  @override
  int get hashCode => Object.hash(tag, search);
}

class FeedQueryNotifier extends Notifier<FeedQuery> {
  @override
  FeedQuery build() => const FeedQuery();

  void toggleTag(ListingTag? tag) {
    state = tag == null || state.tag == tag
        ? state.copyWith(clearTag: true)
        : state.copyWith(tag: tag);
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
        .feed(tag: query.tag, query: query.search);
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
          .feed(tag: query.tag, query: query.search, cursor: current.cursor);
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
