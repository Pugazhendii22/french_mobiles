import 'package:flutter/material.dart';

import '../motion/motion.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import 'app_network_image.dart';

/// A selectable option tile: optional remote icon, title, supporting line.
///
/// Set [multiSelect] to show a checkbox mark instead of the implicit
/// single-choice highlight, for steps where several options can apply.
class AppOptionCard extends StatelessWidget {
  const AppOptionCard({
    super.key,
    required this.title,
    required this.selected,
    this.subtitle,
    this.iconUrl,
    this.art,
    this.fallbackIcon = Icons.smartphone_rounded,
    this.multiSelect = false,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final String? iconUrl;

  /// A drawn illustration, used ahead of [iconUrl] and [fallbackIcon].
  ///
  /// The condition steps supply one of these because every option's
  /// `icon_url` in Firestore is empty, so they all landed on the same generic
  /// handset and told the seller nothing.
  final Widget? art;

  final IconData fallbackIcon;
  final bool selected;
  final bool multiSelect;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: AppPressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.duration(context, AppMotion.fast),
          curve: AppMotion.enter,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySoft : AppColors.surface,
            borderRadius: AppRadius.card,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Center(
                      child: art ??
                          ((iconUrl != null && iconUrl!.trim().isNotEmpty)
                              ? AppNetworkImage(
                                  url: iconUrl!,
                                  height: 44,
                                  width: 44,
                                  fit: BoxFit.contain,
                                  borderRadius: BorderRadius.zero,
                                  placeholderIcon: fallbackIcon,
                                )
                              : Icon(
                                  fallbackIcon,
                                  size: 32,
                                  color: selected
                                      ? AppColors.onPrimarySoft
                                      : AppColors.textSecondary,
                                )),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    title,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label,
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ],
              ),
              if (multiSelect)
                Positioned(
                  top: 0,
                  right: 0,
                  child: AnimatedContainer(
                    duration: AppMotion.duration(context, AppMotion.fast),
                    height: 20,
                    width: 20,
                    decoration: BoxDecoration(
                      color:
                          selected ? AppColors.primary : AppColors.transparent,
                      borderRadius: AppRadius.pill,
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : AppColors.borderStrong,
                        width: 2,
                      ),
                    ),
                    child: selected
                        ? const Icon(
                            Icons.check_rounded,
                            size: 13,
                            color: AppColors.onPrimary,
                          )
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
