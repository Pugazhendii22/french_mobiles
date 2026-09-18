// The pinned search header, on home and on sell.
//
// This is the widget that once shipped a white screen. A pinned header takes
// its paintExtent from the child's real height but its layoutExtent from
// maxExtent, and Flutter asserts if the two disagree by a single pixel. That
// assertion fires inside the viewport's layout pass, so the screen renders
// blank rather than red — analyze passes, build passes, and the page is
// simply empty on a device.
//
// Pumping it is the only thing that catches that, so it is pumped here: at
// several widths, scrolled, and with its rendered height measured against the
// extent it claims.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/shared/theme/app_theme.dart';
import 'package:french_mobiles/shared/widgets/app_search_field.dart';
import 'package:french_mobiles/shared/widgets/app_sticky_header.dart';

Future<void> _pump(WidgetTester t, {required double width}) async {
  t.view.physicalSize = Size(width, 800);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);

  await t.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverList(
            delegate: SliverChildListDelegate([
              for (var i = 0; i < 4; i++)
                SizedBox(height: 120, child: Text('above $i')),
            ]),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: AppStickySearchHeader(
              child: AppSearchField(
                controller: TextEditingController(),
                hintText: 'Search phones, brands…',
                onChanged: (_) {},
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              for (var i = 0; i < 20; i++)
                SizedBox(height: 120, child: Text('below $i')),
            ]),
          ),
        ],
      ),
    ),
  ));
  await t.pump();
}

void main() {
  for (final width in const [400.0, 320.0]) {
    final label = '${width.toInt()}px';

    testWidgets('lays out without a sliver assertion at $label', (t) async {
      await _pump(t, width: width);

      expect(t.takeException(), isNull,
          reason: 'a SliverGeometry assertion renders the page blank, not '
              'red — this is the only test that would notice');
      expect(find.byType(AppSearchField), findsOneWidget);
    });

    testWidgets('the header renders exactly the extent it claims at $label',
        (t) async {
      await _pump(t, width: width);

      final rendered =
          t.getSize(find.byKey(AppStickySearchHeader.boxKey)).height;
      expect(rendered, AppStickySearchHeader.height,
          reason: 'paintExtent comes from this box and layoutExtent from '
              'maxExtent; a pixel of disagreement is the blank screen');
    });

    testWidgets('an oversized child cannot stretch the header at $label',
        (t) async {
      // The header must claim the same extent whatever it is given, because
      // maxExtent is a constant and the paint has to match it. A child that
      // could push it taller is the blank screen waiting to happen, so this
      // hands it one that would.
      t.view.physicalSize = Size(width, 800);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);

      await t.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              const SliverPersistentHeader(
                pinned: true,
                delegate: AppStickySearchHeader(
                  child: SizedBox(height: 300, width: 300),
                ),
              ),
              SliverList(
                delegate: SliverChildListDelegate([
                  for (var i = 0; i < 10; i++) const SizedBox(height: 120),
                ]),
              ),
            ],
          ),
        ),
      ));
      await t.pump();

      expect(t.takeException(), isNull);
      expect(
        t.getSize(find.byKey(AppStickySearchHeader.boxKey)).height,
        AppStickySearchHeader.height,
      );
    });
  }

  testWidgets('it stays put once the content above has scrolled away',
      (t) async {
    await _pump(t, width: 400);
    expect(find.byType(AppSearchField), findsOneWidget);

    await t.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await t.pumpAndSettle();

    expect(find.byType(AppSearchField), findsOneWidget,
        reason: 'the whole point: search stays reachable from anywhere in '
            'the list');
    expect(find.text('above 0'), findsNothing,
        reason: 'the content above it really did scroll off');
  });

  testWidgets('it sits at the very top once pinned', (t) async {
    await _pump(t, width: 400);
    await t.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await t.pumpAndSettle();

    final top = t.getTopLeft(find.byType(AppSearchField)).dy;
    expect(top, lessThan(AppStickySearchHeader.height),
        reason: 'pinned means against the top edge, not floating mid-page');
  });

  test('minExtent and maxExtent agree, which is what pinning requires', () {
    const delegate = AppStickySearchHeader(child: SizedBox());

    expect(delegate.minExtent, delegate.maxExtent);
    expect(delegate.maxExtent, AppStickySearchHeader.height);
  });

  test('it rebuilds when the field changes and not otherwise', () {
    const a = SizedBox(key: ValueKey('a'));
    const b = SizedBox(key: ValueKey('b'));

    expect(
      const AppStickySearchHeader(child: a)
          .shouldRebuild(const AppStickySearchHeader(child: a)),
      isFalse,
    );
    expect(
      const AppStickySearchHeader(child: b)
          .shouldRebuild(const AppStickySearchHeader(child: a)),
      isTrue,
    );
  });
}
