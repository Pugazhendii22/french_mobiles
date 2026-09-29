// Tests for the tiered surface rule.
//
// The point of AppSurface is that the levels are visibly DIFFERENT — before it
// existed, everything was the same white bordered box. These assert that each
// level keeps its distinct treatment, so the hierarchy cannot quietly collapse
// back into card soup.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/shared/theme/app_colors.dart';
import 'package:french_mobiles/shared/widgets/widgets.dart';

BoxDecoration? _decorationOf(WidgetTester tester) {
  final finder = find.descendant(
    of: find.byType(AppSurface),
    matching: find.byType(DecoratedBox),
  );
  if (finder.evaluate().isEmpty) return null;
  return tester.widget<DecoratedBox>(finder.first).decoration as BoxDecoration;
}

Future<BoxDecoration?> _pump(WidgetTester t, AppSurfaceLevel level) async {
  await t.pumpWidget(MaterialApp(
    home: Scaffold(
      body: AppSurface(level: level, child: const Text('x')),
    ),
  ));
  await t.pump();
  return _decorationOf(t);
}

void main() {
  testWidgets('page level draws no box at all', (t) async {
    expect(await _pump(t, AppSurfaceLevel.page), isNull);
  });

  testWidgets('group level is bordered and flat', (t) async {
    final d = await _pump(t, AppSurfaceLevel.group);
    expect(d!.border, isNotNull, reason: 'group is defined by its outline');
    expect(d.boxShadow, isNull, reason: 'group must not also be lifted');
    expect(d.color, AppColors.surface);
  });

  testWidgets('raised level is lifted and NOT bordered', (t) async {
    final d = await _pump(t, AppSurfaceLevel.raised);
    expect(d!.boxShadow, isNotNull, reason: 'the lift marks it tappable');
    expect(d.border, isNull,
        reason: 'border plus shadow is what made everything look identical');
  });

  testWidgets('accent level is tinted, unbordered and flat', (t) async {
    final d = await _pump(t, AppSurfaceLevel.accent);
    expect(d!.color, AppColors.primarySoft);
    expect(d.border, isNull);
    expect(d.boxShadow, isNull);
  });

  testWidgets('every level is visually distinct from the others', (t) async {
    final seen = <String>{};
    for (final level in AppSurfaceLevel.values) {
      final d = await _pump(t, level);
      seen.add('${d?.color}|${d?.border != null}|${d?.boxShadow != null}');
    }
    expect(seen.length, AppSurfaceLevel.values.length,
        reason: 'two levels rendering the same defeats the hierarchy');
  });

  group('AppGroup', () {
    testWidgets('puts one box around many rows, not one each', (t) async {
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AppGroup(children: [
            for (var i = 0; i < 4; i++) Text('row $i'),
          ]),
        ),
      ));
      await t.pump();
      expect(find.byType(AppSurface), findsOneWidget);
      expect(find.byType(Divider), findsNWidgets(3));
    });

    testWidgets('bare keeps the rules and drops the box', (t) async {
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AppGroup(bare: true, children: [
            for (var i = 0; i < 3; i++) Text('row $i'),
          ]),
        ),
      ));
      await t.pump();
      expect(find.byType(AppSurface), findsNothing);
      expect(find.byType(Divider), findsNWidgets(2));
    });
  });
}
