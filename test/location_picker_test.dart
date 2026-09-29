// The map picker for choosing a pickup point.
//
// Tiles never load under flutter_test — there is no network — so what is
// checked is the part that does not need them: that the page lays out over a
// tile layer that is failing, and that confirming hands back the point the
// pin is on. A picker that returns the wrong coordinates sends a courier to
// the wrong house.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/profile/location_picker_page.dart';

Future<PickedLocation?> _open(
  WidgetTester t, {
  double? lat = 12.9716,
  double? lng = 77.5946,
  Size size = const Size(400, 800),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);

  PickedLocation? picked;
  await t.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async {
            picked = await Navigator.of(context).push<PickedLocation>(
              MaterialPageRoute(
                builder: (_) => LocationPickerPage(
                  initialLatitude: lat,
                  initialLongitude: lng,
                ),
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    ),
  ));

  await t.tap(find.text('open'));
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
  return picked;
}

void main() {
  testWidgets('lays out on top of a tile layer that cannot load', (t) async {
    await _open(t);

    expect(find.text('Set location'), findsOneWidget);
    expect(find.text('Confirm location'), findsOneWidget);
    expect(find.text('PICKUP AT'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  // The OpenStreetMap credit this used to assert is gone with the tiles.
  // Google Maps draws its own attribution inside the native view, where no
  // widget test can see it — and the licence is satisfied by the SDK itself
  // rather than by anything this page builds.

  testWidgets('confirming returns the point the pin is on', (t) async {
    final picked = await _openAndConfirm(t);

    expect(picked, isNotNull);
    expect(picked!.latitude, closeTo(12.9716, 0.0001));
    expect(picked.longitude, closeTo(77.5946, 0.0001));
  });

  testWidgets('falls back to coordinates when no address resolves', (t) async {
    final picked = await _openAndConfirm(t);

    expect(picked!.address, contains('12.97160'),
        reason: 'offline, the coordinates are still a usable answer');
  });

  testWidgets('lays out on a narrow screen', (t) async {
    await _open(t, size: const Size(320, 640));
    expect(find.text('Confirm location'), findsOneWidget);
  });

  testWidgets('opens without a starting point', (t) async {
    // No saved pin: the page asks for the device location, which is
    // unavailable here. It must still render rather than fail.
    await _open(t, lat: null, lng: null);
    expect(find.text('Confirm location'), findsOneWidget);
  });
}

/// Opens the picker, confirms, and returns what it popped.
Future<PickedLocation?> _openAndConfirm(WidgetTester t) async {
  PickedLocation? picked;

  t.view.physicalSize = const Size(400, 800);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);

  await t.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async {
            picked = await Navigator.of(context).push<PickedLocation>(
              MaterialPageRoute(
                builder: (_) => const LocationPickerPage(
                  initialLatitude: 12.9716,
                  initialLongitude: 77.5946,
                ),
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    ),
  ));

  await t.tap(find.text('open'));
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
  await t.tap(find.text('Confirm location'));
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
  return picked;
}
