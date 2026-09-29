import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';

/// Rounded search input used at the top of a screen.
///
/// Presentational only — it owns no query state. Pass [onChanged] to filter as
/// the user types, or [onTap] with `readOnly: true` to use it as a button that
/// opens a dedicated search screen.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText = 'Search',
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.readOnly = false,
    this.trailing,
  });

  final TextEditingController? controller;

  /// Lets a caller move focus here from elsewhere on the screen.
  final FocusNode? focusNode;

  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool readOnly;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.pill,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          const SizedBox(width: AppSpacing.lg),
          const Icon(Icons.search_rounded,
              size: 20, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              readOnly: readOnly,
              onTap: onTap,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              style: AppTextStyles.body,
              cursorColor: AppColors.primary,
              decoration: InputDecoration(
                isDense: true,
                hintText: hintText,
                hintStyle:
                    AppTextStyles.body.copyWith(color: AppColors.textTertiary),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: AppSpacing.md),
              ),
            ),
          ),
          if (trailing != null) trailing!,
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
    );
  }
}
