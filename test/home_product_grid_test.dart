// Overflow and layout tests for the Available now grid.
//
// A RenderFlex overflow throws during layout and fails the test on its own,
// so pumping a grid full of maximal content IS the assertion. The narrow-width
// cases matter most: cell height is pinned with mainAxisExtent precisely so a
// 320px screen does not shrink the cell below what the card's text needs.
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/features/home/data/home_models.dart';
import 'package:french_mobiles/features/home/data/home_repository.dart';
import 'package:french_mobiles/features/home/widgets/home_product_card.dart';
import 'package:french_mobiles/shared/theme/app_colors.dart';
import 'package:french_mobiles/features/home/widgets/home_product_grid.dart';
import 'package:french_mobiles/shared/widgets/app_shimmer.dart';

class _FakeRepository extends HomeRepository {
  const _FakeRepository();

  @override
  Stream<User?> watchAuthState() => Stream<User?>.value(null);

  @override
  User? get currentUser => null;
}

/// Every optional field present and a name long enough to wrap to two lines —
/// the tallest card the grid has to hold.
HomeProduct _maximal(int i) => HomeProduct(
      id: '$i',
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
    );

Future<void> _pumpGrid(
  WidgetTester t, {
  required int count,
  Size size = const Size(400, 800),
  Future<List<HomeProduct>>? future,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);

  await t.pumpWidget(MaterialApp(
    home: Scaffold(
      body: CustomScrollView(
        slivers: [
          HomeProductGrid(
            future: future ??
                Future<List<HomeProduct>>.value(
                  List.generate(count, _maximal),
                ),
            repository: const _FakeRepository(),
            onProductTap: (_) {},
            onWishlistTap: (_) {},
            wishlistStream: (_) => null,
            onRetry: () {},
            emptyTitle: 'No devices available',
          ),
        ],
      ),
    ),
  ));
  await t.pump(const Duration(milliseconds: 600));
}

/// Every visible rule drawn by the grid cells.
List<BoxDecoration> _cellDecorations(WidgetTester t) {
  return find
      .descendant(
        of: find.byType(HomeProductGrid),
        matching: find.byType(Container),
      )
      .evaluate()
      .map((e) => (e.widget as Container).decoration)
      .whereType<BoxDecoration>()
      .where((d) => d.border != null)
      .toList();
}

void main() {
  testWidgets('lays out two columns', (t) async {
    await _pumpGrid(t, count: 4);
    final cards = find.byType(Card).evaluate();
    expect(cards, isEmpty); // the card is a Container, not a Card

    // Two cells share a row: the first two have the same vertical offset.
    final first = t.getTopLeft(find
        .text('Galaxy S24 Ultra Titanium Violet '
            'Special Edition')
        .at(0));
    final second = t.getTopLeft(find
        .text('Galaxy S24 Ultra Titanium Violet '
            'Special Edition')
        .at(1));
    expect(first.dy, second.dy, reason: 'first two cards should share a row');
    expect(first.dx, lessThan(second.dx));
  });

  testWidgets('maximal content does not overflow at 400px', (t) async {
    await _pumpGrid(t, count: 6);
  });

  testWidgets('maximal content does not overflow at 320px', (t) async {
    await _pumpGrid(t, count: 6, size: const Size(320, 640));
  });

  testWidgets('maximal content does not overflow at 280px', (t) async {
    await _pumpGrid(t, count: 4, size: const Size(280, 640));
  });

  testWidgets('an odd count leaves the last card its own row, unstretched',
      (t) async {
    await _pumpGrid(t, count: 5);
    final cards = find.byType(HomeProductCard);
    expect(cards, findsNWidgets(5));

    // The lone fifth cell must be the same size as a paired one, not
    // stretched across the row.
    final paired = t.getSize(cards.at(0));
    final lone = t.getSize(cards.at(4));
    expect(lone, paired);

    // And it starts a new row, aligned to the left column.
    expect(t.getTopLeft(cards.at(4)).dx, t.getTopLeft(cards.at(0)).dx);
    expect(t.getTopLeft(cards.at(4)).dy,
        greaterThan(t.getTopLeft(cards.at(2)).dy));
  });

  testWidgets('shows skeletons while loading, then the cards', (t) async {
    // A Completer rather than a delayed Future: AppShimmer repeats forever, so
    // leaving the future pending at teardown trips the pending-timer check.
    final completer = Completer<List<HomeProduct>>();
    await _pumpGrid(t, count: 0, future: completer.future);

    expect(find.byType(AppShimmer), findsWidgets,
        reason: 'skeletons should fill the grid while loading');

    completer.complete(List.generate(2, _maximal));
    await t.pumpAndSettle();

    expect(find.byType(AppShimmer), findsNothing);
    expect(find.text('SAMSUNG'), findsNWidgets(2));
  });

  group('dividers', () {
    testWidgets('left column carries the vertical rule, right column does not',
        (t) async {
      await _pumpGrid(t, count: 4);

      final borders =
          _cellDecorations(t).map((d) => d.border! as Border).toList();
      expect(borders.length, 4);

      // Cells alternate left, right, left, right.
      expect(borders[0].right.color, AppColors.border,
          reason: 'left column should draw the vertical rule');
      expect(borders[1].right.color, AppColors.transparent,
          reason: 'right column must not draw a rule at the screen edge');
    });

    testWidgets('every row but the last carries a horizontal rule', (t) async {
      await _pumpGrid(t, count: 4);

      final borders =
          _cellDecorations(t).map((d) => d.border! as Border).toList();

      // Row 0 (indices 0,1) has a rule beneath it; row 1 (2,3) is last.
      expect(borders[0].bottom.color, AppColors.border);
      expect(borders[1].bottom.color, AppColors.border);
      expect(borders[2].bottom.color, AppColors.transparent);
      expect(borders[3].bottom.color, AppColors.transparent);
    });

    testWidgets('rule thickness is uniform, never doubled', (t) async {
      await _pumpGrid(t, count: 6);

      for (final decoration in _cellDecorations(t)) {
        final border = decoration.border! as Border;
        expect(border.right.width, 1);
        expect(border.bottom.width, 1);
        // A left or top side would meet the neighbour's right or bottom and
        // paint a 2px line in the gutter.
        expect(border.left.style, BorderStyle.none);
        expect(border.top.style, BorderStyle.none);
      }
    });

    testWidgets('both columns get identical card widths', (t) async {
      await _pumpGrid(t, count: 4);
      final cards = find.byType(HomeProductCard);
      expect(t.getSize(cards.at(0)).width, t.getSize(cards.at(1)).width,
          reason: 'a transparent border side still consumes layout space, so '
              'both columns must reserve one');
    });

    testWidgets('an odd count leaves the lone last cell without a rule',
        (t) async {
      await _pumpGrid(t, count: 5);
      final borders =
          _cellDecorations(t).map((d) => d.border! as Border).toList();
      expect(borders.last.bottom.color, AppColors.transparent);
    });
  });

  testWidgets('empty state renders', (t) async {
    await _pumpGrid(t, count: 0);
    expect(find.text('No devices available'), findsOneWidget);
  });
}
