// The gyroscope test is a game, and a game you cannot lose tests nothing.
//
// The first version shipped with the ball starting at (0,0) — the centre of
// the target — so it passed itself 1.2 seconds after opening, without the
// phone being touched. The second had the ball's position decay toward the
// origin to bleed off drift, which quietly pulled it *into* the ring and did
// the same thing more slowly.
//
// Both bugs have the same shape: something other than the seller's hand moved
// the ball to the target. These assert the two properties that rule that out,
// against the real widget.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/screens/checkup/gyroscope_test_page.dart';

void main() {
  group('where the ball starts', () {
    // Asserted directly rather than inferred from how long the widget takes to
    // pass. A timing-based version of this missed the original bug entirely:
    // one large pump exceeds the physics' own dt guard and is skipped, so the
    // ball never moved and the test looked fine.
    test('never inside the ring, whatever the random angle', () {
      for (var seed = 0; seed < 500; seed++) {
        final start = initialBallPosition(math.Random(seed));
        final distance = math.sqrt(start.x * start.x + start.y * start.y);
        expect(distance, greaterThan(kGyroRingRadius),
            reason: 'seed $seed spawned the ball inside the target, which '
                'wins the game before the phone is touched');
      }
    });

    test('never outside the board either', () {
      for (var seed = 0; seed < 500; seed++) {
        final start = initialBallPosition(math.Random(seed));
        expect(start.x.abs(), lessThanOrEqualTo(1.0));
        expect(start.y.abs(), lessThanOrEqualTo(1.0));
      }
    });

    test('comes from different directions', () {
      // One fixed corner would be learnable as a single motion, and would
      // stop exercising both axes.
      final angles = {
        for (var seed = 0; seed < 50; seed++)
          () {
            final s = initialBallPosition(math.Random(seed));
            return math.atan2(s.y, s.x).toStringAsFixed(1);
          }()
      };
      expect(angles.length, greaterThan(10),
          reason: 'the spawn should be spread around the board');
    });
  });

  testWidgets('a motionless phone never completes the test', (tester) async {
    // The decay bug: with no sensor events at all, the ball must stay exactly
    // where it was put. Any force pulling it toward the centre shows up here
    // as an eventual pass.
    await tester.pumpWidget(
      const MaterialApp(home: GyroscopeTestPage()),
    );

    // Well beyond the 1.2s hold, and beyond the 3s silence warning.
    for (var i = 0; i < 300; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(find.text('PASS'), findsNothing,
        reason: 'a phone lying on a table must not pass a movement test');
  });

  testWidgets('says so when the sensor reports nothing at all', (tester) async {
    // A handset with no gyroscope emits no events *and no error*. Silence has
    // to be surfaced or the page looks like it is still working.
    await tester.pumpWidget(
      const MaterialApp(home: GyroscopeTestPage()),
    );

    for (var i = 0; i < 220; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(
      find.textContaining('not reporting any rotation'),
      findsOneWidget,
      reason: 'three seconds of silence should be called out',
    );
  });

  testWidgets('offers both a skip and a way to record a failure',
      (tester) async {
    // Skipping and failing are different outcomes and a seller who genuinely
    // cannot steer the ball must be able to say so rather than skip.
    await tester.pumpWidget(
      const MaterialApp(home: GyroscopeTestPage()),
    );
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('Skip this test'), findsOneWidget);
    expect(find.text('Cannot do it'), findsOneWidget);
  });
}
