import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
    final locale = Localizations.localeOf(context).languageCode;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 186,
                  width: double.infinity,
                  child: Hero(
                    tag: 'listing-image-${listing.id}',
                    child: RemoteImage(
                      url: listing.imageUrl,
                      semanticLabel: listing.imageAlt,
                    ),
                  ),
                ),
                if (listing.isPremium)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Pill(
                      label: l.feedPremium,
                      foreground: p.money,
                      background: p.moneySoft,
                    ),
                  ),
                // The owner rides on the photo, so the card names a person
                // before it names a price.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 32, 14, 10),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Color(0xBF06291D), Colors.transparent],
                      ),
                    ),
                    child: Row(
                      children: [
                        if (listing.owner.isVerified) ...[
                          const Icon(
                            Icons.verified_user_outlined,
                            size: 15,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            listing.owner.displayName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Pill(
                      icon: Icons.swap_horiz_rounded,
                      label: '${l.feedLookingFor} ${listing.wantsSummary}',
                      foreground: p.take,
                      background: p.takeSoft,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Divider(color: p.hair, height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        listing.value.format(locale),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l.feedEstValue,
                        style: TextStyle(fontSize: 11, color: p.inkFaint),
                      ),
                      const Spacer(),
                      Icon(Icons.schedule_rounded, size: 14, color: p.inkFaint),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat.yMMMd(locale).format(listing.postedAt),
                        style: TextStyle(fontSize: 11.5, color: p.inkSoft),
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
