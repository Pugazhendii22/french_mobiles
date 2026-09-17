// Layout smoke tests for the nine original checkup test pages, plus the
// shared chrome they were migrated onto.
//
// These pages drive real hardware (camera, sensors, bluetooth, wifi), which is
// unavailable under flutter_test, so each is pumped only far enough to prove
// its first frame lays out. That is the failure mode worth guarding: a layout
// assertion renders blank rather than erroring, so it survives both
// `flutter analyze` and `flutter build` — neither runs a layout pass.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/models/checkup_result.dart';
import 'package:french_mobiles/screens/checkup/biometric_test_page.dart';
import 'package:french_mobiles/screens/checkup/bluetooth_test_page.dart';
import 'package:french_mobiles/screens/checkup/buttons_test_page.dart';
import 'package:french_mobiles/screens/checkup/camera_test_page.dart';
import 'package:french_mobiles/screens/checkup/checkup_test_shell.dart';
import 'package:french_mobiles/screens/checkup/display_test_page.dart';
import 'package:french_mobiles/screens/checkup/gyroscope_test_page.dart';
import 'package:french_mobiles/screens/checkup/location_test_page.dart';
import 'package:french_mobiles/screens/checkup/network_test_page.dart';
import 'package:french_mobiles/screens/checkup/wifi_test_page.dart';

Future<void> _boot(WidgetTester t, Widget page, {required Size size}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(home: page));
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  /// Every test page, and the header title each should show once migrated
  /// onto the shared shell. Display is absent: it opens on a full-screen
  /// colour sweep and only adopts the chrome for its verdict.
  final pages = <String, (Widget Function(), String?)>{
    'biometric': (() => const BiometricTestPage(), 'Checkup · Biometric'),
    'bluetooth': (() => const BluetoothTestPage(), 'Checkup · Bluetooth'),
    'buttons': (() => const ButtonsTestPage(), 'Checkup · Side buttons'),
    'camera': (() => const CameraTestPage(), 'Checkup · Camera'),
    'display': (() => const DisplayTestPage(), null),
    'gyroscope': (() => const GyroscopeTestPage(), 'Checkup · Gyroscope'),
    'location': (() => const LocationTestPage(), 'Checkup · Location'),
    'network': (() => const NetworkTestPage(), 'Checkup · Mobile network'),
    'wifi': (() => const WifiTestPage(), 'Checkup · Wi-Fi'),
  };

  pages.forEach((name, entry) {
    final (build, title) = entry;

    testWidgets('$name lays out', (t) async {
      await _boot(t, build(), size: const Size(400, 800));
      if (title != null) {
        expect(find.text(title), findsOneWidget,
            reason: '$name should wear the shared checkup chrome');
      }
    });

    testWidgets('$name lays out on a narrow screen', (t) async {
      // 320 is the narrowest phone still in circulation; a row that only
      // just fits at 400 clips here.
      await _boot(t, build(), size: const Size(320, 640));
    });
  });

  group('CheckupVerdict', () {
    const result = CheckupResult(
      key: 'wifi',
      title: 'Wi-Fi',
      status: CheckupStatus.fail,
      detail: 'Permission permanently denied',
    );

    testWidgets('renders the status and detail', (t) async {
      await _boot(t, const Scaffold(body: CheckupVerdict(result: result)),
          size: const Size(400, 800));
      expect(find.text('FAIL'), findsOneWidget);
      expect(find.text('Permission permanently denied'), findsOneWidget);
    });

    testWidgets('offers no action unless one is given', (t) async {
      await _boot(t, const Scaffold(body: CheckupVerdict(result: result)),
          size: const Size(400, 800));
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('a permission verdict offers settings and a way past it',
        (t) async {
      var openedSettings = false;
      var continued = false;

      await _boot(
        t,
        Scaffold(
          body: CheckupVerdict(
            result: result,
            action: CheckupPermissionAction(
              onOpenSettings: () => openedSettings = true,
              onContinue: () => continued = true,
            ),
          ),
        ),
        size: const Size(400, 800),
      );

      await t.tap(find.text('Open Settings'));
      await t.tap(find.text('Continue without it'));
      await t.pump();

      expect(openedSettings, isTrue);
      expect(continued, isTrue,
          reason: 'a held verdict must offer a way onward, or the checkup '
              'stops dead on a denied permission');
    });
  });
}
