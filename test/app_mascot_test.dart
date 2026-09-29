// The helper that walks about on top of the shell.
//
// Two things here would be invisible if they broke. It sits in a
// Positioned.fill over every tab, so an overlay that quietly ate taps would
// break every button beneath it on every screen; and it runs its own physics
// ticker, so a dt bug could fling it off screen where nobody would ever see
// it again.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/shared/widgets/app_mascot.dart';

const Size _screen = Size(400, 800);

/// Sizes the real render surface, not just the reported MediaQuery — the
/// mascot's floor is wherever its own box actually ends.
Future<void> _pumpHarness(
  WidgetTester t, {
  VoidCallback? onTapBehind,
  bool reduceMotion = false,
  DateTime? now,
}) async {
  t.view.physicalSize = _screen;
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(_harness(
    onTapBehind: onTapBehind,
    reduceMotion: reduceMotion,
    now: now,
  ));
}

Widget _harness({
  VoidCallback? onTapBehind,
  bool reduceMotion = false,
  DateTime? now,
}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTapBehind,
                child: const Center(child: Text('page content')),
              ),
            ),
            Positioned.fill(
              child: AppMascot(now: now == null ? null : () => now),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Where the character is, in screen coordinates.
Rect _mascotRect(WidgetTester t) =>
    t.getRect(find.byType(RepaintBoundary).last);

/// Runs the physics for [seconds] without ever settling — it never settles.
Future<void> _run(WidgetTester t, double seconds) async {
  const step = Duration(milliseconds: 16);
  for (var i = 0; i < (seconds * 1000 / 16).round(); i++) {
    await t.pump(step);
  }
}

void main() {
  testWidgets('starts standing on the floor, at the right', (t) async {
    await _pumpHarness(t);
    await _run(t, 0.1);

    final rect = _mascotRect(t);
    expect(rect.bottom, closeTo(800, 1),
        reason: 'the bottom of the area is its floor');
    expect(rect.left, greaterThan(200), reason: 'it starts out of the way');
  });

  testWidgets('does not swallow taps meant for the page', (t) async {
    var tapsBehind = 0;
    await _pumpHarness(t, onTapBehind: () => tapsBehind++);
    await _run(t, 0.1);

    // Top-left, far from where it walks.
    await t.tapAt(const Offset(40, 80));
    await t.pump();

    expect(tapsBehind, 1,
        reason: 'the overlay fills the screen but must be transparent to '
            'everything except its own character');
  });

  testWidgets('walks about without leaving the floor or the screen', (t) async {
    await _pumpHarness(t);

    final seen = <double>{};
    for (var i = 0; i < 40; i++) {
      await _run(t, 0.25);
      final rect = _mascotRect(t);

      expect(rect.left, greaterThanOrEqualTo(-0.5));
      expect(rect.right, lessThanOrEqualTo(_screen.width + 0.5));
      // Tolerant of the walk cycle: each step lifts it a couple of pixels,
      // which is the bob and not a failure of gravity.
      expect(rect.bottom, closeTo(800, 3),
          reason: 'pottering about must never lift it off the floor');
      seen.add(rect.left.roundToDouble());
    }

    expect(seen.length, greaterThan(1),
        reason: 'it should actually move, not just stand there');
  });

  group('when it is thrown', () {
    testWidgets('it falls back down and lands on the floor', (t) async {
      await _pumpHarness(t);
      await _run(t, 0.1);

      // Carried up into the middle and let go. Moved in steps, because a
      // pan is only recognised once the pointer has actually travelled.
      final gesture = await t.startGesture(_mascotRect(t).center);
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(-15, -40));
        await t.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await t.pump();

      expect(_mascotRect(t).bottom, lessThan(700),
          reason: 'it should be up in the air now');

      await _run(t, 4);
      expect(_mascotRect(t).bottom, closeTo(800, 1.5),
          reason: 'gravity should have brought it home');
    });

    // Also the only cover for the dazed drawing: a fling this hard always
    // knocks it silly on the first wall, so these frames paint the spinning
    // eyes and the orbiting stars as well as the physics.
    testWidgets('it stays inside the screen however hard it is flung',
        (t) async {
      await _pumpHarness(t);
      await _run(t, 0.1);

      final gesture = await t.startGesture(_mascotRect(t).center);
      // A deliberately violent flick, straight at the corner.
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(-60, -60));
        await t.pump(const Duration(milliseconds: 8));
      }
      await gesture.up();

      for (var i = 0; i < 200; i++) {
        await t.pump(const Duration(milliseconds: 16));
        final rect = _mascotRect(t);
        expect(rect.left, greaterThanOrEqualTo(-0.5));
        expect(rect.right, lessThanOrEqualTo(_screen.width + 0.5));
        expect(rect.top, greaterThanOrEqualTo(-0.5));
        expect(rect.bottom, lessThanOrEqualTo(_screen.height + 0.5));
      }
    });
  });

  testWidgets('tapping it offers a tip, and a second tap puts it away',
      (t) async {
    await _pumpHarness(t);
    await _run(t, 0.1);

    final before = find.byType(Text).evaluate().length;

    await t.tapAt(_mascotRect(t).center);
    await t.pump();
    expect(find.byType(Text).evaluate().length, greaterThan(before));

    await t.tapAt(_mascotRect(t).center);
    await t.pump();
    expect(find.byType(Text).evaluate().length, before);
  });

  testWidgets('what it says knows what day it is', (t) async {
    // 20 September 2026, a Sunday, mid-afternoon.
    await _pumpHarness(t, now: DateTime(2026, 9, 20, 15));
    await _run(t, 0.1);

    await t.tapAt(_mascotRect(t).center);
    await t.pump();

    final said = t.widgetList<Text>(find.byType(Text)).last.data ?? '';
    // Whatever it picked, a Sunday afternoon should never produce a line
    // about the small hours.
    expect(said, isNot(contains('asleep')));
    expect(said, isNotEmpty);
  });

  testWidgets('stands perfectly still when the system asks for no motion',
      (t) async {
    await _pumpHarness(t, reduceMotion: true);

    // No ticker was ever started, so there is nothing to settle.
    await t.pumpAndSettle();
    final resting = _mascotRect(t);

    await t.pumpAndSettle();
    expect(_mascotRect(t), resting);
  });

  testWidgets('survives being dropped from the tree mid-flight', (t) async {
    await _pumpHarness(t);
    await _run(t, 0.3);

    await t.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
