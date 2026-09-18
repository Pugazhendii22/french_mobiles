// Layout smoke tests for the sell entry screen.
//
// A layout assertion inside a sliver takes down the whole viewport and the
// screen renders blank rather than showing an error, so these pump the page
// in each of its states to keep that class of bug visible.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/screens/sell_mobile_page.dart';

Future<void> _boot(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: SellMobilePage()));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('builds at 400x800', (tester) async {
    await _boot(tester, const Size(400, 800));
  });

  testWidgets('narrow build at 320x640', (tester) async {
    await _boot(tester, const Size(320, 640));
  });

  testWidgets('searching matches brands', (tester) async {
    await _boot(tester, const Size(400, 800));
    await tester.enterText(find.byType(TextField), 'apple');
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Apple'), findsWidgets);
  });

  testWidgets('no model results are invented when the catalogue is absent',
      (tester) async {
    // Model results used to come from fourteen names typed into the source
    // file, so they appeared whether or not the catalogue was reachable —
    // and tapping one opened the wizard at a flat, invented base price.
    await _boot(tester, const Size(400, 800));
    await tester.enterText(find.byType(TextField), 'iphone');
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('iPhone 13'), findsNothing,
        reason: 'there is no Firestore here, so there are no models to show');
  });

  testWidgets('search with no brand matches shows empty state', (tester) async {
    await _boot(tester, const Size(400, 800));
    await tester.enterText(find.byType(TextField), 'zzzzzz');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('No matching brands'), findsOneWidget);
  });

  testWidgets('scrolls far enough to pin the header', (tester) async {
    await _boot(tester, const Size(400, 800));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('help sheet opens and expands', (tester) async {
    await _boot(tester, const Size(400, 800));
    await tester.tap(find.byTooltip('Sell help & FAQs'));
    await tester.pumpAndSettle();
    expect(find.text('Selling help'), findsOneWidget);
    await tester.tap(find.text('When will I get paid?'));
    await tester.pumpAndSettle();
  });
}
