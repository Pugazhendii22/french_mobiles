import 'package:flutter/material.dart';

import 'package:french_mobiles/shared/motion/motion.dart';
import 'package:french_mobiles/shared/theme/app_colors.dart';
import 'package:french_mobiles/shared/theme/app_text_styles.dart';
import 'package:french_mobiles/shared/theme/app_theme.dart';

/// Destinations in the bottom navigation bar.
enum HomeNavTab { home, sell, orders, wishlist, profile }

/// Bottom navigation bar.
///
/// Home is the only tab that renders in place; the rest push their existing
/// route and the bar returns to Home, so the selected index never lies about
/// what is on screen.
class HomeBottomNav extends StatelessWidget {
  const HomeBottomNav({
    super.key,
    required this.current,
    required this.onTap,
  });

  final HomeNavTab current;
  final ValueChanged<HomeNavTab> onTap;

  static const List<(HomeNavTab, IconData, IconData, String)> _items = [
    (HomeNavTab.home, Icons.home_outlined, Icons.home_rounded, 'Home'),
    (HomeNavTab.sell, Icons.sell_outlined, Icons.sell_rounded, 'Sell'),
    (
      HomeNavTab.orders,
      Icons.receipt_long_outlined,
      Icons.receipt_long_rounded,
      'Orders'
    ),
    (
      HomeNavTab.wishlist,
      Icons.favorite_border_rounded,
      Icons.favorite_rounded,
      'Saved'
    ),
    (
      HomeNavTab.profile,
      Icons.person_outline_rounded,
      Icons.person_rounded,
      'Profile'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.only(
        top: AppSpacing.sm,
        bottom: AppSpacing.sm + bottomInset,
        left: AppSpacing.sm,
        right: AppSpacing.sm,
      ),
      child: Row(
        children: [
          for (final item in _items)
            Expanded(
              child: _NavItem(
                icon: item.$2,
                activeIcon: item.$3,
                label: item.$4,
                selected: item.$1 == current,
                onTap: () => onTap(item.$1),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.field,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: AppMotion.duration(context, AppMotion.fast),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Icon(
                  selected ? activeIcon : icon,
                  key: ValueKey<bool>(selected),
                  size: 22,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.navLabel.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
