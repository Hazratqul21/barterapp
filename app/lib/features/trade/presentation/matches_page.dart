import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/widgets/common.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/models.dart';
import '../data/trade_repository.dart';

class MatchesPage extends ConsumerWidget {
  const MatchesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);
    final matchesAsync = ref.watch(matchesProvider);
    final locale = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.matchesTitle),
      ),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 700), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text(
              l.matchesLede,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: p.inkFaint,
              ),
            ),
          ),
          Expanded(
            child: matchesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => ErrorState(
                message: errorMessage(context, e),
                retryLabel: l.retry,
                onRetry: () => ref.invalidate(matchesProvider),
              ),
              data: (matches) {
                if (matches.isEmpty) {
                  return EmptyState(
                    title: l.matchesEmpty,
                    hint: '',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(matchesProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: matches.length,
                    itemBuilder: (context, index) {
                      final match = matches[index];
                      return AnimatedListItem(
                        index: index,
                        child: _MatchCard(
                          match: match,
                          locale: locale,
                          l: l,
                          p: p,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ))),
    );
  }
}

class _MatchCard extends ConsumerWidget {
  const _MatchCard({
    required this.match,
    required this.locale,
    required this.l,
    required this.p,
  });

  final TradeMatch match;
  final String locale;
  final L l;
  final BarterPalette p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: p.give, width: 4),
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.matchesYours,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: p.give,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: double.infinity,
                            height: 100,
                            child: RemoteImage(
                              url: match.mine.imageUrl,
                              semanticLabel: match.mine.imageAlt,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          match.mine.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          match.mine.value.format(locale),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: p.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: theme.colorScheme.tertiaryContainer,
                        child: Icon(
                          Symbols.swap_horiz_rounded,
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${match.score}%',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: p.take, width: 4),
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.matchesTheirs,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: p.take,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: double.infinity,
                            height: 100,
                            child: RemoteImage(
                              url: match.theirs.imageUrl,
                              semanticLabel: match.theirs.imageAlt,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          match.theirs.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          match.theirs.value.format(locale),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: p.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    TraderAvatar(url: match.owner.avatarUrl, name: match.owner.displayName, size: 28),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        match.owner.displayName,
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (match.owner.rating != null) ...[
                      const Icon(Symbols.star_rounded, size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        match.owner.rating!.toStringAsFixed(1),
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  match.reason,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: p.inkSoft,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        ref.read(tradeRepositoryProvider).dismissMatch(match.id);
                        ref.invalidate(matchesProvider);
                      },
                      child: Text(l.matchesSkip),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: () => context.push('/offer/${match.theirs.id}'),
                      child: Text(l.matchesOffer),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
