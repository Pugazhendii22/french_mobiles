// Bottom bars against a changing system inset.
//
// Hiding Android's navigation bar takes MediaQuery's bottom padding from
// roughly 48 to 0, and swiping it back up puts it there again — on the same
// screen, while the user is looking at it. Seven places add that inset to a
// bar's padding, so it is the one thing about hiding the bar that can
// actually break a layout.
//
// Both extremes are pumped here: 0 (bar hidden), a 3-button bar's inset, and
// a gesture-navigation handle's smaller one.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/features/home/widgets/home_bottom_nav.dart';
import 'package:french_mobiles/shared/theme/app_theme.dart';
import 'package:french_mobiles/shared/widgets/app_bottom_bar.dart';

/// Bottom insets worth caring about, in logical pixels.
const Map<String, double> _insets = {
  'navigation bar hidden': 0,
  'gesture handle': 24,
  '3-button bar': 48,
};

Future<void> _pump(
  WidgetTester t,
  Widget bar, {
  required double bottomInset,
  Size size = const Size(400, 800),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);

  await t.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          padding: EdgeInsets.only(bottom: bottomInset),
          viewPadding: EdgeInsets.only(bottom: bottomInset),
        ),
        child: Scaffold(bottomNavigationBar: bar),
      ),
    ),
  );
  await t.pump();
}

void main() {
  _insets.forEach((name, inset) {
    group('with the $name', () {
      testWidgets('the home navigation bar lays out', (t) async {
        await _pump(
          t,
          HomeBottomNav(current: HomeNavTab.home, onTap: (_) {}),
          bottomInset: inset,
        );

        expect(t.takeException(), isNull);
        expect(find.text('Home'), findsOneWidget);
        expect(find.text('Profile'), findsOneWidget);
      });

      testWidgets('the home navigation bar lays out on a narrow screen',
          (t) async {
        // Five tabs across 320px is the tightest this bar ever gets.
        await _pump(
          t,
          HomeBottomNav(current: HomeNavTab.home, onTap: (_) {}),
          bottomInset: inset,
          size: const Size(320, 640),
        );

        expect(t.takeException(), isNull);
      });

      testWidgets('the shared bottom bar lays out', (t) async {
        await _pump(
          t,
          const AppBottomBar(child: Text('Continue')),
          bottomInset: inset,
        );

        expect(t.takeException(), isNull);
        expect(find.text('Continue'), findsOneWidget);
      });
    });
  });

  testWidgets('the bar grows by exactly the inset it is given', (t) async {
    double heightWith(double inset) => inset;

    await _pump(
      t,
      HomeBottomNav(current: HomeNavTab.home, onTap: (_) {}),
      bottomInset: 0,
    );
    final hidden = t.getSize(find.byType(HomeBottomNav)).height;

    await _pump(
      t,
      HomeBottomNav(current: HomeNavTab.home, onTap: (_) {}),
      bottomInset: 48,
    );
    final shown = t.getSize(find.byType(HomeBottomNav)).height;

    expect(shown - hidden, heightWith(48),
        reason: 'the bar should clear the system bar by exactly its height — '
            'more and it floats, less and the buttons sit on the tabs');
  });
}
