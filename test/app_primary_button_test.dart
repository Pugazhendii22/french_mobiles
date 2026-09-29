// The app's primary call-to-action.
//
// Its label used to sit in a Row that could not shrink, so any label long
// enough to fill the button overflowed on a narrow screen — and an overflow
// clips the text rather than resizing it, so the label came out cut in half.
// That was app-wide, and it took a map picker's "Confirm location" to expose
// it, which is exactly the kind of bug that hides until a customer finds it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/shared/theme/app_theme.dart';
import 'package:french_mobiles/shared/widgets/app_primary_button.dart';

/// The narrowest phone still in circulation, minus the standard page gutters.
const double _narrowContentWidth = 320 - 2 * AppSpacing.screenGutter;

Future<void> _pump(
  WidgetTester t,
  Widget button, {
  double width = _narrowContentWidth,
}) async {
  t.view.physicalSize = const Size(320, 640);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);

  await t.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: Center(
        child: SizedBox(width: width, child: button),
      ),
    ),
  ));
  await t.pump();
}

void main() {
  testWidgets('the label that exposed the bug fits at 320px', (t) async {
    // Verified to pass even without Flexible under AppTheme.light — it was
    // the map picker's plainer theme that made this one overflow. Kept as the
    // real-world case; the two below are what actually fail without the fix.
    await _pump(
      t,
      const AppPrimaryButton(label: 'Confirm location', onPressed: _noop),
    );

    expect(t.takeException(), isNull);
  });

  testWidgets('a long label with an icon does not overflow', (t) async {
    // The icon and its gap eat into the same row, so this is the tighter
    // case — and it overflows by 127px without the fix.
    await _pump(
      t,
      const AppPrimaryButton(
        label: 'Confirm pickup location',
        icon: Icons.check_circle_outline,
        onPressed: _noop,
      ),
    );

    expect(t.takeException(), isNull);
  });

  // Overflows by 628px without the fix.
  testWidgets('an absurd label still lays out, truncated', (t) async {
    await _pump(
      t,
      const AppPrimaryButton(
        label: 'Confirm this pickup location and continue to the next step',
        onPressed: _noop,
      ),
    );

    expect(t.takeException(), isNull);
    expect(find.byType(AppPrimaryButton), findsOneWidget);
  });

  testWidgets('a short label is still centred, not stretched', (t) async {
    await _pump(t, const AppPrimaryButton(label: 'Save', onPressed: _noop));

    expect(t.takeException(), isNull);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('expand: false survives an unbounded-width parent', (t) async {
    // A Row gives its children unbounded width. The theme once set
    // minimumSize to Size.fromHeight, which is Size(infinity, 52), and this
    // combination blanked whole screens.
    t.view.physicalSize = const Size(400, 800);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(
        body: Row(
          children: [
            AppPrimaryButton(
              label: 'Continue',
              expand: false,
              onPressed: _noop,
            ),
          ],
        ),
      ),
    ));
    await t.pump();

    expect(t.takeException(), isNull);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('loading swaps the label without changing the footprint',
      (t) async {
    await _pump(
      t,
      const AppPrimaryButton(
        label: 'Confirm location',
        loading: true,
        onPressed: _noop,
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}

void _noop() {}
