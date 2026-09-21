// The colour sweep, which is the one screen in the app that must stay empty.
//
// It is an instrument: the seller is looking AT the panel for dead pixels, so
// anything drawn over it — a caption, a progress row, a button — hides the
// very faults the test exists to find. A dead pixel under a label is a dead
// pixel nobody finds, and it would look like a working test the whole time.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/models/checkup_result.dart';
import 'package:french_mobiles/screens/checkup/display_test_page.dart';

/// Opens the page and gets past the up-front explanation.
Future<CheckupResult?> _open(WidgetTester t) async {
  t.view.physicalSize = const Size(400, 800);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);

  CheckupResult? popped;
  await t.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async {
            popped = await Navigator.of(context).push<CheckupResult>(
              MaterialPageRoute(builder: (_) => const DisplayTestPage()),
            );
          },
          child: const Text('go'),
        ),
      ),
    ),
  ));
  await t.tap(find.text('go'));
  await t.pumpAndSettle();
  return popped;
}

Future<void> _start(WidgetTester t) async {
  await t.tap(find.text('Start'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('explains itself before any colour appears', (t) async {
    await _open(t);

    expect(find.text('Checking the screen'), findsOneWidget,
        reason: 'the instruction has to come first, because it cannot be '
            'written over the colours afterwards');
    expect(find.textContaining('Tap the screen'), findsOneWidget);
  });

  testWidgets('shows nothing at all over the colour', (t) async {
    await _open(t);
    await _start(t);

    // Not one word, anywhere on the panel.
    expect(find.byType(Text), findsNothing,
        reason: 'any text over the sweep hides the pixels being inspected');
    expect(find.byType(Icon), findsNothing);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('a tap asks rather than assumes', (t) async {
    await _open(t);
    await _start(t);

    await t.tap(find.byType(Scaffold).last);
    await t.pumpAndSettle();

    expect(find.text('Issue found'), findsOneWidget);
    expect(find.textContaining('Looks fine'), findsOneWidget);
  });

  testWidgets('dismissing the question leaves the colour up', (t) async {
    await _open(t);
    await _start(t);

    await t.tap(find.byType(Scaffold).last);
    await t.pumpAndSettle();

    // Tapped by accident: backing out must not count as an answer.
    Navigator.of(t.element(find.text('Issue found'))).pop();
    await t.pumpAndSettle();

    expect(find.byType(Text), findsNothing);
  });

  testWidgets('"Issue found" fails the test there and then', (t) async {
    await _open(t);
    await _start(t);

    await t.tap(find.byType(Scaffold).last);
    await t.pumpAndSettle();
    await t.tap(find.text('Issue found'));
    await t.pumpAndSettle();

    // The verdict names the colour, so the agent knows where to look.
    expect(find.textContaining('red'), findsOneWidget);

    // The page auto-pops 1500ms after a verdict, as every checkup page does.
    await t.pump(const Duration(milliseconds: 1600));
    await t.pumpAndSettle();
  });

  testWidgets('every colour is asked about, not just the first', (t) async {
    await _open(t);
    await _start(t);

    // Four "next colour" answers, then the last one offers to finish.
    for (var i = 0; i < 4; i++) {
      await t.tap(find.byType(Scaffold).last);
      await t.pumpAndSettle();
      expect(find.text('Looks fine, next colour'), findsOneWidget,
          reason: 'colour ${i + 1} of 5 should still offer another');
      await t.tap(find.text('Looks fine, next colour'));
      await t.pumpAndSettle();
    }

    await t.tap(find.byType(Scaffold).last);
    await t.pumpAndSettle();
    expect(find.text('Looks fine, finish'), findsOneWidget,
        reason: 'the fifth colour is the last one');
  });

  testWidgets('can still be skipped, from either dialog', (t) async {
    await _open(t);
    await _start(t);

    await t.tap(find.byType(Scaffold).last);
    await t.pumpAndSettle();
    expect(find.text('Skip'), findsOneWidget,
        reason: 'removing the on-screen controls must not remove the way out');
  });
}
