import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/models.dart';

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
        // Premium: M3 surfaceContainerLow rangidan foydalanamiz
        color: theme.colorScheme.surfaceContainerLow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.rLg,
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
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
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  Gap.h3,
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
                            style: theme.textTheme.bodySmall,
                            children: [
                              TextSpan(
                                text: '${l.feedLookingFor} ',
                                style: TextStyle(color: p.inkFaint),
                              ),
                              TextSpan(
                                text: listing.wantsSummary,
                                style: TextStyle(
                                  color: p.take,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Gap.h3,
                  Divider(color: p.hair.withValues(alpha: 0.5), height: 1),
                  Gap.h3,
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: Gap.x3,
                    runSpacing: Gap.x1,
                    children: [
                      Text(
                        listing.value.format(locale),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (listing.distanceKm != null)
                        _Meta(
                          icon: Symbols.near_me_rounded,
                          text: '${listing.distanceKm!.round()} km',
                        ),
                      _Meta(
                        icon: Symbols.schedule_rounded,
                        text: formatDate(context, listing.postedAt),
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

class _Photo extends StatelessWidget {
  const _Photo({required this.listing});
  final ListingCard listing;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);

    return SizedBox(
      height: 190,
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
            child: CategoryBadge(tag: listing.tag, compact: true),
          ),
          if (listing.isPremium)
            Positioned(
              top: Gap.x3,
              right: Gap.x3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: p.money,
                  borderRadius: Radii.rFull,
                ),
                child: Text(
                  l.feedPremium.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(Gap.x4, Gap.x6, Gap.x4, Gap.x2),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0x99000000), Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      listing.owner.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (listing.owner.rating != null) ...[
                    Gap.w1,
                    const Icon(Symbols.star_rounded, size: 12, color: Colors.white, fill: 1),
                    Gap.w1,
                    Text(
                      listing.owner.rating!.toStringAsFixed(1),
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
        Icon(icon, size: 14, color: p.inkFaint),
        Gap.w1,
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: p.inkSoft,
                fontSize: 11,
              ),
        ),
      ],
    );
  }
}
