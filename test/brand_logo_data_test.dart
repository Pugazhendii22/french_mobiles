// The brand cards' logo contract.
//
// Checked against the assets folder rather than a list of brand names typed
// into the test. The old version named every brand it expected to have an
// SVG, so adding a logo meant editing the test too — and forgetting to meant
// a red suite rather than a missing picture. What actually matters is that
// every path a card will try to load is really on disk: a typo there shows
// up as a silently blank card, because BrandLogo falls back to the wordmark
// without complaining.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/models/models.dart';

const _logoDir = 'assets/logos';

void main() {
  group('BrandLogo asset contract', () {
    test('every declared logo file exists', () {
      for (final brand in allBrandData) {
        final path = brand.logoAssetPath;
        if (path == null) continue;

        expect(
          File(path).existsSync(),
          isTrue,
          reason: '${brand.name} points at $path, which is not in the repo — '
              'the card will quietly fall back to a wordmark',
        );
      }
    });

    test('logos live in the assets folder and are SVGs', () {
      for (final brand in allBrandData) {
        final path = brand.logoAssetPath;
        if (path == null) continue;

        expect(path, startsWith('$_logoDir/'),
            reason: '${brand.name} is outside the declared asset folder');
        expect(path, endsWith('.svg'), reason: '${brand.name} is not an SVG');
      }
    });

    test('a brand with no logo file can still draw a wordmark', () {
      for (final brand in allBrandData) {
        if (brand.logoAssetPath != null) continue;
        expect(brand.logoText.trim(), isNotEmpty,
            reason: '${brand.name} has neither a logo nor anything to write '
                'in its place');
      }
    });

    test('no brand is listed twice', () {
      final names = allBrandData.map((b) => b.name).toList();
      expect(names.toSet().length, names.length,
          reason: 'a duplicate would render two identical cards');
    });

    test('the featured brands are also in the full list', () {
      // allBrandData is what the searchable list reads; a brand only in
      // brandData would be unreachable from search.
      final all = allBrandData.map((b) => b.name).toSet();
      for (final brand in brandData) {
        expect(all, contains(brand.name));
      }
      for (final brand in moreBrandData) {
        expect(all, contains(brand.name));
      }
    });
  });

  // Sony's logo arrived as a single white fill: correct on a dark background,
  // invisible on the white brand card, and completely silent about it — the
  // asset loads, it parses, it just draws nothing you can see.
  //
  // Checked by painting each one and counting pixels rather than by reading
  // the SVG's fill attributes. A first attempt did the latter and called iQOO
  // invisible when it renders perfectly well; what colour a shape ends up is
  // the product of nesting, inheritance and CSS, and only the renderer knows.
  testWidgets('every logo is actually visible on a white card', (t) async {
    for (final brand in allBrandData) {
      final path = brand.logoAssetPath;
      if (path == null) continue;

      final key = GlobalKey();
      var visible = 0;

      await t.runAsync(() async {
        await t.pumpWidget(Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            key: key,
            child: Container(
              width: 200,
              height: 100,
              color: const Color(0xFFFFFFFF),
              padding: const EdgeInsets.all(8),
              child: SvgPicture.asset(path),
            ),
          ),
        ));

        // Real I/O, so the frames have to be pumped against a real clock.
        for (var i = 0; i < 20; i++) {
          await t.pump(const Duration(milliseconds: 40));
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }

        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes =
            await image.toByteData(format: ui.ImageByteFormat.rawRgba);

        for (var i = 0; i < bytes!.lengthInBytes; i += 4) {
          final isWhite = bytes.getUint8(i) >= 240 &&
              bytes.getUint8(i + 1) >= 240 &&
              bytes.getUint8(i + 2) >= 240;
          if (!isWhite) visible++;
        }
      });

      expect(
        visible,
        greaterThan(200),
        reason: '${brand.name} drew almost nothing from $path — on the white '
            'brand card it will look like a missing logo',
      );
    }
  });
}
