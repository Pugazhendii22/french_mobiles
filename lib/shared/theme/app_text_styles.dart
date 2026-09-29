import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// The single source of truth for typography.
///
/// Every style is Poppins via `google_fonts`. Call sites should use these
/// constants and adjust with `.copyWith(...)` rather than building a bare
/// [TextStyle], so weight and tracking stay consistent across screens.
class AppTextStyles {
  AppTextStyles._();

  /// Line heights are expressed in logical pixels and converted to the
  /// multiplier Flutter expects, so the numbers here match a design spec.
  static TextStyle _poppins({
    required double size,
    required double lineHeight,
    required FontWeight weight,
    Color color = AppColors.textPrimary,
    double? letterSpacing,
  }) {
    return GoogleFonts.poppins(
      fontSize: size,
      height: lineHeight / size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  // --- Display / headings ------------------------------------------------
  static TextStyle get h1 => _poppins(
        size: 24,
        lineHeight: 32,
        weight: FontWeight.w600,
        letterSpacing: -0.4,
      );

  static TextStyle get h2 => _poppins(
        size: 20,
        lineHeight: 28,
        weight: FontWeight.w600,
        letterSpacing: -0.3,
      );

  /// Section titles ("Recently added", "Browse by category").
  static TextStyle get h3 => _poppins(
        size: 16,
        lineHeight: 24,
        weight: FontWeight.w600,
        letterSpacing: -0.2,
      );

  // --- Body --------------------------------------------------------------
  static TextStyle get bodyLarge =>
      _poppins(size: 15, lineHeight: 22, weight: FontWeight.w400);

  static TextStyle get body =>
      _poppins(size: 14, lineHeight: 20, weight: FontWeight.w400);

  static TextStyle get bodySmall => _poppins(
        size: 12,
        lineHeight: 18,
        weight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  /// Body copy that needs to carry weight without becoming a heading.
  static TextStyle get bodyMedium =>
      _poppins(size: 14, lineHeight: 20, weight: FontWeight.w500);

  // --- UI ----------------------------------------------------------------
  static TextStyle get button => _poppins(
        size: 15,
        lineHeight: 20,
        weight: FontWeight.w600,
        color: AppColors.onPrimary,
        letterSpacing: 0.1,
      );

  static TextStyle get label => _poppins(
        size: 13,
        lineHeight: 18,
        weight: FontWeight.w500,
      );

  /// Captions, helper text, timestamps.
  static TextStyle get caption => _poppins(
        size: 11,
        lineHeight: 16,
        weight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  /// Uppercase micro-labels inside badges and pills.
  static TextStyle get overline => _poppins(
        size: 10,
        lineHeight: 14,
        weight: FontWeight.w600,
        letterSpacing: 0.6,
      );

  /// Prices and other figures that should not reflow when digits change.
  static TextStyle get price => _poppins(
        size: 15,
        lineHeight: 20,
        weight: FontWeight.w600,
      ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  static TextStyle get priceSmall => _poppins(
        size: 13,
        lineHeight: 18,
        weight: FontWeight.w600,
      ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  /// Bottom-navigation item labels.
  static TextStyle get navLabel => _poppins(
        size: 10,
        lineHeight: 14,
        weight: FontWeight.w500,
      );
}
