import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../feed/presentation/listing_card_tile.dart';
import '../../trade/data/trade_repository.dart';

final favoritesProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(tradeRepositoryProvider).getFavorites(),
);

class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final async = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Saved Listings',
        ), // Fallback to hardcoded if not in l10n
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: errorMessage(context, e),
          retryLabel: l.retry,
          onRetry: () => ref.invalidate(favoritesProvider),
        ),
        data: (listings) {
          if (listings.isEmpty) {
            return const EmptyState(
              title: 'Saved Listings',
              hint: 'No saved listings yet',
              icon: Icons.bookmark_border,
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Sizes.contentMax),
              child: GridView.builder(
                padding: Gap.screen,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: Gap.x4,
                  crossAxisSpacing: Gap.x4,
                  childAspectRatio: 0.75,
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
          );
        },
      ),
    );
  }
}
