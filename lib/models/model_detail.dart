class ModelDetail {
  /// The brand this model belongs to.
  ///
  /// Empty when it was read from inside a brand that already knows its own
  /// name; set when it came from a search across every brand, which is the
  /// only way a result can tell the next screen where to look up its price.
  final String brand;

  final String name;
  final String category;

  /// Which series this model belongs to — "A series", "Edge series".
  ///
  /// Worked out from the name by `deriveSeries`, not stored in Firestore.
  final String series;

  final int maxPrice;
  final String? imageUrl;
  final String? docId;

  ModelDetail({
    this.brand = '',
    required this.name,
    required this.category,
    this.series = 'Other',
    required this.maxPrice,
    this.imageUrl,
    this.docId,
  });
}
