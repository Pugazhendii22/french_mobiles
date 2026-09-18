// These three pages read as stacks of containers, and this is why.
//
// AppSurface's `raised` level deliberately has no border — its own comment
// says adding one as well "is what made everything read as the same flat
// box". OrderRow and WishlistRow predated the surface system and hand-rolled
// a Container with surface colour, border AND shadow, which is that mistake
// exactly, once per row, down the whole list.
//
// The rows now sit inside one enclosure (orders) or directly on the page
// (saved), so neither should paint chrome of its own.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/firebase/wishlist_service.dart';
import 'package:french_mobiles/models/order_status.dart';
import 'package:french_mobiles/profile/orders_page.dart';
import 'package:french_mobiles/profile/wishlist_page.dart';
import 'package:french_mobiles/shared/motion/motion.dart';
import 'package:french_mobiles/shared/theme/app_colors.dart';
import 'package:french_mobiles/shared/theme/app_theme.dart';
import 'package:french_mobiles/shared/widgets/app_network_image.dart';
import 'package:french_mobiles/shared/widgets/widgets.dart';

/// Every BoxDecoration the row itself paints.
///
/// AppNetworkImage's own placeholder is excluded: that is the image slot
/// standing in for a missing photo, not chrome the row draws around its
/// content — the same exception the home product card makes.
List<BoxDecoration> _decorationsIn(WidgetTester t, Finder of) {
  final insideImage = find
      .descendant(of: find.byType(AppNetworkImage), matching: find.byType(DecoratedBox))
      .evaluate()
      .toSet();

  return t
      .widgetList<DecoratedBox>(
        find.descendant(of: of, matching: find.byType(DecoratedBox)),
      )
      .where((d) => !insideImage.any((e) => e.widget == d))
      .map((d) => d.decoration)
      .whereType<BoxDecoration>()
      .toList();
}

Future<void> _pump(WidgetTester t, Widget widget) async {
  t.view.physicalSize = const Size(400, 800);
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

void main() {
  testWidgets('an order row carries no border-and-shadow box', (t) async {
    await _pump(t, _order);

    final offenders = _decorationsIn(t, find.byType(OrderRow))
        .where((d) => d.border != null && d.boxShadow != null);

    expect(offenders, isEmpty,
        reason: 'the group around the list supplies the enclosure; a box per '
            'row on top of it is the stack-of-containers look');
  });

  testWidgets('a saved row carries no box at all', (t) async {
    await _pump(t, _wishlist);

    final filled = _decorationsIn(t, find.byType(WishlistRow))
        .where((d) => d.color != null || d.boxShadow != null);

    expect(filled, isEmpty,
        reason: 'saved items are products, and products sit on the page here '
            'the same way the home grid decided they should');
  });

  testWidgets('the saved row no longer panels its photo', (t) async {
    await _pump(t, _wishlist);

    final panels = _decorationsIn(t, find.byType(WishlistRow))
        .where((d) => d.color == AppColors.surfaceMuted);

    expect(panels, isEmpty,
        reason: 'a panel behind a product photo frames it instead of showing '
            'it — the same conclusion the home card reached');
  });

  testWidgets('an order row still reads as tappable', (t) async {
    await _pump(t, _order);

    // Losing the lift means the affordance has to come from somewhere: the
    // chevron, and press feedback from AppPressable.
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    expect(find.byType(AppPressable), findsWidgets);
  });

  testWidgets('an order row is shaped like a saved row', (t) async {
    // Asked for explicitly: the same list treatment on both tabs. Worth
    // pinning, because the two have drifted apart twice already.
    await _pump(t, _order);
    final orderPhoto = t.getSize(find.byType(AppNetworkImage)).height;

    await _pump(t, _wishlist);
    final savedPhoto = t.getSize(find.byType(AppNetworkImage)).height;

    expect(orderPhoto, savedPhoto,
        reason: 'the photo is the most visible difference between two list '
            'rows, so it is the first thing to keep in step');
  });

  testWidgets('both lists show their figure in the brand green', (t) async {
    // The green that means money in this app: the same one the quote
    // breakdown gives "You receive".
    await _pump(t, _order);
    final orderPrice = t.widget<Text>(find.textContaining('42000'));
    expect(orderPrice.style?.color, AppColors.onPrimarySoft);

    await _pump(t, _wishlist);
    final savedPrice = t.widget<Text>(find.text('30000'));
    expect(savedPrice.style?.color, AppColors.onPrimarySoft);
  });

  testWidgets('the order row keeps its progress strip', (t) async {
    await _pump(t, _order);

    expect(find.text(OrderStage.placed.label), findsOneWidget,
        reason: 'the tracking section stays, which is the half of this that '
            'was explicitly to be left alone');
  });
}

void _noop() {}
