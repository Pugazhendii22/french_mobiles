/// A device category shown in the home category grid.
class HomeCategory {
  const HomeCategory({
    required this.id,
    required this.title,
    required this.iconUrl,
    this.available = true,
  });

  final String id;
  final String title;
  final String iconUrl;

  /// False for categories with no catalog behind them yet. The grid still
  /// shows them, marked as upcoming, matching the previous home behaviour
  /// where these rendered a "Coming soon" panel.
  final bool available;
}

/// A second-hand device listing.
///
/// [documentId] and [firestoreData] carry the raw Firestore document through
/// to the detail page and the wishlist, which both expect the unmodified map.
class HomeProduct {
  const HomeProduct({
    required this.id,
    required this.categoryId,
    required this.brand,
    required this.title,
    required this.imageUrl,
    required this.price,
    this.documentId,
    this.firestoreData,
  });

  final String id;
  final String categoryId;
  final String brand;
  final String title;
  final String imageUrl;
  final String price;
  final String? documentId;
  final Map<String, dynamic>? firestoreData;
}

/// Category tiles. Icon URLs are carried over unchanged from the previous
/// home screen.
const List<HomeCategory> homeCategories = [
  HomeCategory(
    id: 'mobile',
    title: 'Mobile',
    iconUrl:
        'https://res.cloudinary.com/dvsnmkgwx/image/upload/v1788426580/images-removebg-preview_gzons0.png',
  ),
  HomeCategory(
    id: 'laptops',
    title: 'Laptops',
    iconUrl:
        'https://res.cloudinary.com/dvsnmkgwx/image/upload/v1788430704/mbp-14-digitalmat-gallery-6-202410-removebg-preview_xmqnvh.png',
    available: false,
  ),
  HomeCategory(
    id: 'earparts',
    title: 'Earbuds',
    iconUrl:
        'https://res.cloudinary.com/dvsnmkgwx/image/upload/v1788430875/airpods-pro-3-hero-select-202509_FMT_WHH-removebg-preview_lnjjup.png',
    available: false,
  ),
];
