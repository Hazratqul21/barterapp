import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../feed/presentation/listing_card_tile.dart';
import '../../auth/data/auth_repository.dart';
import '../../trade/data/trade_repository.dart';

final favoritesProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(tradeRepositoryProvider).getFavorites(),
);

class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        data: (listings) {
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
                  final columns = constraints.maxWidth >= 600 ? 2 : 1;
                  final width =
                      (constraints.maxWidth - 40 - 16 * (columns - 1)) /
                      columns;
                  final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
                  return GridView.builder(
                    padding: const EdgeInsets.all(20),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      mainAxisExtent: width * 0.62 + 156 * scale,
                    ),
                    itemCount: listings.length,
                    itemBuilder: (context, index) {
                      final item = listings[index];
                      return ListingCardTile(
                        listing: item,
                        onTap: () => context.push('/listing/${item.id}'),
                      );
                    },
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
