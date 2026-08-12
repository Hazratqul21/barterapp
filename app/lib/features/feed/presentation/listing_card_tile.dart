import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/models.dart';

/// A feed card. Both sides of the trade are visible at a glance: what is on
/// offer, and what the owner wants for it.
class ListingCardTile extends StatelessWidget {
  const ListingCardTile({
    super.key,
    required this.listing,
    required this.onTap,
  });

  final ListingCard listing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;

    return Pressable(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        color: theme.colorScheme.surfaceContainerLow,
        margin: const EdgeInsets.only(bottom: Gap.x2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Photo(listing: listing),
            Padding(
              padding: const EdgeInsets.all(Gap.x4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge,
                  ),
                  Gap.h3,

                  // The other half of the trade. A price alone would make this
                  // a classifieds card; what the owner wants back is the
                  // product.
                  Row(
                    children: [
                      Icon(
                        Symbols.swap_horiz_rounded,
                        size: Sizes.iconMd,
                        color: p.take,
                      ),
                      Gap.w2,
                      Expanded(
                        child: RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: theme.textTheme.bodyMedium,
                            children: [
                              TextSpan(
                                text: '${l.feedLookingFor} ',
                                style: TextStyle(color: p.inkFaint),
                              ),
                              TextSpan(
                                text: listing.wantsSummary,
                                style: TextStyle(
                                  color: p.take,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  Gap.h3,
                  Divider(color: p.hair, height: 1),
                  Gap.h3,

                  // Wrap, not Row: with the price, its caption and the date all
                  // set as unbounded text, a long value in Russian overflowed
                  // the card by up to 23 pixels.
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: Gap.x2,
                    runSpacing: Gap.x1,
                    children: [
                      Text(
                        listing.value.format(locale),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        l.feedEstValue,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: p.inkFaint,
                        ),
                      ),
                      if (listing.distanceKm != null)
                        _Meta(
                          icon: Symbols.near_me_rounded,
                          text: '${listing.distanceKm!.round()} km',
                        ),
                      _Meta(
                        icon: Symbols.schedule_rounded,
                        text: DateFormat.yMMMd(locale).format(listing.postedAt),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The photograph, with the category on one corner and the owner across the
/// bottom — so the card names a person and a kind of thing before a price.
class _Photo extends StatelessWidget {
  const _Photo({required this.listing});

  final ListingCard listing;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);

    return SizedBox(
      height: Sizes.cardImage,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Hero(
            tag: 'listing-image-${listing.id}',
            child: RemoteImage(
              url: listing.imageUrl,
              semanticLabel: listing.imageAlt,
            ),
          ),
          Positioned(
            top: Gap.x3,
            left: Gap.x3,
            child: CategoryBadge(tag: listing.tag),
          ),
          if (listing.isPremium)
            Positioned(
              top: Gap.x3,
              right: Gap.x3,
              child: Pill(
                label: l.feedPremium,
                foreground: p.money,
                background: p.moneySoft,
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                Gap.x4,
                Gap.x8,
                Gap.x4,
                Gap.x3,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xCC06291D), Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  if (listing.owner.isVerified) ...[
                    const Icon(
                      Symbols.verified_rounded,
                      size: Sizes.iconSm,
                      color: Colors.white,
                    ),
                    Gap.w1,
                  ],
                  Expanded(
                    child: Text(
                      listing.owner.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (listing.owner.rating != null) ...[
                    Gap.w2,
                    const Icon(
                      Symbols.star_rounded,
                      size: Sizes.iconSm,
                      color: Colors.white,
                      fill: 1,
                    ),
                    Gap.w1,
                    Text(
                      listing.owner.rating!.toStringAsFixed(1),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// An icon and a short value — distance, date.
class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: Sizes.iconSm, color: p.inkFaint),
        Gap.w1,
        Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: p.inkSoft),
        ),
      ],
    );
  }
}
