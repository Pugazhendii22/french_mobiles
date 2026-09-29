// Tests for the shared motion layer.
//
// The reduced-motion cases matter most: every animated primitive must render
// its settled state when the platform asks for less motion, both for
// accessibility and so widget tests stay deterministic.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/shared/motion/motion.dart';

Widget _wrap(Widget child, {bool reduceMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  group('AppReveal', () {
    testWidgets('settles fully opaque', (t) async {
      await t.pumpWidget(_wrap(const AppReveal(child: Text('hi'))));
      await t.pumpAndSettle();
      final opacity = t.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, 1.0);
    });

    testWidgets('renders the child directly under reduced motion', (t) async {
      await t.pumpWidget(
        _wrap(const AppReveal(child: Text('hi')), reduceMotion: true),
      );
      await t.pump();
      expect(find.byType(Opacity), findsNothing);
      expect(find.text('hi'), findsOneWidget);
    });

    testWidgets('staggers without leaving timers pending', (t) async {
      await t.pumpWidget(_wrap(
        Column(
          children: [
            for (var i = 0; i < 12; i++)
              AppReveal(index: i, child: Text('item $i')),
          ],
        ),
      ));
      await t.pumpAndSettle();
      expect(find.text('item 11'), findsOneWidget);
    });
  });

  group('AppPressable', () {
    testWidgets('fires onTap', (t) async {
      var taps = 0;
      await t.pumpWidget(
        _wrap(AppPressable(onTap: () => taps++, child: const Text('tap'))),
      );
      await t.tap(find.text('tap'));
      await t.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('returns to full scale after a press', (t) async {
      await t.pumpWidget(
        _wrap(AppPressable(onTap: () {}, child: const Text('tap'))),
      );
      await t.tap(find.text('tap'));
      await t.pumpAndSettle();
      final scale = t.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale.scale, 1.0);
    });
  });

  group('AppAnimatedCount', () {
    testWidgets('lands on the target value', (t) async {
      await t.pumpWidget(_wrap(const AppAnimatedCount(value: 4200)));
      await t.pumpAndSettle();
      expect(find.text('4200'), findsOneWidget);
    });

    testWidgets('shows the value immediately under reduced motion', (t) async {
      await t.pumpWidget(
        _wrap(const AppAnimatedCount(value: 4200, prefix: '₹ '),
            reduceMotion: true),
      );
      await t.pump();
      expect(find.text('₹ 4200'), findsOneWidget);
    });
  });

  group('AppPageRoute', () {
    for (final transition in AppTransition.values) {
      testWidgets('pushes and settles: $transition', (t) async {
        await t.pumpWidget(MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => context.pushScreen(
                  const Scaffold(body: Text('second')),
                  transition: transition,
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ));
        await t.tap(find.text('go'));
        await t.pumpAndSettle();
        expect(find.text('second'), findsOneWidget);
      });
    }

    testWidgets('pops back cleanly', (t) async {
      await t.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => context.pushScreen(
                const Scaffold(body: Text('second')),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ));
      await t.tap(find.text('go'));
      await t.pumpAndSettle();
      final ctx = t.element(find.text('second'));
      Navigator.of(ctx).pop();
      await t.pumpAndSettle();
      expect(find.text('go'), findsOneWidget);
    });
  });
}
