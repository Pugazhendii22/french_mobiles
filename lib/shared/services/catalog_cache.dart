import '../../models/model_detail.dart';

/// Remembers brand catalogues for the life of the process.
///
/// The browsing list and the price that matters are two different things. A
/// model tile shows a headline — "up to ₹40,000" — which exists to help
/// someone choose what to tap; the number a quote is built from is read fresh
/// from the variants the moment they tap it. So the list can be cached
/// aggressively without any risk of quoting a stale price, because the list's
/// figure never becomes a quote.
///
/// When that fresh read disagrees with what was cached, [updateHeadlinePrice]
/// corrects the stored copy, so going back shows the real number rather than
/// the one that was wrong.
///
/// Deliberately not persisted to disk and deliberately without a timer:
/// restarting the app clears it, and a price that drifts within one session
/// is corrected the moment it is acted on. Firestore's own disk cache already
/// makes a cold start cheap.
class CatalogCache {
  CatalogCache._();

  static final Map<String, List<ModelDetail>> _modelsByBrand = {};

  /// Keyed the way the queries are, so casing cannot split the cache.
  static String _key(String brand) => brand.toLowerCase();

  /// The models held for [brand], or null if that brand has not been loaded.
  static List<ModelDetail>? models(String brand) {
    final cached = _modelsByBrand[_key(brand)];
    if (cached == null) return null;
    // A copy: callers sort and filter their own list, and doing that in place
    // would reorder what everyone else reads.
    return List<ModelDetail>.from(cached);
  }

  static void storeModels(String brand, List<ModelDetail> models) {
    _modelsByBrand[_key(brand)] = List<ModelDetail>.from(models);
  }

  /// Corrects one model's headline price after a real read of its variants.
  ///
  /// Does nothing when the brand is not cached or the price is unchanged, so
  /// the common case costs nothing.
  static void updateHeadlinePrice(String brand, String docId, int maxPrice) {
    final models = _modelsByBrand[_key(brand)];
    if (models == null) return;

    final index = models.indexWhere((m) => m.docId == docId);
    if (index < 0 || models[index].maxPrice == maxPrice) return;

    final stale = models[index];
    models[index] = ModelDetail(
      name: stale.name,
      category: stale.category,
      maxPrice: maxPrice,
      imageUrl: stale.imageUrl,
      docId: stale.docId,
    );
  }

  /// Forgets [brand], so the next visit reads it again.
  static void invalidate(String brand) => _modelsByBrand.remove(_key(brand));

  static void clear() => _modelsByBrand.clear();
}
