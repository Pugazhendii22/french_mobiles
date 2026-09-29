import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:french_mobiles/models/brand_model.dart';

import '../motion/motion.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';

/// A selectable brand tile.
///
/// Renders as a neutral surface card and lets the brand's own logo carry its
/// identity, rather than tinting the card with `themeColor`. That keeps a
/// grid of brands visually even — no single card dominates because its brand
/// happens to be vivid — and keeps the surface inside the design system.
class AppBrandCard extends StatelessWidget {
  const AppBrandCard({
    super.key,
    required this.brand,
    this.onTap,
    this.width,
  });

  final BrandModel brand;
  final VoidCallback? onTap;

  /// Set for a fixed-width card in a horizontal rail; leave null to fill a
  /// grid cell.
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: brand.name,
      child: AppPressable(
        onTap: onTap,
        child: Container(
          width: width,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.card,
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: AppBrandLogo(brand: brand, height: 34),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                brand.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.label,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Resolves a [BrandModel] to its mark.
///
/// Prefers the bundled SVG/bitmap asset, falling back to a wordmark. Every
/// logo is fitted to the same box so tall marks and icon marks scale
/// uniformly across a grid.
class AppBrandLogo extends StatelessWidget {
  const AppBrandLogo({
    super.key,
    required this.brand,
    this.height = 34,
    this.width = 90,
  });

  final BrandModel brand;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    final asset = brand.logoAssetPath;

    if (asset == null) {
      return _Wordmark(brand: brand, height: height, width: width);
    }

    final isSvg = asset.toLowerCase().endsWith('.svg');
    final logo = isSvg
        ? SvgPicture.asset(
            asset,
            fit: BoxFit.contain,
            placeholderBuilder: (_) => const SizedBox.shrink(),
            errorBuilder: (_, __, ___) =>
                _Wordmark(brand: brand, height: height, width: width),
          )
        : Image.asset(
            asset,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                _Wordmark(brand: brand, height: height, width: width),
          );

    return SizedBox(
      width: width,
      height: height,
      child: FittedBox(fit: BoxFit.contain, child: logo),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({
    required this.brand,
    required this.height,
    required this.width,
  });

  final BrandModel brand;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: FittedBox(
        fit: BoxFit.contain,
        child: Text(
          brand.name,
          maxLines: 1,
          // themeColor is model data, not a palette value: it is the only
          // place a brand's own colour appears, so a brand with no bundled
          // asset still reads as itself.
          style: AppTextStyles.h2.copyWith(
            color: brand.themeColor,
            height: 1,
          ),
        ),
      ),
    );
  }
}
