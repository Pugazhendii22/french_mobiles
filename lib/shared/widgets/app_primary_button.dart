import 'package:flutter/material.dart';

import '../motion/motion.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';

/// The app's primary call-to-action.
///
/// Solid [AppColors.primary] with a tinted lift. Set [loading] to swap the
/// label for a spinner while keeping the button's footprint, so the layout
/// does not jump.
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;

    final button = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.field,
        boxShadow: enabled ? AppShadows.primary : null,
      ),
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        child: AnimatedSwitcher(
          duration: AppMotion.duration(context, AppMotion.fast),
          child: loading
            ? const SizedBox(
                key: ValueKey('loading'),
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.onPrimary),
                ),
              )
            : Row(
                key: const ValueKey('label'),
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: AppColors.onPrimary),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                      Text(label, style: AppTextStyles.button),
                    ],
                  ),
        ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
