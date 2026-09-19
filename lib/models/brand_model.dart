import 'package:flutter/material.dart';

class BrandModel {
  final String name;
  final String logoText;
  final Color themeColor;
  final Widget? logo;
  final String? logoImageUrl;
  final String? logoAssetPath;
  final Color? borderColor;
  final List<Color>? gradientColors;
  final List<double>? gradientStops;

  BrandModel({
    required this.name,
    required this.logoText,
    required this.themeColor,
    this.logo,
    this.logoImageUrl,
    this.logoAssetPath,
    this.borderColor,
    this.gradientColors,
    this.gradientStops,
  });

  /// Soft tinted border matching the brand-card demo look.
  Color get resolvedBorderColor =>
      borderColor ?? Color.lerp(Colors.white, themeColor, 0.28)!;

  /// Soft glow-band gradient: near-white top → color bloom → white seam.
  /// Peak tint is capped at a uniform level so no single brand card dominates
  /// regardless of how vivid its theme colour is.
  List<Color> get resolvedGradientColors =>
      gradientColors ??
      [
        Colors.white,
        Color.lerp(Colors.white, themeColor, 0.05)!,
        Color.lerp(Colors.white, themeColor, 0.22)!,
        Color.lerp(Colors.white, themeColor, 0.34)!,
        Color.lerp(Colors.white, themeColor, 0.22)!,
        Colors.white,
      ];

  List<double> get resolvedGradientStops =>
      gradientStops ?? const [0.0, 0.12, 0.5, 0.78, 0.9, 1.0];
}

// Apple: built-in Material icon.
const Widget appleLogo = Icon(Icons.apple, size: 56, color: Color(0xFF111827));

// Samsung: blue SAMSUNG wordmark.
const Widget samsungLogo = Text(
  'SAMSUNG',
  style: TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.5,
    color: Color(0xFF1D4ED8),
  ),
);

// Motorola: navy MOTO wordmark (flat, matches the other brand wordmarks).
const Widget motorolaLogo = Text(
  'MOTOROLA',
  style: TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.2,
    color: Color(0xFF334155),
  ),
);

// Oppo: green OPPO wordmark.
const Widget oppoLogo = Text(
  'OPPO',
  style: TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.2,
    color: Color(0xFF15803D),
  ),
);

// OnePlus: red-bordered "1+" badge next to ONEPLUS wordmark.
const Widget oneplusLogo = Row(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    SizedBox(
      width: 30,
      height: 30,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.fromBorderSide(
            BorderSide(color: Color(0xFFEB0028), width: 2),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '1',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFFEB0028),
                height: 1,
              ),
            ),
            Positioned(
              top: 2,
              right: 3,
              child: Text(
                '+',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFEB0028),
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    SizedBox(width: 6),
    Text(
      'ONE',
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: Color(0xFFEB0028),
      ),
    ),
    Text(
      'PLUS',
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: Colors.black,
      ),
    ),
  ],
);

// Xiaomi: Mi monogram + XIAOMI wordmark.
const Widget xiaomiLogo = Row(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    Text(
      'Mi',
      style: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w900,
        color: Color(0xFFEA580C),
      ),
    ),
    SizedBox(width: 5),
    Padding(
      padding: EdgeInsets.only(top: 6),
      child: Text(
        'XIAOMI',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFFEA580C),
        ),
      ),
    ),
  ],
);

// Vivo: blue vivo wordmark.
const Widget vivoLogo = Text(
  'vivo',
  style: TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    color: Color(0xFF2563EB),
  ),
);

// Realme: yellow realme wordmark.
const Widget realmeLogo = Text(
  'realme',
  style: TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    color: Color(0xFFCA8A04),
  ),
);

// Google: G monogram + Google wordmark.
const Widget googleLogo = Row(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    Text(
      'G',
      style: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w900,
        color: Color(0xFF4285F4),
      ),
    ),
    SizedBox(width: 3),
    Text(
      'oogle',
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: Color(0xFF4285F4),
      ),
    ),
  ],
);

// TODO: Replace this mock catalog with a backend/API response model.
// This is intentionally static while the app flow is being stabilized.
final List<BrandModel> brandData = [
  BrandModel(
    name: 'Samsung',
    logoText: 'SAMSUNG',
    themeColor: const Color(0xFF1D4ED8),
    logo: samsungLogo,
    logoImageUrl: 'https://logo.clearbit.com/samsung.com',
    logoAssetPath: 'assets/logos/samsung.svg',
  ),
  BrandModel(
    name: 'Motorola',
    logoText: 'M motorola',
    themeColor: const Color(0xFF334155),
    logo: motorolaLogo,
    logoImageUrl: 'https://logo.clearbit.com/motorola.com',
    logoAssetPath: 'assets/logos/motorola.svg',
  ),
  BrandModel(
    name: 'Oppo',
    logoText: 'oppo',
    themeColor: const Color(0xFF15803D),
    logo: oppoLogo,
    logoImageUrl: 'https://logo.clearbit.com/oppo.com',
    logoAssetPath: 'assets/logos/oppo.svg',
  ),
  BrandModel(
    name: 'Apple',
    logoText: 'Apple',
    themeColor: const Color(0xFF111827),
    logo: appleLogo,
    logoImageUrl: 'https://logo.clearbit.com/apple.com',
    logoAssetPath: 'assets/logos/apple.svg',
  ),
];

/// Secondary brands shown in the "More Brands" grid and the full brand list.
final List<BrandModel> moreBrandData = [
  BrandModel(
    name: 'OnePlus',
    logoText: 'OnePlus',
    themeColor: const Color(0xFFDC2626),
    logo: oneplusLogo,
    logoImageUrl: 'https://logo.clearbit.com/oneplus.com',
    logoAssetPath: 'assets/logos/oneplus.svg',
  ),
  BrandModel(
    name: 'Xiaomi',
    logoText: 'Xiaomi',
    themeColor: const Color(0xFFEA580C),
    logo: xiaomiLogo,
    logoImageUrl: 'https://logo.clearbit.com/mi.com',
    logoAssetPath: 'assets/logos/xiaomi.svg',
  ),
  BrandModel(
    name: 'Vivo',
    logoText: 'vivo',
    themeColor: const Color(0xFF2563EB),
    logo: vivoLogo,
    logoImageUrl: 'https://logo.clearbit.com/vivo.com',
    logoAssetPath: 'assets/logos/vivo.svg',
  ),
  BrandModel(
    name: 'Realme',
    logoText: 'realme',
    themeColor: const Color(0xFFCA8A04),
    logo: realmeLogo,
    logoImageUrl: 'https://logo.clearbit.com/realme.com',
  ),
  BrandModel(
    name: 'Google',
    logoText: 'Google',
    themeColor: const Color(0xFF059669),
    logo: googleLogo,
    logoImageUrl: 'https://logo.clearbit.com/google.com',
    logoAssetPath: 'assets/logos/google.svg',
  ),
];

/// Every brand shown on the sell flow, for the searchable full brand list.
final List<BrandModel> allBrandData = [
  ...brandData,
  ...moreBrandData,
];