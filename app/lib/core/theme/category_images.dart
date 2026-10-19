import '../../shared/models/models.dart';

/// Bundled category photography: stable subjects, available offline.
const Map<ListingTag, String> categoryImages = {
  ListingTag.agri: 'assets/images/category_agri.jpg',
  ListingTag.livestock: 'assets/images/category_livestock.jpg',
  ListingTag.machinery: 'assets/images/category_machinery.jpg',
  ListingTag.transport: 'assets/images/category_transport.jpg',
  ListingTag.electronics: 'assets/images/category_electronics.jpg',
  ListingTag.construction: 'assets/images/category_construction.jpg',
};

String? categoryImage(ListingTag tag) => categoryImages[tag];
