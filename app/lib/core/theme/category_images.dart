import '../../shared/models/models.dart';

/// The photograph shown at the top of each category card.
///
/// One editable place. Drop your own image URL (or a bundled asset path handled
/// by [RemoteImage]) next to a category and the card picks it up — this is where
/// the AI-generated category art from the design reference goes. Leave a value
/// null and the card falls back to its coloured gradient with the drawn mark,
/// so a missing or slow image never shows a broken card.
///
/// The defaults are Unsplash photos that match each category; replace them with
/// your own to get the exact look from the reference.
const Map<ListingTag, String?> categoryImages = {
  ListingTag.agri:
      'https://images.unsplash.com/photo-1560493676-04071c5f467b?w=400&h=520&fit=crop&auto=format',
  ListingTag.livestock:
      'https://images.unsplash.com/photo-1516467508483-a7212febe31a?w=400&h=520&fit=crop&auto=format',
  ListingTag.machinery:
      'https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=400&h=520&fit=crop&auto=format',
  ListingTag.transport:
      'https://images.unsplash.com/photo-1601584115197-04ecc0da31d7?w=400&h=520&fit=crop&auto=format',
  ListingTag.electronics:
      'https://images.unsplash.com/photo-1518770660439-4636190af475?w=400&h=520&fit=crop&auto=format',
  ListingTag.construction:
      'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=400&h=520&fit=crop&auto=format',
};

String? categoryImage(ListingTag tag) => categoryImages[tag];
