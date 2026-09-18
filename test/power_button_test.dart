// The power step of the side-buttons test.
//
// Android reserves KEYCODE_POWER and never delivers it to an app, so the
// press itself cannot be observed. Its effect can be: the screen turning off
// and then coming back. The step used to just ask the user whether the button
// worked, which tested nothing — a seller with a broken power button could
// tap Yes and the report would say the button was fine.
//
// These drive the native screen broadcasts to check the sequence is what
// grants the pass.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/screens/checkup/buttons_test_page.dart';

const _volume = MethodChannel('french_mobiles/volume_keys');
const _power = MethodChannel('french_mobiles/power_button');

late List<String> calls;

Future<void> _boot(WidgetTester t) async {
  t.view.physicalSize = const Size(400, 800);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);

  await t.pumpWidget(const MaterialApp(home: ButtonsTestPage()));
  await t.pump();
  await t.pump(const Duration(milliseconds: 100));
}

/// Sends a screen broadcast the way MainActivity does.
Future<void> _screen(WidgetTester t, String event) async {
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
    _power.name,
    _power.codec.encodeMethodCall(
      MethodCall('screenEvent', {'event': event}),
    ),
    (_) {},
  );
  await t.pump();
}

void main() {
  setUp(() {
    calls = [];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    // No volume key channel, so both volume steps skip and the power step is
    // reached immediately.
    messenger.setMockMethodCallHandler(_volume, (call) async {
      throw PlatformException(code: 'unavailable');
    });
    messenger.setMockMethodCallHandler(_power, (call) async {
      calls.add(call.method);
      return true;
    });
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_volume, null);
    messenger.setMockMethodCallHandler(_power, null);
  });

  testWidgets('the power step watches the screen rather than asking',
      (t) async {
    await _boot(t);

    expect(calls, contains('startWatching'));
    expect(find.textContaining('Waiting for the screen to go off'),
        findsOneWidget);
    expect(find.text('Yes, it worked'), findsNothing,
        reason: 'the self-report is a fallback, not the first thing offered');
  });

  testWidgets('screen off alone is not a pass', (t) async {
    await _boot(t);
    await _screen(t, 'screen_off');

    expect(find.textContaining('Now wake it up'), findsOneWidget);
    expect(find.text('PASS'), findsNothing,
        reason: 'a screen that goes off and never comes back is not a '
            'working power button');
  });

  testWidgets('off then on is what passes the step', (t) async {
    await _boot(t);
    await _screen(t, 'screen_off');
    await _screen(t, 'screen_on');
    await t.pump(const Duration(milliseconds: 300));

    expect(calls, contains('stopWatching'),
        reason: 'a receiver left registered would read an unrelated '
            'screen-off as another press');
  });

  testWidgets('unlocking counts as the screen coming back', (t) async {
    await _boot(t);
    await _screen(t, 'screen_off');
    await _screen(t, 'user_present');
    await t.pump(const Duration(milliseconds: 300));

    expect(calls, contains('stopWatching'));
  });

  testWidgets('waking without ever sleeping is ignored', (t) async {
    await _boot(t);
    // A screen_on with no preceding screen_off — the phone was already awake.
    await _screen(t, 'screen_on');
    await t.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Waiting for the screen to go off'),
        findsOneWidget,
        reason: 'the button has to do both halves of its job');
  });

  testWidgets('the self-report appears only after the watch gives up',
      (t) async {
    await _boot(t);
    expect(find.text('Yes, it worked'), findsNothing);

    await t.pump(const Duration(seconds: 46));
    await t.pump();

    expect(find.text('Yes, it worked'), findsOneWidget,
        reason: 'some OEM builds never broadcast screen state to a paused '
            'app, and a seller should not be stuck because of it');
    expect(find.textContaining('could not detect'), findsOneWidget);
  });
}
