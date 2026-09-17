// The proximity test blanks the screen the way a call does.
//
// The risk worth testing is not the blanking but the giving back: a
// PROXIMITY_SCREEN_OFF_WAKE_LOCK left held keeps the screen dark whenever the
// sensor is covered, with nothing on screen to explain why.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/screens/checkup/proximity_test_page.dart';

const _channel = MethodChannel('french_mobiles/proximity_screen');

void main() {
  late List<String> calls;
  late bool supported;

  setUp(() {
    calls = [];
    supported = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'enable':
          return supported;
        case 'disable':
          return true;
        case 'isSupported':
          return supported;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  Future<void> boot(WidgetTester t, {Size size = const Size(400, 800)}) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: ProximityTestPage()));
    await t.pump(const Duration(milliseconds: 300));
  }

  testWidgets('takes the screen lock as the test starts', (t) async {
    await boot(t);
    expect(calls, contains('enable'));
  });

  testWidgets('says the screen will go dark, so it does not look broken',
      (t) async {
    await boot(t);
    expect(find.textContaining('go dark'), findsOneWidget);
  });

  testWidgets('gives the screen back when the test is skipped', (t) async {
    await boot(t);
    await t.tap(find.text('Skip this test'));
    await t.pump();

    expect(calls, contains('disable'),
        reason: 'a held wake lock keeps blanking the screen after the test');
  });

  testWidgets('gives the screen back when the page goes away', (t) async {
    await boot(t);
    await t.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await t.pump();

    expect(calls, contains('disable'));
  });

  testWidgets('a device without the wake lock still runs the test', (t) async {
    supported = false;
    await boot(t);

    expect(calls, contains('enable'));
    expect(find.textContaining('go dark'), findsNothing,
        reason: 'promising a dark screen that never comes is worse than '
            'saying nothing');
    expect(find.textContaining('Hold the phone to your ear'), findsOneWidget,
        reason: 'the sensor readings still drive the test');
  });

  testWidgets('a failing channel does not take the test down with it',
      (t) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      throw PlatformException(code: 'no');
    });

    await boot(t);
    expect(find.textContaining('Hold the phone to your ear'), findsOneWidget);
  });

  testWidgets('lays out on a narrow screen', (t) async {
    await boot(t, size: const Size(320, 640));
  });
}
