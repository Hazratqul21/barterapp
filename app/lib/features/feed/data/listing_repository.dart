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

final feedProvider = FutureProvider.autoDispose<Page<ListingCard>>((ref) async {
  final query = ref.watch(feedQueryProvider);
  return ref
      .watch(listingRepositoryProvider)
      .feed(tag: query.tag, query: query.search);
});

final listingDetailProvider = FutureProvider.autoDispose
    .family<ListingDetail, String>((ref, id) {
      return ref.watch(listingRepositoryProvider).detail(id);
    });
