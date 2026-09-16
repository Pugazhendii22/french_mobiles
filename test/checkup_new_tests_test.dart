// Tests for the tests added to the checkup flow.
//
// Most of these pages drive hardware unavailable under flutter_test — a
// torch, a receiver, a vibration motor — so they are covered by the
// orchestrator registration check plus the two pages that need nothing:
// multitouch (pure pointer events) and the shared result plumbing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/models/checkup_result.dart';
import 'package:french_mobiles/screens/checkup/checkup_entry_page.dart';
import 'package:french_mobiles/screens/checkup/multitouch_test_page.dart';

Future<void> _boot(WidgetTester t, Widget page,
    {Size size = const Size(400, 800)}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(home: page));
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  group('orchestrator registration', () {
    test('every new test is registered exactly once, in order', () {
      final keys = CheckupEntryPage.specs.map((s) => s.key).toList();

      for (final key in [
        'flashlight',
        'multitouch',
        'speaker',
        'earpiece',
        'microphone',
        'proximity',
        'vibration',
      ]) {
        expect(keys.where((k) => k == key).length, 1,
            reason: '$key should appear exactly once');
      }

      // The nine originals must still be present and untouched.
      for (final key in [
        'camera', 'display', 'buttons', 'wifi', 'bluetooth',
        'biometric', 'network', 'location', 'gyroscope',
      ]) {
        expect(keys, contains(key));
      }

      expect(keys.length, 16);
    });

    test('grouping keeps related hardware adjacent', () {
      final keys = CheckupEntryPage.specs.map((s) => s.key).toList();
      // Torch next to camera — same LED assembly.
      expect(keys.indexOf('flashlight'), keys.indexOf('camera') + 1);
      // Multitouch next to display — both the panel.
      expect(keys.indexOf('multitouch'), keys.indexOf('display') + 1);
      // The audio trio runs together.
      expect(keys.indexOf('earpiece'), keys.indexOf('speaker') + 1);
      expect(keys.indexOf('microphone'), keys.indexOf('earpiece') + 1);
    });

    test('every spec has a distinct key and a non-empty description', () {
      final specs = CheckupEntryPage.specs;
      expect(specs.map((s) => s.key).toSet().length, specs.length);
      for (final spec in specs) {
        expect(spec.title, isNotEmpty);
        expect(spec.description, isNotEmpty);
      }
    });
  });

  group('MultitouchTestPage', () {
    /// Pushes the page and returns whatever it pops.
    ///
    /// The shared flow shows a verdict then auto-pops after 1500ms, so the
    /// delay has to be pumped past explicitly — pumpAndSettle alone does not
    /// advance it.
    Future<CheckupResult?> run(
      WidgetTester t,
      Future<void> Function(WidgetTester t) act, {
      Size size = const Size(400, 800),
    }) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);

      CheckupResult? popped;
      await t.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                popped = await Navigator.of(context).push<CheckupResult>(
                  MaterialPageRoute(builder: (_) => const MultitouchTestPage()),
                );
              },
              child: const Text('go'),
            ),
          ),
        ),
      ));
      await t.tap(find.text('go'));
      await t.pumpAndSettle();

      await act(t);

      await t.pump(const Duration(milliseconds: 1600));
      await t.pumpAndSettle();
      return popped;
    }

    testWidgets('builds', (t) async {
      await _boot(t, const MultitouchTestPage());
      expect(find.text('Checkup · Multi-touch'), findsOneWidget);
    });

    testWidgets('builds narrow', (t) async {
      await _boot(t, const MultitouchTestPage(), size: const Size(320, 640));
    });

    testWidgets('five simultaneous pointers pass the test', (t) async {
      final result = await run(t, (t) async {
        final centre = t.getCenter(find.byType(MultitouchTestPage));
        final gestures = <TestGesture>[];
        for (var i = 0; i < 5; i++) {
          gestures.add(await t.startGesture(
            Offset(centre.dx - 60 + i * 30, centre.dy),
            pointer: 100 + i,
          ));
          await t.pump(const Duration(milliseconds: 20));
        }
        expect(find.text('PASS'), findsOneWidget,
            reason: 'five pointers should conclude the test immediately');
        for (final g in gestures) {
          await g.up();
        }
      });

      expect(result, isNotNull);
      expect(result!.status, CheckupStatus.pass);
      expect(result.key, 'multitouch');
      expect(result.detail, contains('5'));
    });

    testWidgets('fewer than five pointers does not pass', (t) async {
      await _boot(t, const MultitouchTestPage());
      final centre = t.getCenter(find.byType(MultitouchTestPage));
      final gestures = <TestGesture>[];
      for (var i = 0; i < 3; i++) {
        gestures.add(await t.startGesture(
          Offset(centre.dx - 30 + i * 30, centre.dy),
          pointer: 200 + i,
        ));
        await t.pump(const Duration(milliseconds: 20));
      }
      expect(find.text('PASS'), findsNothing);
      for (final g in gestures) {
        await g.up();
      }
      await t.pumpAndSettle();
    });

    testWidgets('skip returns a skipped result', (t) async {
      final result = await run(t, (t) async {
        await t.tap(find.text('Skip this test'));
      });
      expect(result!.status, CheckupStatus.skipped);
      expect(result.detail, 'Skipped by user');
    });

    testWidgets('Issue found returns a fail carrying the count reached',
        (t) async {
      final result = await run(t, (t) async {
        await t.tap(find.text('Issue found'));
      });
      expect(result!.status, CheckupStatus.fail);
      expect(result.key, 'multitouch');
      expect(result.detail, contains('at most 0'));
    });
  });
}
