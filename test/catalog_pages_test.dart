// Layout smoke tests for the catalog flow.
//
// brand_detail and variant_selection reach Firestore in initState, but both
// wrap that call in try/catch, so with no Firebase configured they settle into
// their error/empty state — which is exactly the path worth pumping here.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
            'ram': '4GB',
            'storage': '128GB',
          },
        ),
      );
      expect(find.text('Apple iPhone 13'), findsOneWidget);
      expect(find.text('36% OFF'), findsOneWidget);
    });

    testWidgets('builds with a near-empty document', (t) async {
      await _boot(t, const InventoryDetailPlaceholder(data: {}));
    });
  });
}
