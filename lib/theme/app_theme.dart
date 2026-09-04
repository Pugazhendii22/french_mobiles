import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colors extracted 1:1 from the Tailwind `theme.extend.colors` config
/// shared across all three screens.
class AppColors {
  AppColors._();

  static const surfaceContainerLow = Color(0xFFF0F3FF);
  static const primaryFixedDim = Color(0xFF4CE346);
  static const surface = Color(0xFFF9F9FF);
  static const outline = Color(0xFF6D7B67);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const onErrorContainer = Color(0xFF93000A);
  static const onTertiaryFixedVariant = Color(0xFF454748);
  static const surfaceDim = Color(0xFFD3DAEA);
  static const secondaryContainer = Color(0xFFE2E2E2);
  static const background = Color(0xFFF9F9FF);
  static const onPrimaryFixedVariant = Color(0xFF005306);
  static const secondaryFixedDim = Color(0xFFC6C6C6);
  static const inversePrimary = Color(0xFF4CE346);
  static const surfaceBright = Color(0xFFF9F9FF);
  static const primaryContainer = Color(0xFF32CD32);
  static const surfaceVariant = Color(0xFFDCE2F3);
  static const onBackground = Color(0xFF151C27);
  static const surfaceContainerHighest = Color(0xFFDCE2F3);
  static const outlineVariant = Color(0xFFBCCBB4);
  static const onTertiaryFixed = Color(0xFF191C1D);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onSecondaryContainer = Color(0xFF646464);
  static const onSecondaryFixed = Color(0xFF1B1B1B);
  static const onSurface = Color(0xFF151C27);
  static const tertiaryFixedDim = Color(0xFFC5C7C8);
  static const tertiaryContainer = Color(0xFFB0B2B3);
  static const tertiaryFixed = Color(0xFFE1E3E4);
  static const onSecondary = Color(0xFFFFFFFF);
  static const inverseOnSurface = Color(0xFFEBF1FF);
  static const primary = Color(0xFF006E0A);
  static const inverseSurface = Color(0xFF2A313D);
  static const onError = Color(0xFFFFFFFF);
  static const onPrimaryFixed = Color(0xFF002201);
  static const tertiary = Color(0xFF5C5F60);
  static const onTertiaryContainer = Color(0xFF424546);
  static const surfaceContainerHigh = Color(0xFFE2E8F8);
  static const onTertiary = Color(0xFFFFFFFF);
  static const surfaceContainer = Color(0xFFE7EEFE);
  static const onSecondaryFixedVariant = Color(0xFF474747);
  static const secondary = Color(0xFF5E5E5E);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryFixed = Color(0xFF75FF68);
  static const error = Color(0xFFBA1A1A);
  static const secondaryFixed = Color(0xFFE2E2E2);
  static const onPrimaryContainer = Color(0xFF005105);
  static const surfaceTint = Color(0xFF006E0A);
  static const onSurfaceVariant = Color(0xFF3D4A39);
}

/// Spacing scale from `theme.extend.spacing`.
class AppSpacing {
  AppSpacing._();

  static const base = 8.0;
  static const gutter = 16.0;
  static const containerPadding = 20.0;
  static const stackSm = 12.0;
  static const stackMd = 24.0;
  static const stackLg = 40.0;
}

/// Border radii from `theme.extend.borderRadius`.
class AppRadius {
  AppRadius._();

  static const dflt = 4.0; // DEFAULT: 0.25rem
  static const lg = 8.0; // 0.5rem
  static const xl = 12.0; // 0.75rem
  static const card = 16.0; // used on Select Device screen
  static const input = 12.0; // used on Select Device screen
  static const full = 9999.0;
}

/// Text styles from `theme.extend.fontSize`, all on the Hanken Grotesk
/// family declared in `theme.extend.fontFamily`.
class AppText {
  AppText._();

  static TextStyle _hanken({
    required double size,
    required double height,
    required FontWeight weight,
    double? letterSpacing,
    Color? color,
  }) {
    return GoogleFonts.hankenGrotesk(
      fontSize: size,
      height: height / size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  static TextStyle headlineLgMobile({Color? color}) => _hanken(
        size: 22,
        height: 28,
        weight: FontWeight.w700,
        color: color,
      );

  static TextStyle bodySm({Color? color}) => _hanken(
        size: 14,
        height: 20,
        weight: FontWeight.w400,
        color: color,
      );

  static TextStyle headlineMd({Color? color}) => _hanken(
        size: 20,
        height: 28,
        weight: FontWeight.w700,
        color: color,
      );

  static TextStyle headlineLg({Color? color}) => _hanken(
        size: 24,
        height: 32,
        weight: FontWeight.w700,
        color: color,
      );

  static TextStyle displayPrice({Color? color}) => _hanken(
        size: 32,
        height: 40,
        weight: FontWeight.w800,
        letterSpacing: -0.02 * 32,
        color: color,
      );

  static TextStyle labelBold({Color? color}) => _hanken(
        size: 12,
        height: 16,
        weight: FontWeight.w700,
        color: color,
      );

  static TextStyle bodyLg({Color? color}) => _hanken(
        size: 16,
        height: 24,
        weight: FontWeight.w400,
        color: color,
      );
}

/// Shared shadows (`.card-shadow` / `.fab-shadow` / boxShadow.card / .fab).
class AppShadows {
  AppShadows._();

  static const card = [
    BoxShadow(
      color: Color(0x0D000000), // rgba(0,0,0,0.05)
      blurRadius: 20,
      offset: Offset(0, 4),
    ),
  ];

  static const fab = [
    BoxShadow(
      color: Color(0x1A000000), // rgba(0,0,0,0.1)
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  static const bottomNav = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 20,
      offset: Offset(0, -4),
    ),
  ];
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      background: AppColors.background,
      surface: AppColors.surface,
    ),
    textTheme: GoogleFonts.hankenGroteskTextTheme(),
  );
}
