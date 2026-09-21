import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../models/model_detail.dart';
import 'catalog_cache.dart';
import 'model_series.dart';

/// Every model in the catalogue, for the sell page's search.
///
/// The sell page used to search a list of fourteen model names typed into the
/// source file, show them with a generic phone icon, and — on tapping one —
/// open the grading wizard with an invented ₹50,000 base price, no brand and
/// no document id. A search result could therefore produce a quote built on a
/// number that came from nowhere.
///
/// Read with a collection-group query so the whole catalogue costs one round
/// trip rather than one per brand, and held for the process: Firestore has no
/// substring search, so the filtering happens here.
class ModelSearch {
  ModelSearch._();

  static FirebaseFirestore get _firestore =>
      FirebaseFirestore.instanceFor(app: Firebase.app('catalogApp'));

  /// Loads every model once. Subsequent calls return what was already read.
  static Future<List<ModelDetail>> load() async {
    final cached = CatalogCache.searchIndex;
    if (cached != null) return cached;

    final snapshot = await _firestore.collectionGroup('models').get();

    final models = <ModelDetail>[];
    for (final doc in snapshot.docs) {
      // models lives at brands/{brand}/models/{model}, so the grandparent
      // document is the brand. Without it a result cannot say where to read
      // its own price.
      final brand = doc.reference.parent.parent?.id;
      if (brand == null) continue;

      final data = doc.data();

      // Hidden models are kept out of search too. Without this a model the
      // admin had hidden would still be reachable by typing its name, which
      // is the one route into the sell flow that does not go via the brand
      // list. Only an explicit `hidden: true` hides it — see BrandDetailPage.
      if (data['hidden'] == true) continue;

      final name = (data['model'] ?? '').toString().trim();
      if (name.isEmpty) continue;

      final imageUrl = (data['image_url'] ?? '').toString().trim();

      models.add(ModelDetail(
        brand: brand,
        name: name,
        category: (data['release_year'] ?? '').toString(),
        series: deriveSeries(name, brand),
        maxPrice: _price(data['base_price']),
        imageUrl: imageUrl.isEmpty ? null : imageUrl,
        docId: doc.id,
      ));
    }

    models.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    CatalogCache.storeSearchIndex(models);
    return models;
  }

  /// Models whose name or brand contains [query].
  ///
  /// Matches the brand too, so "samsung" finds Samsung's phones even though
  /// the word is not in most of their model names.
  static List<ModelDetail> filter(List<ModelDetail> models, String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const [];

    return models
        .where((m) =>
            m.name.toLowerCase().contains(needle) ||
            m.brand.toLowerCase().contains(needle))
        .toList();
  }

  static int _price(Object? raw) {
    if (raw is num) return raw.toInt();
    return int.tryParse('$raw') ?? 0;
  }
}
