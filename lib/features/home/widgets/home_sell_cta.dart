import 'package:flutter/material.dart';

import 'package:french_mobiles/shared/theme/app_colors.dart';
import 'package:french_mobiles/shared/theme/app_text_styles.dart';
import 'package:french_mobiles/shared/theme/app_theme.dart';
import 'package:french_mobiles/shared/widgets/app_primary_button.dart';

/// The home screen's primary conversion surface: sell a device.
///
/// A white card rather than a lime panel — the brand colour stays on the
/// button, where it reads as the action to take, instead of becoming a
/// full-bleed background that competes with the listings below.
class HomeSellCta extends StatelessWidget {
  const HomeSellCta({
    super.key,
    required this.onSellTap,
    required this.onCheckupTap,
  });

  final VoidCallback onSellTap;
  final VoidCallback onCheckupTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.sell_rounded,
                  size: 20,
                  color: AppColors.onPrimarySoft,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Sell your old phone', style: AppTextStyles.h3),
                    const SizedBox(height: 2),
                    Text(
                      'Instant quote, free doorstep pickup',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppPrimaryButton(
            label: 'Sell Phone',
            icon: Icons.arrow_forward_rounded,
            onPressed: onSellTap,
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: onCheckupTap,
              icon: const Icon(
                Icons.health_and_safety_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              label: Text(
                'Run a free device checkup',
                style: AppTextStyles.label.copyWith(color: AppColors.primary),
              ),
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
