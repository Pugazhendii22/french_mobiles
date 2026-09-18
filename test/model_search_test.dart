// Searching the real catalogue instead of a list typed into the source.
//
// The sell page used to search fourteen hardcoded model names, show them
// beside a generic phone icon, and — on tapping one — open the grading wizard
// with brandName '', modelDocId '' and a flat ₹50,000 base price. Every
// searched phone was therefore graded against the same invented figure, and
// the seller had no way to tell the match was even the right phone.
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/models/model_detail.dart';
import 'package:french_mobiles/shared/services/catalog_cache.dart';
import 'package:french_mobiles/shared/services/model_search.dart';

ModelDetail _model(String brand, String name) => ModelDetail(
      brand: brand,
      name: name,
      category: '2024',
      maxPrice: 40000,
      imageUrl: 'https://example.test/$name.png',
      docId: name.toLowerCase().replaceAll(' ', '-'),
    );

final _catalogue = [
  _model('apple', 'iPhone 13'),
  _model('apple', 'iPhone 15 Pro Max'),
  _model('samsung', 'Galaxy S24 Ultra'),
  _model('samsung', 'Galaxy M34'),
  _model('oneplus', 'OnePlus 11 5G'),
];

void main() {
  setUp(CatalogCache.clear);

  group('filtering', () {
    test('an empty query matches nothing rather than everything', () {
      expect(ModelSearch.filter(_catalogue, ''), isEmpty,
          reason: 'the results list is hidden until something is typed');
      expect(ModelSearch.filter(_catalogue, '   '), isEmpty);
    });

    test('matches part of a model name', () {
      final found = ModelSearch.filter(_catalogue, 'iphone');

      expect(found.map((m) => m.name),
          containsAll(['iPhone 13', 'iPhone 15 Pro Max']));
      expect(found, hasLength(2));
    });

    test('matches the brand, which is usually not in the model name', () {
      final found = ModelSearch.filter(_catalogue, 'samsung');

      expect(found.map((m) => m.name),
          containsAll(['Galaxy S24 Ultra', 'Galaxy M34']),
          reason: 'searching a brand should find its phones even though '
              '"Samsung" appears in none of their model names');
    });

    test('is case insensitive both ways', () {
      expect(ModelSearch.filter(_catalogue, 'IPHONE'), hasLength(2));
      expect(ModelSearch.filter(_catalogue, 'GaLaXy'), hasLength(2));
    });

    test('a query that matches nothing returns nothing', () {
      expect(ModelSearch.filter(_catalogue, 'nokia'), isEmpty);
    });

    test('every result can say where its price lives', () {
      for (final match in ModelSearch.filter(_catalogue, 'a')) {
        expect(match.brand, isNotEmpty,
            reason: 'without a brand the next screen cannot read the real '
                'price, which is how the flat 50000 happened');
        expect(match.docId, isNotNull);
      }
    });

    test('results carry an image, which is what identifies the phone', () {
      final found = ModelSearch.filter(_catalogue, 'iphone');
      expect(found.every((m) => m.imageUrl != null), isTrue);
    });
  });

  group('the index is read once', () {
    test('a cached index is returned without touching Firestore', () async {
      CatalogCache.storeSearchIndex(_catalogue);

      // No Firebase here: reaching the network would throw rather than
      // return, so completing at all proves the cache was used.
      expect(await ModelSearch.load(), hasLength(_catalogue.length));
    });

    test('clearing forces it to be read again', () {
      CatalogCache.storeSearchIndex(_catalogue);
      expect(CatalogCache.searchIndex, isNotNull);

      CatalogCache.clear();
      expect(CatalogCache.searchIndex, isNull);
    });

    test('the index hands out a copy', () {
      CatalogCache.storeSearchIndex(_catalogue);
      CatalogCache.searchIndex!.clear();

      expect(CatalogCache.searchIndex, hasLength(_catalogue.length));
    });
  });
}
