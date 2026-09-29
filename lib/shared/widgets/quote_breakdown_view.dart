import 'package:flutter/material.dart';

import '../../models/quote_breakdown.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import 'app_badge.dart';
import 'app_surface.dart';

/// The arithmetic behind a payout, shown line by line.
///
/// Used by both the wizard's last step and the checkout so the two can never
/// disagree about what was deducted — a seller who sees one total in the
/// wizard and a different one at checkout has no reason to believe either.
class QuoteBreakdownView extends StatelessWidget {
  const QuoteBreakdownView({
    super.key,
    required this.breakdown,
    this.showValidity = true,
  });

  final QuoteBreakdown breakdown;

  /// The validity line is worth stating once per screen, not twice.
  final bool showValidity;

  @override
  Widget build(BuildContext context) {
    final lines = breakdown.lines;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppGroup(
          bare: true,
          children: [
            _row(
              label: 'Base price',
              detail: 'What this model fetches in perfect condition',
              amount: '₹ ${breakdown.basePrice}',
            ),
            if (lines.isEmpty)
              _row(
                label: 'No deductions',
                detail: 'Nothing was reported that reduces the value',
                amount: '₹ 0',
                amountColor: AppColors.success,
              )
            else
              for (final line in lines)
                _row(
                  label: line.category,
                  detail: line.choice,
                  amount: '− ₹ ${line.amount}',
                  badge: '${line.percent}%',
                  amountColor: AppColors.error,
                ),
            _total(),
          ],
        ),
        if (breakdown.floored) ...[
          const SizedBox(height: AppSpacing.md),
          _note(
            icon: Icons.info_outline_rounded,
            tone: AppColors.warning,
            // Saying this out loud is the point: without it the numbers above
            // visibly fail to add up and the whole table looks wrong.
            text: 'The deductions above come to more than the device is worth, '
                'so this quote is our minimum offer rather than the sum of '
                'them.',
          ),
        ],
        if (showValidity) ...[
          const SizedBox(height: AppSpacing.md),
          _validity(),
        ],
      ],
    );
  }

  Widget _row({
    required String label,
    required String detail,
    required String amount,
    String? badge,
    Color? amountColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      AppBadge(label: badge, tone: AppBadgeTone.neutral),
                    ],
                  ],
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            amount,
            style: AppTextStyles.bodyMedium.copyWith(color: amountColor),
          ),
        ],
      ),
    );
  }

  Widget _total() {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text('You receive', style: AppTextStyles.bodyMedium),
          ),
          Text(
            '₹ ${breakdown.finalPayout}',
            style: AppTextStyles.h3.copyWith(color: AppColors.onPrimarySoft),
          ),
        ],
      ),
    );
  }

  Widget _validity() {
    final days = breakdown.daysRemaining;
    final expired = breakdown.isExpired;

    return _note(
      icon: expired ? Icons.schedule_rounded : Icons.verified_outlined,
      tone: expired ? AppColors.error : AppColors.textSecondary,
      text: expired
          ? 'This quote has expired. Run the check again for a current price.'
          : days == 0
              ? 'This price is held until the end of today.'
              : 'This price is held for '
                  '${days == 1 ? '1 more day' : '$days more days'}.',
    );
  }

  Widget _note({
    required IconData icon,
    required Color tone,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: tone),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(text, style: AppTextStyles.caption.copyWith(color: tone)),
        ),
      ],
    );
  }
}
