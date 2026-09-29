// Permissions the app cannot work without.
//
// INTERNET was declared only in the debug and profile manifests, which merge
// into those builds alone. A release APK therefore had no network at all:
// Firestore, the profile photo upload, address geocoding and the map tiles
// would every one fail, and only in the build nobody runs from an IDE.
//
// A manifest is not covered by any widget test and is easy to regenerate, so
// the permissions the app genuinely depends on are pinned here.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml');

  late String xml;

  setUpAll(() {
    expect(manifest.existsSync(), isTrue,
        reason: 'run from the package root: ${manifest.absolute.path}');
    xml = manifest.readAsStringSync();
  });

  /// Matches a declaration regardless of attribute order or extra flags.
  void expectPermission(String name, {required String because}) {
    expect(xml, contains('android:name="android.permission.$name"'),
        reason: because);
  }

  test('INTERNET is declared in the main manifest, not just debug', () {
    expectPermission('INTERNET',
        because: 'without it a release build has no network: Firestore, the '
            'photo upload, geocoding and map tiles all fail');
  });

  test('the checkup can reach the hardware it tests', () {
    expectPermission('CAMERA', because: 'camera and flashlight tests');
    expectPermission('RECORD_AUDIO', because: 'microphone test');
    expectPermission('VIBRATE', because: 'vibration motor test');
    expectPermission('WAKE_LOCK',
        because: 'the proximity test blanks the screen as a call does');
    expectPermission('READ_PHONE_STATE', because: 'mobile network test');
    expectPermission('ACCESS_WIFI_STATE', because: 'Wi-Fi scan');
    expectPermission('BLUETOOTH_SCAN', because: 'Bluetooth test');
    expectPermission('BLUETOOTH_CONNECT', because: 'Bluetooth adapter state');
  });

  test('location is declared for GPS, Wi-Fi scanning and the map', () {
    expectPermission('ACCESS_FINE_LOCATION',
        because: 'the GPS test needs a real fix');
    expectPermission('ACCESS_COARSE_LOCATION',
        because: 'Android requires location to scan for Wi-Fi');
  });

  test('debug and profile manifests exist and are not the only source', () {
    // They legitimately add INTERNET for tooling; the point is that main
    // no longer depends on them for it.
    for (final variant in ['debug', 'profile']) {
      final file = File('android/app/src/$variant/AndroidManifest.xml');
      expect(file.existsSync(), isTrue, reason: '$variant manifest missing');
    }
  });
}
