// Whether the phone can actually get online over mobile data.
//
// The failure this catches: a SIM that registers, shows full bars, and has no
// working data — an unpaid bill, an APN that never provisioned, data switched
// off for that SIM. An ordinary connectivity check cannot see it, because an
// HTTP request goes out over whatever route Android picks, and on a phone
// connected to Wi-Fi that proves only that Wi-Fi works.
//
// So the thing worth testing here is that Wi-Fi never rescues a dead mobile
// data connection.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/models/checkup_result.dart';
import 'package:french_mobiles/screens/checkup/checkup_entry_page.dart';
import 'package:french_mobiles/screens/checkup/internet_test_page.dart';

const _internet = MethodChannel('french_mobiles/internet');
const _connectivity =
    MethodChannel('dev.fluttercommunity.plus/connectivity');

/// Drives the native cellular probe's reply.
void _cellularReplies(Map<String, dynamic> reply) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_internet, (call) async {
    if (call.method == 'probeCellular') return reply;
    return null;
  });
}

/// connectivity_plus reporting what the phone is attached to.
void _connectedTo(List<String> types) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_connectivity, (call) async {
    if (call.method == 'check') return types;
    return null;
  });
}

Future<CheckupResult?> _run(WidgetTester t) async {
  t.view.physicalSize = const Size(400, 800);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);

  CheckupResult? popped;
  await t.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async {
            popped = await Navigator.of(context).push<CheckupResult>(
              MaterialPageRoute(builder: (_) => const InternetTestPage()),
            );
          },
          child: const Text('go'),
        ),
      ),
    ),
  ));

  await t.tap(find.text('go'));
  await t.pumpAndSettle();
  // The shared flow shows a verdict and auto-pops after 1500ms.
  await t.pump(const Duration(milliseconds: 1600));
  await t.pumpAndSettle();
  return popped;
}

void main() {
  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_internet, null);
    messenger.setMockMethodCallHandler(_connectivity, null);
  });

  testWidgets('working mobile data passes', (t) async {
    _cellularReplies({'status': 'ok', 'code': 204, 'ms': 120});
    _connectedTo(['wifi']);

    final result = await _run(t);

    expect(result?.status, CheckupStatus.pass);
    expect(result?.detail, contains('120ms'));
  });

  testWidgets('dead mobile data fails even with Wi-Fi working', (t) async {
    // The whole point: this phone is online, and its data is still broken.
    _cellularReplies({'status': 'unreachable', 'message': 'timed out'});
    _connectedTo(['wifi']);

    final result = await _run(t);

    expect(result?.status, CheckupStatus.fail,
        reason: 'Wi-Fi working says nothing about the SIM, and treating it '
            'as a pass is the bug this test exists for');
    expect(result?.detail, contains('mobile data'));
  });

  testWidgets('a sign-in portal is not a working connection', (t) async {
    _cellularReplies({'status': 'captive', 'code': 200});
    _connectedTo(['mobile']);

    final result = await _run(t);

    expect(result?.status, CheckupStatus.fail,
        reason: 'something answered, but it was not the internet');
  });

  testWidgets('no SIM is not a failure', (t) async {
    _cellularReplies({'status': 'no_cellular'});
    _connectedTo(['wifi']);

    final result = await _run(t);

    expect(result?.status, CheckupStatus.notAvailable,
        reason: 'a phone handed in without a SIM cannot be tested this way, '
            'which is not the same as being broken');
  });

  testWidgets('a platform without the channel does not fail the phone',
      (t) async {
    // iOS: nothing implements the channel, so it throws rather than replying.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_internet, (call) async {
      throw MissingPluginException('no implementation');
    });
    _connectedTo(['wifi']);

    final result = await _run(t);

    expect(result?.status, CheckupStatus.notAvailable);
  });

  test('the test is registered once, next to the mobile network test', () {
    final keys = CheckupEntryPage.specs.map((s) => s.key).toList();

    expect(keys.where((k) => k == 'internet').length, 1);
    expect(keys.indexOf('internet'), keys.indexOf('network') + 1,
        reason: 'one reads the SIM, the next asks whether it carries data');
  });
}
