import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// A segmented progress bar for multi-step flows.
///
/// Segments rather than a continuous bar so the number of steps remaining
/// stays legible at a glance.
class AppStepProgress extends StatelessWidget {
  const AppStepProgress({
    super.key,
    required this.total,
    required this.current,
  });

  final int total;

  /// Zero-based index of the active step.
  final int current;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step ${current + 1} of $total',
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                height: 4,
                decoration: BoxDecoration(
                  color: i <= current ? AppColors.primary : AppColors.border,
                  borderRadius: AppRadius.pill,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
