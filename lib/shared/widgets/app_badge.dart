import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';

/// Tone presets for [AppBadge].
enum AppBadgeTone { primary, neutral, success, warning, error }

/// A small pill label for status and emphasis ("AI PICKS", "Soon", "5 left").
///
/// Tones map onto the soft/on pairs in [AppColors] rather than taking raw
/// colours, so every badge in the app stays within the palette.
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.tone = AppBadgeTone.neutral,
    this.icon,
  });

  final String label;
  final AppBadgeTone tone;
  final IconData? icon;

  (Color background, Color foreground) get _colors {
    switch (tone) {
      case AppBadgeTone.primary:
        return (AppColors.primarySoft, AppColors.onPrimarySoft);
      case AppBadgeTone.neutral:
        return (AppColors.surfaceMuted, AppColors.textSecondary);
      case AppBadgeTone.success:
        return (AppColors.successSoft, AppColors.success);
      case AppBadgeTone.warning:
        return (AppColors.warningSoft, AppColors.warning);
      case AppBadgeTone.error:
        return (AppColors.errorSoft, AppColors.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = _colors;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: foreground),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: AppTextStyles.overline.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}
