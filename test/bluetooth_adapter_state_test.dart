// What the Bluetooth test does about each adapter state.
//
// The bug this exists for: the test read the adapter's first reported state
// and treated anything that was not `on` as off. But the first value can be
// `unknown` before the platform has answered, and `turningOn` while the radio
// is coming up on its own. Asking the OS to enable an already-enabling radio
// produced a prompt that threw or vanished, which the test then reported as
// the user declining — a failure on hardware that worked.
//
// The radio itself cannot be driven from a test, so the decision is separated
// from the flow and checked here instead.
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/screens/checkup/bluetooth_test_page.dart';

void main() {
  test('an adapter that is on is simply used', () {
    expect(actionForAdapterState(BluetoothAdapterState.on),
        AdapterAction.proceed);
  });

  test('a radio already coming up is waited for, not asked again', () {
    expect(actionForAdapterState(BluetoothAdapterState.turningOn),
        AdapterAction.waitForOn,
        reason: 'this is the state that produced the false failure');
  });

  test('an unanswered platform is waited for rather than assumed off', () {
    expect(actionForAdapterState(BluetoothAdapterState.unknown),
        AdapterAction.waitForOn,
        reason: 'unknown means the OS has not replied yet, not that the '
            'radio is off');
  });

  test('a radio that is genuinely off asks the user', () {
    expect(actionForAdapterState(BluetoothAdapterState.off),
        AdapterAction.requestTurnOn);
  });

  test('a radio going down is treated as off', () {
    expect(actionForAdapterState(BluetoothAdapterState.turningOff),
        AdapterAction.requestTurnOn);
  });

  test('a device with no radio is not a failure', () {
    expect(actionForAdapterState(BluetoothAdapterState.unavailable),
        AdapterAction.unavailable,
        reason: 'no hardware is "not applicable", not "broken"');
  });

  test('a permission problem is reported as one', () {
    expect(actionForAdapterState(BluetoothAdapterState.unauthorized),
        AdapterAction.unauthorized);
  });

  test('every adapter state is handled', () {
    // A new state added by the plugin should surface here rather than falling
    // into whatever branch happens to be last.
    for (final state in BluetoothAdapterState.values) {
      expect(() => actionForAdapterState(state), returnsNormally,
          reason: '$state has no decision');
    }
  });

  test('only a settled "on" leads to scanning', () {
    final scanning = BluetoothAdapterState.values
        .where((s) => actionForAdapterState(s) == AdapterAction.proceed);

    expect(scanning, [BluetoothAdapterState.on],
        reason: 'scanning on any other state is what produced flaky results');
  });
}
