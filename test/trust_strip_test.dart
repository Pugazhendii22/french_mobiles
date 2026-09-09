import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/home_screen.dart';

void main() {
  testWidgets('resting arrangement starts at container 1', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HomeTrustStrip())),
    );
    await tester.pump(); // value == 0.0 -> initial rest

    const gap = 8.0;
    const edgePad = 16.0;
    final width = 360 - edgePad * 2; // 328
    final pitch = width / 3;
    final centers = [
      edgePad + pitch / 2,
      edgePad + pitch + pitch / 2,
      edgePad + 2 * pitch + pitch / 2,
    ];

    const labels = ['Certified', 'Doorstep', 'Fair price'];
    for (var i = 0; i < labels.length; i++) {
      final center = tester.getCenter(find.text(labels[i]));
      // ignore: avoid_print
      print('${labels[i]} at t=0 => x=${center.dx.toStringAsFixed(1)} '
          '(expected ${centers[i].toStringAsFixed(1)})');
      expect(center.dx, closeTo(centers[i], 0.5));
    }

    // During the first jump (starts at 1250ms, ends 1750ms) the contents
    // must shift right by one card and land as 3->1, 1->2, 2->3.
    await tester.pump(const Duration(milliseconds: 1300));
    final certNetMove = tester.getCenter(find.text('Certified')).dx - centers[0];
    final fairNetMove =
        tester.getCenter(find.text('Fair price')).dx - centers[2];
    expect(certNetMove, greaterThan(0)); // Certified moving right
    expect(fairNetMove, lessThan(0)); // Fair price moving left (wrap)

    await tester.pump(const Duration(milliseconds: 550)); // 1850ms total
    final after = [
      tester.getCenter(find.text('Certified')).dx,
      tester.getCenter(find.text('Doorstep')).dx,
      tester.getCenter(find.text('Fair price')).dx,
    ];
    // ignore: avoid_print
    print('after jump1 -> ${after.map((x) => x.toStringAsFixed(1)).toList()}');
    expect(after[0], closeTo(centers[1], 0.5)); // Certified in card 2
    expect(after[1], closeTo(centers[2], 0.5)); // Doorstep in card 3
    expect(after[2], closeTo(centers[0], 0.5)); // Fair price in card 1
  });
}