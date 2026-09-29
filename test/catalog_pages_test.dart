// Layout smoke tests for the catalog flow.
//
// brand_detail and variant_selection reach Firestore in initState, but both
// wrap that call in try/catch, so with no Firebase configured they settle into
// their error/empty state — which is exactly the path worth pumping here.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/shared/motion/motion.dart';
import 'package:french_mobiles/screens/brand_detail_page.dart';
import 'package:french_mobiles/screens/brand_list_page.dart';
import 'package:french_mobiles/screens/inventory_detail_page.dart';
import 'package:french_mobiles/screens/variant_selection_page.dart';

Future<void> _boot(WidgetTester tester, Widget page, {Size? size}) async {
  tester.view.physicalSize = size ?? const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  group('BrandListPage', () {
    testWidgets('builds', (t) async {
      await _boot(t, const BrandListPage());
      expect(find.text('All brands'), findsOneWidget);
    });

    testWidgets('builds narrow', (t) async {
      await _boot(t, const BrandListPage(), size: const Size(320, 640));
    });

    testWidgets('empty search shows empty state', (t) async {
      await _boot(t, const BrandListPage());
      await t.enterText(find.byType(TextField), 'zzzzz');
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('No brands found'), findsOneWidget);
    });
  });

  group('BrandDetailPage', () {
    testWidgets('builds and settles into empty state', (t) async {
      await _boot(
        t,
        const BrandDetailPage(brandName: 'Apple', themeColor: Colors.black),
      );
      expect(find.text('Apple'), findsOneWidget);
    });

    testWidgets('builds narrow', (t) async {
      await _boot(
        t,
        const BrandDetailPage(brandName: 'Apple', themeColor: Colors.black),
        size: const Size(320, 640),
      );
    });
  });

  group('VariantSelectionPage', () {
    testWidgets('builds and settles into empty state', (t) async {
      await _boot(
        t,
        const VariantSelectionPage(
          brandName: 'Apple',
          modelDocId: 'x',
          modelName: 'iPhone 13',
        ),
      );
      expect(find.text('Select storage'), findsOneWidget);
    });
  });

  group('InventoryDetailPlaceholder', () {
    testWidgets('builds with a full document', (t) async {
      await _boot(
        t,
        const InventoryDetailPlaceholder(
          documentId: 'abc',
          data: {
            'brand': 'Apple',
            'model': 'iPhone 13',
            'description': 'Good condition.',
            'salePrice': 32000,
            'originalPrice': 50000,
            'condition': 'Superb',
            'ram': '4GB',
            'storage': '128GB',
          },
        ),
      );
      expect(find.text('Apple iPhone 13'), findsOneWidget);
      expect(find.text('36% off'), findsOneWidget);
    });

    testWidgets('shows the grade, which decides a used purchase', (t) async {
      await _boot(
        t,
        const InventoryDetailPlaceholder(
          data: {
            'brand': 'Apple',
            'model': 'iPhone 13',
            'salePrice': 32000,
            'condition': 'Superb',
          },
        ),
      );

      expect(find.text('SUPERB'), findsOneWidget,
          reason: 'the grid shows a grade and this page did not, so a buyer '
              'had to go back to find the most important fact about it');
    });

    testWidgets('does not print the price twice', (t) async {
      await _boot(
        t,
        const InventoryDetailPlaceholder(
          data: {
            'brand': 'Apple',
            'model': 'iPhone 13',
            'salePrice': 32000,
          },
        ),
      );

      // The bottom bar carries the price and follows the page; repeating it
      // under the photo said the same thing twice and pushed the rest down.
      expect(find.text('₹ 32000'), findsOneWidget,
          reason: 'once, in the bottom bar — not again under the photo');
      expect(
        find.descendant(
          of: find.byType(AppAnimatedCount),
          matching: find.text('₹ 32000'),
        ),
        findsOneWidget,
        reason: 'and the one that remains is the bar\'s',
      );
    });

    testWidgets('a listing with no photo still lays out', (t) async {
      await _boot(
        t,
        const InventoryDetailPlaceholder(
          data: {'brand': 'Apple', 'model': 'iPhone 13', 'salePrice': 1},
        ),
      );

      // It used to point at an outside placeholder service, which is a broken
      // image the moment that host is unreachable.
      expect(t.takeException(), isNull);
      // Twice is correct: the headline and the MODEL row of the spec table.
      expect(find.text('iPhone 13'), findsWidgets);
    });

    testWidgets('builds with a near-empty document', (t) async {
      await _boot(t, const InventoryDetailPlaceholder(data: {}));
    });
  });
}
