// Holding a skeleton on screen long enough to be read as a load.
//
// A cached Firestore read can land in under a tenth of a second. A skeleton
// that appears and vanishes inside 80ms reads as a glitch, not a load — so
// AppSkeleton holds it for a floor once it has been shown, while never
// delaying content that was not loading in the first place.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/shared/widgets/app_shimmer.dart';

const _floor = Duration(milliseconds: 300);

Future<void> _pump(WidgetTester t, bool loading) async {
  await t.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AppSkeleton(
          loading: loading,
          minimum: _floor,
          skeleton: const Text('skeleton'),
          child: const Text('content'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('content that was never loading shows straight away', (t) async {
    await _pump(t, false);

    expect(find.text('content'), findsOneWidget);
    expect(find.text('skeleton'), findsNothing,
        reason: 'nothing was waiting, so nothing should be held back');
  });

  testWidgets('a fast load still shows its skeleton for the floor', (t) async {
    await _pump(t, true);
    expect(find.text('skeleton'), findsOneWidget);

    // Data lands almost immediately.
    await t.pump(const Duration(milliseconds: 50));
    await _pump(t, false);
    await t.pump();

    expect(find.text('skeleton'), findsOneWidget,
        reason: 'swapping at 50ms would read as a flicker');

    await t.pump(const Duration(milliseconds: 260));
    expect(find.text('content'), findsOneWidget);
    expect(find.text('skeleton'), findsNothing);
  });

  testWidgets('a slow load swaps the moment it finishes', (t) async {
    await _pump(t, true);
    await t.pump(const Duration(milliseconds: 900));

    await _pump(t, false);
    await t.pump();

    expect(find.text('content'), findsOneWidget,
        reason: 'the floor was already served; holding longer just delays');
  });

  testWidgets('loading again brings the skeleton back', (t) async {
    await _pump(t, true);
    await t.pump(const Duration(milliseconds: 400));
    await _pump(t, false);
    await t.pump();
    expect(find.text('content'), findsOneWidget);

    await _pump(t, true);
    await t.pump();
    expect(find.text('skeleton'), findsOneWidget,
        reason: 'a refresh is a load like any other');
  });

  testWidgets('a pending hold does not outlive the widget', (t) async {
    await _pump(t, true);
    await t.pump(const Duration(milliseconds: 50));
    await _pump(t, false);
    await t.pump();

    // Torn down mid-hold: the timer must not fire into a dead State.
    await t.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await t.pump(const Duration(milliseconds: 400));

    expect(t.takeException(), isNull);
  });

  testWidgets('interrupting a hold with a new load keeps the skeleton up',
      (t) async {
    await _pump(t, true);
    await t.pump(const Duration(milliseconds: 50));
    await _pump(t, false);
    await t.pump();

    // Loading restarts before the floor elapsed.
    await _pump(t, true);
    await t.pump(const Duration(milliseconds: 400));

    expect(find.text('skeleton'), findsOneWidget,
        reason: 'the earlier hold must not swap in content mid-load');
  });
}
