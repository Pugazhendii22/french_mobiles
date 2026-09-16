// Tests for the Available now card.
//
// The card fills a fixed-size grid cell, so the main risk is a long model name
// or an extra spec line blowing its bounds. A RenderFlex overflow throws
// during layout and fails the test on its own, so pumping a card with hostile
// content IS the assertion — there is no separate expect for it.
//
// The harness reproduces a real cell: 178 x 302, which is what
// HomeProductGrid's delegate produces on a 400px screen.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/features/home/data/home_models.dart';
import 'package:french_mobiles/features/home/data/home_repository.dart';
import 'package:french_mobiles/features/home/widgets/home_product_card.dart';

/// Stands in for the real repository so the card can render without Firebase.
/// Signed out is the interesting case: the wishlist heart still has to draw.
class _FakeRepository extends HomeRepository {
  const _FakeRepository();

  @override
  Stream<User?> watchAuthState() => Stream<User?>.value(null);

  @override
  User? get currentUser => null;
}

Future<void> _pumpCard(
  WidgetTester t,
  HomeProduct product, {
  Size size = const Size(400, 800),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);

  await t.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 178,
          height: 302,
          child: HomeProductCard(
            product: product,
            repository: const _FakeRepository(),
            onTap: () {},
            onWishlistTap: () {},
            wishlistStream: (_) => null,
          ),
        ),
      ),
    ),
  ));
  await t.pump(const Duration(milliseconds: 400));
}

const _rich = HomeProduct(
  id: 'a',
  categoryId: 'mobile',
  brand: 'Apple',
  title: 'Apple iPhone 13',
  model: 'iPhone 13',
  imageUrl: '',
  price: '₹ 32000',
  storage: '128GB',
  condition: 'Superb',
  salePriceValue: 32000,
  originalPriceValue: 50000,
  warrantyMonths: 6,
);

void main() {
  group('HomeProduct.discountPercent', () {
    test('computes against a higher original', () {
      expect(_rich.discountPercent, 36);
    });

    test('is zero without an original price', () {
      expect(
        const HomeProduct(
          id: 'a', categoryId: 'mobile', brand: 'Apple',
          title: 'Apple iPhone 13', imageUrl: '', price: '₹ 32000',
          salePriceValue: 32000,
        ).discountPercent,
        0,
      );
    });

    test('is zero when the original is not higher', () {
      expect(
        const HomeProduct(
          id: 'a', categoryId: 'mobile', brand: 'Apple',
          title: 'Apple iPhone 13', imageUrl: '', price: '₹ 32000',
          salePriceValue: 32000, originalPriceValue: 30000,
        ).discountPercent,
        0,
      );
    });
  });

  group('card', () {
    testWidgets('shows the brand once, not twice', (t) async {
      await _pumpCard(t, _rich);
      // "APPLE" as the overline, "iPhone 13" as the name — never
      // "Apple iPhone 13", which is what HomeProduct.title holds.
      expect(find.text('APPLE'), findsOneWidget);
      expect(find.text('iPhone 13'), findsOneWidget);
      expect(find.text('Apple iPhone 13'), findsNothing);
    });

    testWidgets('leads with the condition grade', (t) async {
      await _pumpCard(t, _rich);
      expect(find.text('SUPERB'), findsOneWidget);
    });

    testWidgets('shows storage, discount and warranty', (t) async {
      await _pumpCard(t, _rich);
      expect(find.text('128GB'), findsOneWidget);
      expect(find.text('36% off'), findsOneWidget);
      expect(find.text('₹ 50000'), findsOneWidget);
      expect(find.text('6-month warranty'), findsOneWidget);
    });

    testWidgets('makes no warranty claim when the document has none',
        (t) async {
      await _pumpCard(
        t,
        const HomeProduct(
          id: 'a', categoryId: 'mobile', brand: 'Apple',
          title: 'Apple iPhone 13', model: 'iPhone 13',
          imageUrl: '', price: '₹ 32000', condition: 'Good',
        ),
      );
      expect(find.textContaining('warranty'), findsNothing);
    });

    test('grade vocabularies map to tones', () {
      HomeProduct p(String c) => HomeProduct(
            id: 'a', categoryId: 'mobile', brand: '', title: '',
            imageUrl: '', price: '', condition: c,
          );
      // Cashify
      expect(p('Superb').conditionTone, ConditionTone.top);
      expect(p('Good').conditionTone, ConditionTone.mid);
      expect(p('Fair').conditionTone, ConditionTone.low);
      // Back Market
      expect(p('Premium').conditionTone, ConditionTone.top);
      expect(p('Excellent').conditionTone, ConditionTone.top);
      // letter grades
      expect(p('A').conditionTone, ConditionTone.top);
      expect(p('C').conditionTone, ConditionTone.low);
      // unrecognised falls back rather than guessing
      expect(p('Mint').conditionTone, ConditionTone.unknown);
      expect(p('').conditionTone, ConditionTone.unknown);
    });

    testWidgets('omits optional fields rather than rendering blanks',
        (t) async {
      await _pumpCard(
        t,
        const HomeProduct(
          id: 'a', categoryId: 'mobile', brand: 'Apple',
          title: 'Apple iPhone 13', model: 'iPhone 13',
          imageUrl: '', price: '₹ 32000',
        ),
      );
      expect(find.textContaining('% off'), findsNothing);
      expect(find.text('iPhone 13'), findsOneWidget);
    });

    testWidgets('a very long name does not overflow the cell', (t) async {
      await _pumpCard(
        t,
        const HomeProduct(
          id: 'a', categoryId: 'mobile', brand: 'Samsung',
          title: 'Samsung Galaxy S24 Ultra Titanium Violet',
          model: 'Galaxy S24 Ultra Titanium Violet Special Edition',
          imageUrl: '', price: '₹ 128000', storage: '1TB',
          condition: 'Excellent', warrantyMonths: 12,
          salePriceValue: 128000, originalPriceValue: 165000,
        ),
      );
    });

    testWidgets('falls back when there is no price', (t) async {
      await _pumpCard(
        t,
        const HomeProduct(
          id: 'a', categoryId: 'mobile', brand: '', title: 'Unknown',
          imageUrl: '', price: '',
        ),
      );
      expect(find.text('Price on request'), findsOneWidget);
    });

    testWidgets('renders on a narrow screen', (t) async {
      await _pumpCard(t, _rich, size: const Size(320, 640));
    });
  });
}
