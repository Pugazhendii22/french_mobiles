import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';

/// A single-choice row: title, optional trailing text, and a radio mark.
class AppSelectableTile extends StatelessWidget {
  const AppSelectableTile({
    super.key,
    required this.title,
    required this.selected,
    this.subtitle,
    this.trailingText,
    this.trailingLabel,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final String? trailingText;
  final String? trailingLabel;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.card,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySoft : AppColors.surface,
            borderRadius: AppRadius.card,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              _Radio(selected: selected),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: AppTextStyles.bodyMedium),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: AppTextStyles.caption),
                    ],
                  ],
                ),
              ),
              if (trailingText != null) ...[
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (trailingLabel != null)
                      Text(trailingLabel!, style: AppTextStyles.caption),
                    Text(trailingText!, style: AppTextStyles.price),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: 20,
      width: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.primary : AppColors.transparent,
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.borderStrong,
          width: 2,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 13, color: AppColors.onPrimary)
          : null,
    );
  }
}
