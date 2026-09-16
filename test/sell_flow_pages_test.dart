// Layout smoke tests for the sell flow after brand selection.
//
// The wizard wraps its Firestore call in try/catch and settles into its empty
// state without Firebase. Checkout and order tracking touch catalogAuth /
// catalogFirestore during build, so they are exercised only where they can be
// reached without a configured app.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/screens/device_evaluation_wizard.dart';

Future<void> _boot(WidgetTester tester, Widget page, {Size? size}) async {
  tester.view.physicalSize = size ?? const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pump(const Duration(milliseconds: 500));
}

Widget _wizard() => const DeviceEvaluationWizard(
      brandName: 'Apple',
      modelDocId: 'x',
      modelName: 'iPhone 13',
      basePrice: 50000,
      storage: '128GB',
    );

void main() {
  group('DeviceEvaluationWizard', () {
    testWidgets('builds at step 1', (t) async {
      await _boot(t, _wizard());
      expect(find.text('Screen condition'), findsOneWidget);
      expect(find.text('STEP 1/6'), findsOneWidget);
    });

    testWidgets('builds narrow', (t) async {
      await _boot(t, _wizard(), size: const Size(320, 640));
    });

    testWidgets('advances through every step to the payout bar', (t) async {
      await _boot(t, _wizard());
      for (var i = 0; i < 5; i++) {
        await t.tap(find.text('Continue'));
        await t.pump(const Duration(milliseconds: 300));
      }
      expect(find.text('Lock status & payout'), findsOneWidget);
      expect(find.text('STEP 6/6'), findsOneWidget);
      expect(find.text('Get paid'), findsOneWidget);
      // The payout counts up to its value, so wait for the animation to land
      // before asserting. With no options loaded no deduction applies and the
      // figure is the full base price.
      await t.pumpAndSettle();
      expect(find.text('₹ 50000'), findsOneWidget);
    });
  });
}
