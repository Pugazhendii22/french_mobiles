import 'package:flutter/material.dart';

import 'package:flutter_svg/flutter_svg.dart';

import '../models/brand_model.dart';

class GridBrandCard extends StatelessWidget {
  final BrandModel brand;
  final VoidCallback? onTap;

  const GridBrandCard({super.key, required this.brand, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _BrandCardShell(
        brand: brand,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _BrandGradientHeader(
                brand: brand,
                logoHeight: 26,
              ),
            ),
            _BrandCardFooter(brand: brand, fontSize: 13),
          ],
        ),
      ),
    );
  }
}

class BrandCard extends StatelessWidget {
  final BrandModel brand;
  final VoidCallback? onTap;

  const BrandCard({super.key, required this.brand, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 160,
        height: 185,
        child: _BrandCardShell(
          brand: brand,
          elevated: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _BrandGradientHeader(
                  brand: brand,
                  logoHeight: 40,
                  logoWidth: 136,
                ),
              ),
              _BrandCardFooter(brand: brand, subtitle: 'AI pick · Top demand'),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shadow sits outside the clipped border so rounded corners stay intact.
class _BrandCardShell extends StatelessWidget {
  final BrandModel brand;
  final Widget child;
  final bool elevated;

  const _BrandCardShell({
    required this.brand,
    required this.child,
    this.elevated = false,
  });

  static const _radius = 24.0;

  @override
  Widget build(BuildContext context) {
    // Top-brands cards stand taller than the flatter grid cards via a
    // stronger shadow + a soft green halo, reinforcing the premium section.
    final shadow = elevated
        ? [
            BoxShadow(
              color: const Color(0xFF32CD32).withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: shadow,
      ),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: BorderSide(
              color: elevated
                  ? brand.resolvedBorderColor
                  : brand.resolvedBorderColor.withValues(alpha: 0.5)),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

class _BrandGradientHeader extends StatelessWidget {
  final BrandModel brand;
  final double logoHeight;
  final double logoWidth;

  const _BrandGradientHeader({
    required this.brand,
    required this.logoHeight,
    this.logoWidth = 120,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: brand.resolvedGradientColors,
          stops: brand.resolvedGradientStops,
        ),
      ),
      child: Center(
        child: Padding(
          // Consistent breathing room around the mark so tall logo assets
          // (OnePlus, Xiaomi, Google) don't crowd the card edge.
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          child: BrandLogo(
              brand: brand, height: logoHeight, width: logoWidth),
        ),
      ),
    );
  }
}

/// Reusable brand mark with exactly two states:
///  - a real logo asset exists  → show the logo image/icon
///  - no logo asset yet         → show the styled wordmark (brand name)
/// There is no third "monogram" state.
class BrandLogo extends StatelessWidget {
  final BrandModel brand;
  final double height;
  final double width;

  const BrandLogo({
    super.key,
    required this.brand,
    this.height = 40,
    this.width = 120,
  });

  @override
  Widget build(BuildContext context) {
    final asset = brand.logoAssetPath;
    // Debug: prints the branch + asset so you can tell "no asset" from
    // "asset failed to load" when a card shows a wordmark unexpectedly.
    debugPrint('[BrandLogo] ${brand.name}: asset=$asset');

    if (asset != null) {
      final isSvg = asset.toLowerCase().endsWith('.svg');
      final logo = isSvg
          ? SvgPicture.asset(
              asset,
              fit: BoxFit.contain,
              // If the asset fails to load, render an obvious marker instead
              // of silently showing nothing (which can look like "no logo").
              placeholderBuilder: (context) => const SizedBox(),
              errorBuilder: (context, error, stackTrace) {
                debugPrint('[BrandLogo] FAILED to load $asset: $error');
                return Container(
                  width: 48,
                  height: 24,
                  alignment: Alignment.center,
                  color: brand.themeColor,
                  child: Text(
                    brand.name.isNotEmpty
                        ? brand.name.substring(0, 1)
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                );
              },
            )
          : Image.asset(
              asset,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('[BrandLogo] FAILED to load $asset: $error');
                return _WordmarkFallback(brand: brand, height: height);
              },
            );
      // Fix every logo to the same bounding box so tall marks (OnePlus,
      // Xiaomi, Google) and icon marks (Apple, Vivo) share identical
      // max-height/max-width and scale uniformly within consistent padding.
      return SizedBox(
        width: width,
        height: height,
        child: FittedBox(fit: BoxFit.contain, child: logo),
      );
    }

    // No logo asset: styled wordmark only (no icon, no monogram).
    return _WordmarkFallback(brand: brand, height: height, width: width);
  }
}

class _WordmarkFallback extends StatelessWidget {
  final BrandModel brand;
  final double height;
  final double width;

  const _WordmarkFallback({
    required this.brand,
    required this.height,
    this.width = 120,
  });

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
          style: TextStyle(
            fontSize: height * 0.55,
            fontWeight: FontWeight.w800,
            color: brand.themeColor,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _BrandCardFooter extends StatelessWidget {
  final BrandModel brand;
  final double fontSize;
  final String? subtitle;

  const _BrandCardFooter({
    required this.brand,
    this.fontSize = 16,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    brand.name,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      subtitle!,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E9B1E),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Icon(
            Icons.arrow_forward_ios,
            color: Color(0xFFB0B7BF),
            size: 12,
          ),
        ],
      ),
    );
  }
}
