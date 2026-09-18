// Caching the browsing list without ever caching a quote.
//
// The two numbers are different things. A model tile's "up to ₹40,000" exists
// to help someone choose what to tap; the number a quote is built from is
// read fresh from that model's variants the moment they do. So the list can
// be cached hard — its figure never becomes a commitment — and when the fresh
// read disagrees, the cache is corrected rather than left lying.
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/models/model_detail.dart';
import 'package:french_mobiles/shared/services/catalog_cache.dart';

ModelDetail _model(String docId, int maxPrice) => ModelDetail(
      name: 'Model $docId',
      category: '2024',
      maxPrice: maxPrice,
      docId: docId,
    );

void main() {
  setUp(CatalogCache.clear);

  test('a brand that has never been read is a miss', () {
    expect(CatalogCache.models('Apple'), isNull,
        reason: 'null is what tells the page to go and fetch');
  });

  test('a stored brand is served back', () {
    CatalogCache.storeModels('Apple', [_model('m1', 40000)]);

    expect(CatalogCache.models('Apple'), hasLength(1));
    expect(CatalogCache.models('Apple')!.first.maxPrice, 40000);
  });

  test('casing cannot split the cache', () {
    CatalogCache.storeModels('Apple', [_model('m1', 40000)]);

    expect(CatalogCache.models('apple'), isNotNull);
    expect(CatalogCache.models('APPLE'), isNotNull,
        reason: 'the queries lowercase the brand, so the cache must too');
  });

  test('the caller gets a copy it can sort without disturbing anyone', () {
    CatalogCache.storeModels('Apple', [_model('m1', 1), _model('m2', 2)]);

    CatalogCache.models('Apple')!.clear();

    expect(CatalogCache.models('Apple'), hasLength(2),
        reason: 'brand detail filters its own list in place');
  });

  group('correcting a headline against the real price', () {
    setUp(() {
      CatalogCache.clear();
      CatalogCache.storeModels('Apple', [
        _model('m1', 40000),
        _model('m2', 30000),
      ]);
    });

    test('a changed price replaces the stored one', () {
      CatalogCache.updateHeadlinePrice('Apple', 'm1', 38000);

      final models = CatalogCache.models('Apple')!;
      expect(models.firstWhere((m) => m.docId == 'm1').maxPrice, 38000);
      expect(models.firstWhere((m) => m.docId == 'm2').maxPrice, 30000,
          reason: 'only the model that was opened was verified');
    });

    test('the rest of the model survives the correction', () {
      CatalogCache.updateHeadlinePrice('Apple', 'm1', 38000);

      final updated =
          CatalogCache.models('Apple')!.firstWhere((m) => m.docId == 'm1');
      expect(updated.name, 'Model m1');
      expect(updated.category, '2024');
      expect(updated.docId, 'm1');
    });

    test('an unchanged price is left alone', () {
      CatalogCache.updateHeadlinePrice('Apple', 'm1', 40000);
      expect(CatalogCache.models('Apple')!.first.maxPrice, 40000);
    });

    test('correcting an uncached brand does nothing rather than throwing', () {
      CatalogCache.updateHeadlinePrice('Samsung', 'm9', 1000);
      expect(CatalogCache.models('Samsung'), isNull);
    });

    test('correcting an unknown model does nothing', () {
      CatalogCache.updateHeadlinePrice('Apple', 'nope', 1);
      expect(CatalogCache.models('Apple'), hasLength(2));
    });
  });

  test('a brand can be forgotten so the next visit reads it again', () {
    CatalogCache.storeModels('Apple', [_model('m1', 1)]);
    CatalogCache.invalidate('Apple');

    expect(CatalogCache.models('Apple'), isNull);
  });

  test('clearing forgets every brand', () {
    CatalogCache.storeModels('Apple', [_model('m1', 1)]);
    CatalogCache.storeModels('Samsung', [_model('m2', 2)]);

    CatalogCache.clear();

    expect(CatalogCache.models('Apple'), isNull);
    expect(CatalogCache.models('Samsung'), isNull);
  });
}
