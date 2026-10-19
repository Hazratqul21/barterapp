import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../data/billing_repository.dart';
import 'tariffs_page.dart';

/// The boosts on sale for one of the person's own listings.
Future<void> showBoostSheet(BuildContext context, String listingId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => _BoostSheet(listingId: listingId),
  );
}

class _BoostSheet extends ConsumerWidget {
  const _BoostSheet({required this.listingId});
  final String listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final boosts = ref.watch(tariffsProvider(TariffKind.boost));

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.fromLTRB(
          Gap.x5,
          0,
          Gap.x5,
          MediaQuery.paddingOf(context).bottom + Gap.x6,
        ),
        children: [
          Text(
            l.boostSheetTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Gap.h1,
          Text(
            l.boostSheetHint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: palette(context).inkSoft,
            ),
          ),
          Gap.h4,
          boosts.fade(
            loading: () => const Padding(
              padding: EdgeInsets.all(Gap.x6),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e) => ErrorState(
              message: errorMessage(context, e),
              retryLabel: l.retry,
              onRetry: () => ref.invalidate(tariffsProvider(TariffKind.boost)),
            ),
            data: (rows) => rows.isEmpty
                ? EmptyState(
                    icon: Symbols.rocket_launch_rounded,
                    title: l.billingEmpty,
                    hint: l.billingEmptyHint,
                  )
                : Column(
                    children: [
                      for (final t in rows)
                        TariffCard(tariff: t, listingId: listingId),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
