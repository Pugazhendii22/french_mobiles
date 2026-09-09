import 'package:flutter_test/flutter_test.dart';

import 'package:french_mobiles/models/models.dart';

void main() {
  group('BrandLogo asset contract', () {
    test('brands with a real SVG logo expose logoAssetPath', () {
      const withAsset = {
        'Samsung',
        'Motorola',
        'Oppo',
        'Apple',
        'OnePlus',
        'Xiaomi',
        'Vivo',
        'Google',
      };
      const wordmarkOnly = {'Realme'};

      for (final brand in allBrandData) {
        final has = brand.logoAssetPath != null;
        if (withAsset.contains(brand.name)) {
          expect(has, isTrue,
              reason: '${brand.name} should have a logo asset');
          expect(brand.logoAssetPath, endsWith('.svg'));
        } else if (wordmarkOnly.contains(brand.name)) {
          expect(has, isFalse,
              reason: '${brand.name} should use the wordmark fallback');
        }
        // Catch brands not explicitly listed so the contract stays in sync.
        if (!withAsset.contains(brand.name) &&
            !wordmarkOnly.contains(brand.name)) {
          fail('${brand.name} is not categorized in the logo contract');
        }
      }
    });
  });
}
