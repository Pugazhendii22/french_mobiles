// Tests for the Available now card.
//
// The card fills a fixed-size grid cell, so the main risk is a long model name
// or an extra spec line blowing its bounds. A RenderFlex overflow throws
// during layout and fails the test on its own, so pumping a card with hostile
// content IS the assertion — there is no separate expect for it.
//
// The harness reproduces a real cell: 178 x 280, which is what
// HomeProductGrid's delegate produces on a 400px screen.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/features/home/data/home_models.dart';
import 'package:french_mobiles/features/home/data/home_repository.dart';
import 'package:french_mobiles/features/home/widgets/home_product_card.dart';
import 'package:french_mobiles/shared/theme/app_colors.dart';
import 'package:french_mobiles/shared/widgets/app_network_image.dart';

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
          height: 280,
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
);

void main() {
  group('HomeProduct.discountPercent', () {
    test('computes against a higher original', () {
      expect(_rich.discountPercent, 36);
    });

    test('is zero without an original price', () {
      expect(
        const HomeProduct(
          id: 'a',
          categoryId: 'mobile',
          brand: 'Apple',
          title: 'Apple iPhone 13',
          imageUrl: '',
          price: '₹ 32000',
          salePriceValue: 32000,
        ).discountPercent,
        0,
      );
    });

    test('is zero when the original is not higher', () {
      expect(
        const HomeProduct(
          id: 'a',
          categoryId: 'mobile',
          brand: 'Apple',
          title: 'Apple iPhone 13',
          imageUrl: '',
          price: '₹ 32000',
          salePriceValue: 32000,
          originalPriceValue: 30000,
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

    testWidgets('shows storage and the discount', (t) async {
      await _pumpCard(t, _rich);
      expect(find.text('128GB'), findsOneWidget);
      expect(find.text('36% off'), findsOneWidget);
      expect(find.text('₹ 50000'), findsOneWidget);
    });

    testWidgets('draws no surface at all — photo and text sit on the page',
        (t) async {
      await _pumpCard(t, _rich);
      // Nothing paints AppColors.surface: no card behind the whole cell and
      // no panel behind the photo. The heart and grade label sit straight on
      // the page too, so any white box here means chrome has crept back in.
      //
      // AppColors.surfaceMuted is deliberately allowed — that is
      // AppNetworkImage's own placeholder for a missing photo, which is the
      // image slot rather than decoration around it.
      final surfaces = find
          .descendant(
            of: find.byType(HomeProductCard),
            matching: find.byType(DecoratedBox),
          )
          .evaluate()
          .map((e) => (e.widget as DecoratedBox).decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.color == AppColors.surface)
          .length;
      expect(surfaces, 0);
    });

    testWidgets('the grade is a plain label, not a filled pill', (t) async {
      await _pumpCard(t, _rich);
      expect(find.text('SUPERB'), findsOneWidget);
      final label = t.widget<Text>(find.text('SUPERB'));
      // Colour still carries the grade; the shape is gone.
      expect(label.style?.color, AppColors.success);
    });

    test('grade vocabularies map to tones', () {
      HomeProduct p(String c) => HomeProduct(
            id: 'a',
            categoryId: 'mobile',
            brand: '',
            title: '',
            imageUrl: '',
            price: '',
            condition: c,
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
          id: 'a',
          categoryId: 'mobile',
          brand: 'Apple',
          title: 'Apple iPhone 13',
          model: 'iPhone 13',
          imageUrl: '',
          price: '₹ 32000',
        ),
      );
      expect(find.textContaining('% off'), findsNothing);
      expect(find.text('iPhone 13'), findsOneWidget);
    });

    testWidgets('a very long name does not overflow the cell', (t) async {
      await _pumpCard(
        t,
        const HomeProduct(
          id: 'a',
          categoryId: 'mobile',
          brand: 'Samsung',
          title: 'Samsung Galaxy S24 Ultra Titanium Violet',
          model: 'Galaxy S24 Ultra Titanium Violet Special Edition',
          imageUrl: '',
          price: '₹ 128000',
          storage: '1TB',
          condition: 'Excellent',
          salePriceValue: 128000,
          originalPriceValue: 165000,
        ),
      );
    });

    testWidgets('falls back when there is no price', (t) async {
      await _pumpCard(
        t,
        const HomeProduct(
          id: 'a',
          categoryId: 'mobile',
          brand: '',
          title: 'Unknown',
          imageUrl: '',
          price: '',
        ),
      );
      expect(find.text('Price on request'), findsOneWidget);
    });

    testWidgets('renders on a narrow screen', (t) async {
      await _pumpCard(t, _rich, size: const Size(320, 640));
    });
  });

  group('the details fill the cell', () {
    HomeProduct withStorage(String storage) => HomeProduct(
          id: 'a',
          categoryId: 'mobile',
          brand: 'Apple',
          title: 'Apple iPhone 13',
          model: 'iPhone 13',
          imageUrl: '',
          price: '₹ 32000',
          storage: storage,
          salePriceValue: 32000,
        );

    // Two complaints, one cause each: a blank line held open where the
    // storage would go, and the column shrink-wrapping inside a fixed-height
    // cell so everything under the price was dead space.

    testWidgets('the price follows the name closely', (t) async {
      await _pumpCard(t, withStorage(''));

      final nameBottom = t.getBottomLeft(find.text('iPhone 13')).dy;
      final priceTop = t.getTopLeft(find.text('₹ 32000')).dy;

      // Two failed attempts at this: a blank line held the gap open, then
      // bottom-aligning the price moved the cell's spare height into the same
      // place. The photo absorbs it now, so the text is a block.
      expect(priceTop - nameBottom, lessThan(12),
          reason: 'anything more is the gap that keeps coming back');
    });

    testWidgets('a storage line does not open the gap either', (t) async {
      await _pumpCard(t, withStorage('128 GB'));

      final storageBottom = t.getBottomLeft(find.text('128 GB')).dy;
      final priceTop = t.getTopLeft(find.text('₹ 32000')).dy;

      expect(priceTop - storageBottom, lessThan(12));
    });

    testWidgets('the photo takes the space the text does not', (t) async {
      await _pumpCard(t, withStorage(''));
      final tall = t.getSize(find.byType(AppNetworkImage)).height;

      await _pumpCard(t, withStorage('128 GB'));
      final shorter = t.getSize(find.byType(AppNetworkImage)).height;

      expect(shorter, lessThan(tall),
          reason: 'an extra line of text comes out of the picture, not out '
              'of the space around the price');
    });

    testWidgets('the price sits at the bottom of the cell', (t) async {
      await _pumpCard(t, withStorage('128 GB'));

      final priceBottom = t.getBottomLeft(find.text('₹ 32000')).dy;
      expect(priceBottom, closeTo(280, 16),
          reason: 'anything higher leaves dead space under the price, which '
              'is what the cell looked like before');
    });

    testWidgets('prices line up whether or not storage is shown', (t) async {
      await _pumpCard(t, withStorage('128 GB'));
      final withSpec = t.getBottomLeft(find.text('₹ 32000')).dy;

      await _pumpCard(t, withStorage(''));
      final without = t.getBottomLeft(find.text('₹ 32000')).dy;

      expect(without, withSpec,
          reason: 'holding the line open with a space was how this used to '
              'be achieved; the spacer does it without the gap');
    });
  });

  group('legible on any photo', () {
    // Both sit directly on the picture, and a picture can be any colour. A
    // grey heart vanished on a pale screenshot; a green grade disappears on
    // grass. Neither gets a pill or a disc back — the shadow is what gives
    // them an edge.

    testWidgets('the grade carries a shadow', (t) async {
      await _pumpCard(t, _rich);

      final label = t.widget<Text>(find.text('SUPERB'));
      expect(label.style?.shadows, isNotEmpty,
          reason: 'without it the grade is unreadable over a light photo');
    });

    testWidgets('the heart carries a shadow', (t) async {
      await _pumpCard(t, _rich);

      final heart = t.widget<Icon>(
        find.byIcon(Icons.favorite_border_rounded),
      );
      expect(heart.shadows, isNotEmpty);
    });

    testWidgets('an unsaved heart is filled light, not grey', (t) async {
      await _pumpCard(t, _rich);

      final heart = t.widget<Icon>(
        find.byIcon(Icons.favorite_border_rounded),
      );
      expect(heart.color, AppColors.onOverlay,
          reason: 'grey on a pale photo was the half of this that '
              'disappeared entirely');
    });
  });
}
