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

/// How good a cosmetic grade is, for colouring its chip.
enum ConditionTone { top, mid, low, unknown }

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
    this.model = '',
    this.storage = '',
    this.condition = '',
    this.warrantyMonths = 0,
    this.salePriceValue = 0,
    this.originalPriceValue = 0,
    this.documentId,
    this.firestoreData,
  });

  final String id;
  final String categoryId;
  final String brand;
  final String title;
  final String imageUrl;
  final String price;

  /// The model on its own. [title] is `'\$brand \$model'` and is what the
  /// wishlist and the detail page receive, so it must not change; this is for
  /// display, where showing the brand twice reads as a mistake.
  final String model;

  /// Empty when the document does not carry the field. Every consumer treats
  /// empty as "omit the line" rather than rendering a blank.
  final String storage;

  /// Cosmetic grade. The refurbished marketplaces all lead with this —
  /// Cashify uses Superb / Good / Fair, Back Market Premium / Excellent /
  /// Good / Fair — because it is the thing a buyer is actually choosing
  /// between. Empty when the document does not carry it.
  final String condition;

  /// Zero when the document carries no warranty term, in which case the card
  /// shows no warranty claim at all.
  final int warrantyMonths;

  /// Maps a grade onto a badge tone. Accepts both the Cashify and Back Market
  /// vocabularies plus the obvious synonyms, and falls back to neutral rather
  /// than guessing.
  ConditionTone get conditionTone {
    switch (condition.trim().toLowerCase()) {
      case 'superb':
      case 'premium':
      case 'excellent':
      case 'like new':
      case 'a+':
      case 'a':
        return ConditionTone.top;
      case 'good':
      case 'b':
        return ConditionTone.mid;
      case 'fair':
      case 'average':
      case 'c':
        return ConditionTone.low;
      default:
        return ConditionTone.unknown;
    }
  }

  /// Numeric prices, for computing a discount. Zero means absent.
  final int salePriceValue;
  final int originalPriceValue;

  /// Percentage off, or 0 when there is no higher original price to compare
  /// against.
  int get discountPercent {
    if (originalPriceValue <= 0 || originalPriceValue <= salePriceValue) {
      return 0;
    }
    return ((originalPriceValue - salePriceValue) * 100 / originalPriceValue)
        .round();
  }

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
