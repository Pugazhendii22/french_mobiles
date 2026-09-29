// The loading state of the two card grids.
//
// Both used to fill each cell with one solid grey block, which promises a
// shape and then delivers a different one — the page still jumps when the
// data lands, which is the whole thing a skeleton exists to prevent.
//
// A card-shaped skeleton has fixed heights inside a cell whose height comes
// from an aspect ratio, so the risk it introduces is overflow on a narrow
// screen. Both are pumped at the exact cell sizes their grids produce.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/screens/brand_detail_page.dart';
import 'package:french_mobiles/screens/device_evaluation_wizard.dart';
import 'package:french_mobiles/shared/theme/app_theme.dart';
import 'package:french_mobiles/shared/widgets/app_shimmer.dart';

/// The cell a two-column grid produces on a screen [width] wide.
///
/// Mirrors both grids: a screen-gutter each side, one gap between columns,
/// and a height set by the aspect ratio.
Size _cell(double width, double aspectRatio) {
  final cellWidth = (width - 2 * AppSpacing.screenGutter - AppSpacing.md) / 2;
  return Size(cellWidth, cellWidth / aspectRatio);
}

Future<void> _pumpInCell(WidgetTester t, Widget skeleton, Size cell) async {
  t.view.physicalSize = const Size(400, 800);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);

  await t.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: cell.width,
          height: cell.height,
          child: skeleton,
        ),
      ),
    ),
  ));
  await t.pump();
}

void main() {
  for (final screen in const [400.0, 320.0]) {
    final label = '${screen.toInt()}px';

    testWidgets('the brand model skeleton fits its cell at $label', (t) async {
      // BrandDetailPage's grid: childAspectRatio 0.74.
      await _pumpInCell(t, const ModelCardSkeleton(), _cell(screen, 0.74));

      expect(t.takeException(), isNull,
          reason: 'a skeleton taller than its cell overflows, and an '
              'overflow is a worse first impression than a spinner');
    });

    testWidgets('the wizard option skeleton fits its cell at $label',
        (t) async {
      // The wizard's grid: childAspectRatio 0.95.
      await _pumpInCell(t, const OptionCardSkeleton(), _cell(screen, 0.95));

      expect(t.takeException(), isNull);
    });
  }

  testWidgets('the brand skeleton mirrors the card, not one grey block',
      (t) async {
    await _pumpInCell(t, const ModelCardSkeleton(), _cell(400, 0.74));

    // Photo panel, two title lines, an "Up to" label, a price.
    expect(find.byType(AppShimmer), findsNWidgets(5),
        reason: 'one block per element of the card it stands in for');
  });

  testWidgets('the wizard skeleton mirrors its option card', (t) async {
    await _pumpInCell(t, const OptionCardSkeleton(), _cell(400, 0.95));

    // Icon, title, subtitle.
    expect(find.byType(AppShimmer), findsNWidgets(3));
  });
}
