// Behaviour of the checkup orchestrator screen.
//
// The list of tests is the screen's main affordance, so these cover what
// happens when a user acts on it: tapping one test, leaving a run part-way,
// and what the screen reports back afterwards.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/models/checkup_result.dart';
import 'package:french_mobiles/screens/checkup/checkup_entry_page.dart';
import 'package:french_mobiles/screens/checkup/multitouch_test_page.dart';
import 'package:french_mobiles/screens/checkup/summary_page.dart';

Future<void> _boot(WidgetTester t, {Size size = const Size(400, 800)}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(const MaterialApp(home: CheckupEntryPage()));
  await t.pump(const Duration(milliseconds: 300));
}

/// Scrolls the multi-touch tile into view and taps it.
///
/// Multi-touch is the one test that drives no hardware, so it is the only
/// one that can actually be opened under flutter_test.
Future<void> _openMultitouch(WidgetTester t) async {
  final tile = find.text('Panel tracks five fingers at once');
  await t.scrollUntilVisible(tile, 200, scrollable: find.byType(Scrollable).first);
  await t.tap(tile);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('the intro count matches the number of registered tests',
      (t) async {
    await _boot(t);
    expect(
      find.text('${CheckupEntryPage.specs.length} hardware tests'),
      findsOneWidget,
      reason: 'a hardcoded count goes stale the moment a test is added',
    );
  });

  testWidgets('tapping a test in the list runs that test on its own',
      (t) async {
    await _boot(t);
    await _openMultitouch(t);

    expect(find.byType(MultitouchTestPage), findsOneWidget,
        reason: 'the list is the screen\'s main affordance; tiles must run');
  });

  testWidgets('a test run on its own reports its status back onto the tile',
      (t) async {
    await _boot(t);
    await _openMultitouch(t);

    await t.tap(find.text('Skip this test'));
    await t.pumpAndSettle();

    expect(find.byType(MultitouchTestPage), findsNothing);
    expect(find.text('SKIPPED'), findsOneWidget,
        reason: 'a result the user just produced should be visible');
  });

  testWidgets('results collected so far can be reviewed without a full run',
      (t) async {
    await _boot(t);
    await _openMultitouch(t);
    await t.tap(find.text('Skip this test'));
    await t.pumpAndSettle();

    await t.tap(find.text('View results'));
    await t.pumpAndSettle();

    expect(find.byType(CheckupSummaryPage), findsOneWidget);
  });

  testWidgets('leaving a test with back ends the run instead of advancing',
      (t) async {
    // Every registered test drives hardware flutter_test does not provide, so
    // the sequence runs against two stand-ins. Multi-touch is the one real
    // page that needs nothing, so it stands in for both steps.
    const stand = [
      CheckupTestSpec(
        key: 'first',
        title: 'First test',
        description: 'Stands in for the first step',
        icon: Icons.looks_one_outlined,
        pageBuilder: _standIn,
      ),
      CheckupTestSpec(
        key: 'second',
        title: 'Second test',
        description: 'Must not be reached after backing out',
        icon: Icons.looks_two_outlined,
        pageBuilder: _standIn,
      ),
    ];

    t.view.physicalSize = const Size(400, 800);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: CheckupEntryPage(tests: stand)));
    await t.pump(const Duration(milliseconds: 300));

    await t.tap(find.text('Start Checkup'));
    // Not pumpAndSettle: the start button shows a progress spinner while a
    // run is in flight, and a spinner never settles.
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byType(MultitouchTestPage), findsOneWidget);

    await t.tap(find.bySemanticsLabel('Back'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));

    expect(find.text('Device Auto Checkup'), findsOneWidget,
        reason: 'back should return to the list, not advance the sequence');
    expect(find.text('Second test'), findsOneWidget,
        reason: 'the second test should be listed, not opened');
    expect(find.byType(MultitouchTestPage), findsNothing,
        reason: 'backing out must not push the next test');
    expect(find.text('Start Checkup'), findsOneWidget,
        reason: 'the run should not still be in progress');
  });

  testWidgets('a completed result carries into the summary', (t) async {
    await _boot(t);
    await _openMultitouch(t);
    await t.tap(find.text('Skip this test'));
    await t.pumpAndSettle();
    await t.tap(find.text('View results'));
    await t.pumpAndSettle();

    final summary =
        t.widget<CheckupSummaryPage>(find.byType(CheckupSummaryPage));
    expect(summary.results, hasLength(1));
    expect(summary.results.single.key, 'multitouch');
    expect(summary.results.single.status, CheckupStatus.skipped);
  });
}

/// Stand-in page for sequencing tests: a real checkup page that drives no
/// hardware, so it renders and pops a result under flutter_test.
Widget _standIn(BuildContext context) => const MultitouchTestPage();
