// Layout smoke tests for the checkup flow.
//
// These pages drive real hardware (camera, sensors, bluetooth, wifi), which is
// unavailable under flutter_test, so each is pumped only far enough to prove
// its first frame lays out. That is the failure mode worth guarding: a layout
// assertion renders blank rather than erroring.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/models/checkup_result.dart';
import 'package:french_mobiles/screens/checkup/checkup_entry_page.dart';
import 'package:french_mobiles/screens/checkup/summary_page.dart';

Future<void> _boot(WidgetTester tester, Widget page, {Size? size}) async {
  tester.view.physicalSize = size ?? const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('CheckupEntryPage builds', (t) async {
    await _boot(t, const CheckupEntryPage());
    expect(find.text('Device Auto Checkup'), findsOneWidget);
  });

  testWidgets('CheckupEntryPage builds narrow', (t) async {
    await _boot(t, const CheckupEntryPage(), size: const Size(320, 640));
  });

  testWidgets('CheckupSummaryPage builds with mixed results', (t) async {
    await _boot(
      t,
      const CheckupSummaryPage(
        results: [
          CheckupResult(key: 'display', title: 'Display', status: CheckupStatus.pass),
          CheckupResult(key: 'camera', title: 'Camera', status: CheckupStatus.fail),
          CheckupResult(key: 'bluetooth', title: 'Bluetooth', status: CheckupStatus.skipped),
          CheckupResult(key: 'biometric', title: 'Biometric', status: CheckupStatus.notAvailable),
        ],
      ),
    );
    expect(find.text('Checkup Results'), findsOneWidget);
  });

  testWidgets('CheckupSummaryPage builds with an empty result set', (t) async {
    await _boot(t, const CheckupSummaryPage(results: []));
  });

  testWidgets('CheckupSummaryPage builds narrow', (t) async {
    await _boot(
      t,
      const CheckupSummaryPage(
        results: [CheckupResult(key: 'display', title: 'Display', status: CheckupStatus.pass)],
      ),
      size: const Size(320, 640),
    );
  });
}
