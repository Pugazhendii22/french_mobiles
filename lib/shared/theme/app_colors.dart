import 'package:flutter/material.dart';

/// The single source of truth for colour in the app.
///
/// Nothing outside this file should construct a [Color] literal. If a shade is
/// missing here, add it here rather than inlining it at the call site.
class AppColors {
  AppColors._();

  // --- Brand -------------------------------------------------------------
  /// Lime green. Buttons, active states, links and accents only.
  ///
  /// Deliberately never used as a full-page background: at this saturation it
  /// overwhelms content and drags contrast on white text below AA.
  static const Color primary = Color(0xFF32CD32);

  /// Pressed / hovered states for [primary] surfaces.
  static const Color primaryDark = Color(0xFF28A428);

  /// Tinted fill for chips, badges and selected tiles.
  static const Color primarySoft = Color(0xFFE8F9E8);

  /// Readable text/icon colour on top of [primarySoft].
  static const Color onPrimarySoft = Color(0xFF1B7A1B);

  /// Foreground on a solid [primary] fill.
  static const Color onPrimary = Color(0xFFFFFFFF);

  // --- Surfaces ----------------------------------------------------------
  static const Color background = Color(0xFFF7F8F8);
  static const Color surface = Color(0xFFFFFFFF);

  /// A slightly recessed surface for search fields and inert tiles.
  static const Color surfaceMuted = Color(0xFFF2F3F3);

  // --- Text --------------------------------------------------------------
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B7280);

  /// For hints and disabled labels. Sits below body contrast on purpose.
  static const Color textTertiary = Color(0xFF9CA3AF);

  static const Color onSurfaceInverse = Color(0xFFFFFFFF);

  // --- Lines -------------------------------------------------------------
  static const Color border = Color(0xFFEEEEEE);

  /// A marginally stronger rule for dividers that must read against cards.
  static const Color borderStrong = Color(0xFFE2E4E4);

  // --- Status ------------------------------------------------------------
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  static const Color successSoft = Color(0xFFE7F8ED);
  static const Color warningSoft = Color(0xFFFEF3E2);
  static const Color errorSoft = Color(0xFFFDECEC);

  // --- Effects -----------------------------------------------------------
  /// Card shadow. Kept very low-alpha: on a #F7F8F8 ground a heavier shadow
  /// reads as a grey halo rather than lift.
  static const Color shadow = Color(0x0D000000);

  /// A touch stronger, for surfaces that float above the page.
  static const Color shadowRaised = Color(0x14000000);

  /// Tinted lift under a solid [primary] fill — a neutral shadow under a
  /// saturated colour reads as muddy.
  static const Color shadowPrimary = Color(0x3332CD32);

  static const Color scrim = Color(0x66000000);

  /// Named so that call sites never reach for `Colors.transparent` directly.
  static const Color transparent = Color(0x00000000);
}
