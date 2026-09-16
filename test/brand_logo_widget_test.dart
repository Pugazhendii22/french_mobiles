import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:french_mobiles/models/models.dart';
import 'package:french_mobiles/shared/widgets/widgets.dart';

/// In-memory asset bundle so SvgPicture.asset can find the declared asset.
class _FakeAssetBundle extends CachingAssetBundle {
  final Map<String, ByteData> _assets;
  _FakeAssetBundle(this._assets);

  @override
  Future<ByteData> load(String key) async {
    final data = _assets[key];
    if (data == null) {
      throw FlutterError('Asset not found: $key');
    }
    return data;
  }
}

final _svgBytes = ByteData(
  3 * 4 + _simpleSvg.codeUnits.length,
)..buffer.asUint8List().setAll(0, _simpleSvg.codeUnits);

const _simpleSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
    '<circle cx="12" cy="12" r="10" fill="#000000"/></svg>';

final _samsung = BrandModel(
  name: 'Samsung',
  discountText: '',
  logoText: 'SAMSUNG',
  themeColor: const Color(0xFF1D4ED8),
  logoAssetPath: 'assets/logos/samsung.svg',
);

final _realmeBrand = BrandModel(
  name: 'Realme',
  discountText: '',
  logoText: 'realme',
  themeColor: const Color(0xFFCA8A04),
);

void main() {
  testWidgets('AppBrandLogo with asset renders SvgPicture, not wordmark text',
      (tester) async {
    final assets = <String, ByteData>{
      'assets/logos/samsung.svg': _svgBytes,
      'assets/logos/motorola.svg': _svgBytes,
    };
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: _FakeAssetBundle(assets),
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AppBrandLogo(brand: _samsung),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SvgPicture), findsWidgets,
        reason: 'Samsung has a logo asset so it should render an SVG');
    // The wordmark fallback text for Samsung should NOT be present.
    expect(
      find.descendant(
        of: find.byType(AppBrandLogo),
        matching: find.text('Samsung'),
      ),
      findsNothing,
      reason: 'Wordmark fallback should not render when an asset exists',
    );
  });

  testWidgets('AppBrandLogo without asset renders wordmark text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppBrandLogo(brand: _realmeBrand),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Realme'), findsOneWidget,
        reason: 'Realme has no asset so it should render the wordmark');
  });
}
