class ModelDetail {
  final String name;
  final String category;
  final int maxPrice;
  final String? imageUrl;
  final String? docId;

  ModelDetail({
    required this.name,
    required this.category,
    required this.maxPrice,
    this.imageUrl,
    this.docId,
  });
}
