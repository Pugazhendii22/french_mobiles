// Skeletons have to be the height of what replaces them.
//
// A list of three orders whose skeleton was 15px short shifted by 45px the
// instant the data landed — the exact jump a skeleton exists to prevent, and
// invisible to every other kind of test.
//
// The rows lost their individual cards when these pages moved onto the
// surface system, so the heights moved with them.
//
// These measure the real row and its skeleton side by side, so a change to
// one that is not matched in the other fails here rather than shipping.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/firebase/wishlist_service.dart';
import 'package:french_mobiles/models/order_status.dart';
import 'package:french_mobiles/profile/orders_page.dart';
import 'package:french_mobiles/profile/wishlist_page.dart';
import 'package:french_mobiles/shared/theme/app_theme.dart';
import 'package:french_mobiles/shared/widgets/widgets.dart';

/// Renders [widget] in a list's content width and returns its height.
Future<double> _heightOf(
  WidgetTester t,
  Widget widget, {
  double screenWidth = 400,
}) async {
  t.view.physicalSize = Size(screenWidth, 900);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);

  await t.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter),
        child: Column(mainAxisSize: MainAxisSize.min, children: [widget]),
      ),
    ),
  ));
  await t.pump();

  return t.getSize(find.byWidget(widget)).height;
}

const _order = OrderRow(
  modelName: 'iPhone 13 Pro Max',
  storage: '256GB',
  imageUrl: '',
  payout: 42000,
  date: '12 Sep 2026',
  stage: OrderStage.placed,
  onTap: _noop,
);

const _wishlist = WishlistRow(
  item: WishlistItem(
    productId: 'p1',
    brand: 'Apple',
    title: 'iPhone 13',
    imageUrl: '',
    price: '30000',
    categoryId: 'mobile',
  ),
  onTap: _noop,
  onRemove: _noop,
);

const _variant = AppSelectableTile(
  title: '256GB',
  selected: false,
  trailingLabel: 'Up to',
  trailingText: '₹ 42000',
);

void main() {
  for (final width in const [400.0, 320.0]) {
    final label = '${width.toInt()}px';

    testWidgets('an order skeleton is the height of an order row at $label',
        (t) async {
      final real = await _heightOf(t, _order, screenWidth: width);
      final skeleton = await _heightOf(
        t,
        const OrderRowSkeleton(),
        screenWidth: width,
      );

      expect(skeleton, real,
          reason: 'three rows of a 15px error is a 45px jump');
    });

    testWidgets('the wishlist skeleton is the height of its row at $label',
        (t) async {
      final real = await _heightOf(t, _wishlist, screenWidth: width);
      // The row is now vertical padding either side of a 64px thumbnail,
      // with no card around it.
      expect(real, 64 + 2 * AppSpacing.md,
          reason: 'wishlist_page pins its skeleton to this height');
    });

    testWidgets('the variant skeleton is the height of its tile at $label',
        (t) async {
      final real = await _heightOf(t, _variant, screenWidth: width);
      expect(real, 70,
          reason: 'variant_selection_page pins its skeleton to this height');
    });
  }
}

void _noop() {}
