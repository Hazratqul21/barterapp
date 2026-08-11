import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/models.dart';
import '../../feed/data/listing_repository.dart';

class ListingDetailPage extends ConsumerStatefulWidget {
  const ListingDetailPage({super.key, required this.listingId});

  final String listingId;

  @override
  ConsumerState<ListingDetailPage> createState() => _ListingDetailPageState();
}

class _ListingDetailPageState extends ConsumerState<ListingDetailPage> {
  int _shot = 0;
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final async = ref.watch(listingDetailProvider(widget.listingId));

    return Scaffold(
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: ErrorState(
            message: error is ApiException && error.isNetworkFailure
                ? l.errorNetwork
                : l.errorGeneric,
            retryLabel: l.retry,
            onRetry: () =>
                ref.invalidate(listingDetailProvider(widget.listingId)),
          ),
        ),
        data: (listing) => Container(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: _Content(
              listing: listing,
              shot: _shot,
              saved: _saved,
              onShot: (i) => setState(() => _shot = i),
              onToggleSave: () => setState(() => _saved = !_saved),
            ),
          ),
        ),
      ),
      bottomNavigationBar: async.maybeWhen(
        data: (listing) => SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 8, 20, 10),
          // heightFactor 1 makes this bar as tall as its buttons. Without it a
          // Center takes every pixel the Scaffold will give a bottom bar, which
          // is all of them — leaving the listing itself no room at all.
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Row(
                children: [
                  Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    // A route rather than a sheet: the same screen opens from
                    // a match card and the feed, and an offer in progress
                    // should survive a link being shared or a back gesture.
                    context.push('/offer/${listing.id}');
                  },
                  icon: const Icon(Icons.swap_horiz_rounded, size: 19),
                  label: Text(l.listingOffer),
                ),
              ),
            ],
          ),
            ),
          ),
        ),
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }

}

class _Content extends StatelessWidget {
  const _Content({
    required this.listing,
    required this.shot,
    required this.saved,
    required this.onShot,
    required this.onToggleSave,
  });

  final ListingDetail listing;
  final int shot;
  final bool saved;
  final ValueChanged<int> onShot;
  final VoidCallback onToggleSave;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final locale = Localizations.localeOf(context).languageCode;
    final gallery = listing.gallery.isEmpty
        ? [if (listing.imageUrl != null) listing.imageUrl!]
        : listing.gallery;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 280,
          backgroundColor: BrandColors.brand900,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: Icon(context.canPop() ? Icons.arrow_back : Icons.close_rounded),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: onToggleSave,
                style: TextButton.styleFrom(
                  backgroundColor: saved
                      ? BrandColors.gold500
                      : Colors.black.withValues(alpha: 0.35),
                  foregroundColor: Colors.white,
                ),
                child: Text(saved ? l.listingSaved : l.listingSave),
              ),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Hero(
              tag: 'listing-image-${listing.id}',
              child: RemoteImage(
                url: gallery.isEmpty ? null : gallery[shot.clamp(0, gallery.length - 1)],
                semanticLabel: listing.imageAlt,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (gallery.length > 1) ...[
                  SizedBox(
                    height: 60,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: gallery.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) => InkWell(
                        onTap: () => onShot(i),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: i == shot ? p.give : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: RemoteImage(url: gallery[i], semanticLabel: ''),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                Text(
                  listing.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      listing.value.format(locale),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    Pill(
                      label: listing.cashOk ? l.listingCashOk : l.listingCashNo,
                      foreground: listing.cashOk ? p.money : p.inkSoft,
                      background: listing.cashOk
                          ? p.moneySoft
                          : Theme.of(context).colorScheme.surfaceContainerLowest,
                    ),
                  ],
                ),

                const SizedBox(height: 22),
                // The two sides of the trade, stacked — the point of the product.
                _GiveTakeCard(listing: listing),

                const SizedBox(height: 24),
                _SectionLabel(l.listingAbout),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      listing.description,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.6,
                        color: p.inkSoft,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    title: _SectionLabel(l.listingSpecs),
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                    initiallyExpanded: true,
                    shape: const Border(),
                    children: [
                      _SpecRow(l.specCategory, listing.category),
                      _SpecRow(l.specCondition, listing.condition),
                      _SpecRow(l.specQuantity, listing.quantity),
                      _SpecRow(
                        l.specPosted,
                        DateFormat.yMMMd(locale).format(listing.postedAt),
                      ),
                      _SpecRow(l.specValue, listing.value.format(locale),
                          last: true),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                _SectionLabel(l.listingOwner),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        TraderAvatar(
                          url: listing.owner.avatarUrl,
                          name: listing.owner.name,
                          size: 48,
                          isOnline: listing.owner.isOnline,
                          showPresence: true,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      listing.owner.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (listing.owner.isVerified) ...[
                                    const SizedBox(width: 5),
                                    Icon(
                                      Icons.verified_user_outlined,
                                      size: 15,
                                      color: p.give,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(
                                    Icons.star_rounded,
                                    size: 14,
                                    color: BrandColors.gold500,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    listing.owner.rating?.toStringAsFixed(1) ??
                                        '—',
                                    style: const TextStyle(fontSize: 12.5),
                                  ),
                                  Text(
                                    '  ·  ${l.listingTrades(listing.owner.deals)}',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: p.inkSoft,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined, size: 15, color: p.give),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.listingSafety,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: p.inkFaint,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GiveTakeCard extends StatelessWidget {
  const _GiveTakeCard({required this.listing});

  final ListingDetail listing;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              border: BorderDirectional(
                start: BorderSide(color: p.give, width: 3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.listingGives.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.3,
                    fontWeight: FontWeight.w600,
                    color: p.give,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  listing.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Icon(Icons.swap_vert_rounded, size: 18, color: p.give),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            decoration: BoxDecoration(
              border: BorderDirectional(
                start: BorderSide(color: p.take, width: 3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.listingWants.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.3,
                    fontWeight: FontWeight.w600,
                    color: p.take,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final want in listing.wants)
                      Pill(
                        label: want,
                        foreground: p.take,
                        background: p.takeSoft,
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w600,
          color: palette(context).inkFaint,
        ),
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  const _SpecRow(this.label, this.value, {this.last = false});

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: last
          ? null
          : BoxDecoration(
              border: Border(bottom: BorderSide(color: p.hair)),
            ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: p.inkSoft),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
