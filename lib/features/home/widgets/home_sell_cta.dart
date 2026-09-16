import 'package:flutter/material.dart';

import 'package:french_mobiles/shared/theme/app_colors.dart';
import 'package:french_mobiles/shared/theme/app_text_styles.dart';
import 'package:french_mobiles/shared/theme/app_theme.dart';
import 'package:french_mobiles/shared/widgets/app_primary_button.dart';

/// The home screen's primary conversion surface: sell a device.
///
/// The one accent surface on the screen (surface level `accent`). Everything
/// else on home sits on the page or is a raised product card, so this tinted
/// panel is what the eye lands on first — which is correct, because selling a
/// phone is what the app is for.
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
        color: AppColors.primarySoft,
        borderRadius: AppRadius.card,
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
                  color: AppColors.surface,
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
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.onPrimarySoft,
                      ),
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
