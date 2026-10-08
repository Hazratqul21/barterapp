import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

import '../../shared/models/models.dart';

/// The public web address listings are shared under, e.g.
/// `https://barter.example.uz`. Set at build time:
///
///   flutter build web --dart-define=PUBLIC_WEB_BASE_URL=https://barter.example.uz
///
/// Empty in development: sharing then sends the text without a link rather
/// than a localhost URL nobody else can open.
const publicWebBaseUrl = String.fromEnvironment('PUBLIC_WEB_BASE_URL');

/// `/l/<id>` — short enough for an SMS, and the path the app's router and the
/// iOS/Android app-link files (docs/DEEPLINKS.md) both claim.
Uri? listingShareUri(String id, {String base = publicWebBaseUrl}) {
  final trimmed = base.trim().replaceAll(RegExp(r'/+$'), '');
  if (trimmed.isEmpty) return null;
  final parsed = Uri.tryParse(trimmed);
  if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) return null;
  return parsed.replace(path: '${parsed.path}/l/$id');
}

/// What goes into the share sheet: title, price, what they want, link.
String listingShareText(
  ListingCard listing,
  String locale, {
  String base = publicWebBaseUrl,
}) {
  final link = listingShareUri(listing.id, base: base);
  return [
    listing.title,
    listing.value.format(locale),
    if (listing.wantsSummary.trim().isNotEmpty) '⇄ ${listing.wantsSummary}',
    ?link?.toString(),
  ].join('\n');
}

/// Opens the platform share sheet. [origin] anchors the iPad popover.
Future<void> shareListing(
  BuildContext context,
  ListingCard listing, {
  Rect? origin,
}) {
  final locale = Localizations.localeOf(context).languageCode;
  return SharePlus.instance.share(
    ShareParams(
      text: listingShareText(listing, locale),
      subject: listing.title,
      sharePositionOrigin: origin,
    ),
  );
}
