// The wordless instruction animations.
//
// Twenty of them, each hand-painted with trigonometry and rects built from
// the canvas size. A negative radius, a NaN from a division, or a rect with
// a negative width throws at paint time — not at build time — so nothing but
// actually painting every one of them catches it. Each is painted at several
// points through its loop, and at a phone-sized and a cramped canvas.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/models/checkup_result.dart';
import 'package:french_mobiles/screens/checkup/checkup_demo.dart';
import 'package:french_mobiles/screens/checkup/checkup_verdict_mark.dart';

Future<void> _paintThroughLoop(
  WidgetTester tester,
  CheckupDemoKind kind, {
  required Size surface,
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(child: CheckupDemo(kind: kind)),
      ),
    ),
  );

  // Across the loop, including the wrap back to the start.
  for (var step = 0; step < 8; step++) {
    await tester.pump(const Duration(milliseconds: 325));
    expect(tester.takeException(), isNull,
        reason: '$kind threw while painting at ${surface.width}px wide');
  }
}

void main() {
  group('every demo paints', () {
    for (final kind in CheckupDemoKind.values) {
      testWidgets('${kind.name} on a normal screen', (t) async {
        await _paintThroughLoop(t, kind, surface: const Size(400, 800));
      });

      testWidgets('${kind.name} on a cramped screen', (t) async {
        // 320px is the narrowest phone the app supports; the illustrations
        // size themselves off the canvas, so this is where a rect can invert.
        await _paintThroughLoop(t, kind, surface: const Size(320, 560));
      });
    }
  });

  testWidgets('holds a still frame when motion is switched off', (t) async {
    await t.pumpWidget(const MediaQuery(
      data: MediaQueryData(disableAnimations: true),
      child: MaterialApp(
        home: Scaffold(body: CheckupDemo(kind: CheckupDemoKind.fiveFingers)),
      ),
    ));

    // Settling is only possible because nothing is repeating — with the
    // animation running this call would never return.
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  group('the verdict mark', () {
    for (final status in CheckupStatus.values) {
      testWidgets('draws ${status.name} without throwing', (t) async {
        await t.pumpWidget(MaterialApp(
          home:
              Scaffold(body: Center(child: CheckupVerdictMark(status: status))),
        ));

        // Through the ring sweep, the stroke, and the halo burst.
        for (var step = 0; step < 8; step++) {
          await t.pump(const Duration(milliseconds: 110));
          expect(t.takeException(), isNull, reason: '$status threw mid-draw');
        }
      });
    }

    testWidgets('finishes, so a page showing one can settle', (t) async {
      await t.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Center(child: CheckupVerdictMark(status: CheckupStatus.pass)),
        ),
      ));

      // It plays once. If it ever looped, this would hang like the
      // instruction demos do, and every page's verdict would become
      // untestable with pumpAndSettle.
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  });

  testWidgets('the animation is disposed with the widget', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(body: CheckupDemo(kind: CheckupDemoKind.volumeButtons)),
    ));
    await t.pump(const Duration(milliseconds: 400));

    // A repeating controller that outlives its State keeps ticking forever and
    // fails the test binding on teardown.
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    expect(t.takeException(), isNull);
  });
}
