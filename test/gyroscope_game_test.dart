// The gyroscope test is a game, and a game you cannot lose tests nothing.
//
// Two earlier versions passed themselves: one spawned the ball inside the
// target, the other decayed its position toward the origin, which is the
// target. Both had the same shape — something other than the seller's hand
// moved the ball home.
//
// The current design cannot do that, because the ball's position is a direct
// function of tilt rather than anything accumulated: a phone that is not moved
// produces a ball that does not move. What is left to protect is that a
// motionless phone never completes, that silence is surfaced, and that both
// outcomes are reachable.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/screens/checkup/gyroscope_test_page.dart';

void main() {
  testWidgets('a motionless phone never completes the test', (tester) async {
    // The bug this file exists for, and it has now been shipped twice. The
    // ball's position starts at (0,0) because that is what a position is
    // before any reading arrives — and (0,0) is the middle of the target. So a
    // phone lying flat, or one with no sensors at all, sat in the ring from
    // the first frame and passed itself.
    await tester.pumpWidget(const MaterialApp(home: GyroscopeTestPage()));

    // Checked *while* the page is still up. An earlier version of this test
    // looked after 300 frames, by which point a passing page had already shown
    // its verdict and popped, leaving nothing to find — so it went green on
    // the very bug it was written to catch.
    for (var frame = 0; frame < 200; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('PASS'), findsNothing,
          reason: 'nothing moved the phone, so nothing should have passed '
              '(frame $frame)');
    }
  });

  testWidgets('says so when the sensor reports nothing at all', (tester) async {
    // A handset with no such sensor emits no events *and no error* — the
    // stream simply stays quiet, so silence needs a deadline of its own.
    await tester.pumpWidget(
      const MaterialApp(home: GyroscopeTestPage()),
    );

    // Past the four-second deadline the page gives silence.
    for (var i = 0; i < 300; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(
      find.textContaining('not reporting any movement'),
      findsOneWidget,
      reason: 'silence has to be surfaced, or the page looks like it is '
          'still working',
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
