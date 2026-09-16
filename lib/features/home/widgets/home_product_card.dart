import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:french_mobiles/features/home/data/home_models.dart';
import 'package:french_mobiles/features/home/data/home_repository.dart';
import 'package:french_mobiles/shared/motion/motion.dart';
import 'package:french_mobiles/shared/theme/app_colors.dart';
import 'package:french_mobiles/shared/theme/app_text_styles.dart';
import 'package:french_mobiles/shared/theme/app_theme.dart';
import 'package:french_mobiles/shared/widgets/app_network_image.dart';

/// A single device listing.
///
/// The heart reflects [WishlistService.watchIsSaved] for the signed-in user
/// and is inert (but still visible) when signed out, so tapping it can route
/// to sign-in rather than silently doing nothing.
class HomeProductCard extends StatelessWidget {
  const HomeProductCard({
    super.key,
    required this.product,
    required this.repository,
    required this.onTap,
    required this.onWishlistTap,
    required this.wishlistStream,
  });

  final HomeProduct product;
  final HomeRepository repository;
  final VoidCallback onTap;
  final VoidCallback onWishlistTap;

  /// Saved-state stream for this product, or null when signed out.
  final Stream<bool>? Function(String productId) wishlistStream;

  /// Grade chip colours, following the convention the refurbished
  /// marketplaces share: the top grade reads as reassurance (green), the
  /// middle as neutral-positive, the lowest as a caution rather than a
  /// warning — a Fair phone is still fully functional, it just looks used.
  (Color, Color) _gradeColors() {
    switch (product.conditionTone) {
      case ConditionTone.top:
        return (AppColors.successSoft, AppColors.success);
      case ConditionTone.mid:
        return (AppColors.primarySoft, AppColors.onPrimarySoft);
      case ConditionTone.low:
        return (AppColors.warningSoft, AppColors.warning);
      case ConditionTone.unknown:
        return (AppColors.surfaceMuted, AppColors.textSecondary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productId = product.documentId ?? product.id;
    final discount = product.discountPercent;

    // The model alone: HomeProduct.title is "brand model", and the brand is
    // already the line above it.
    final name = product.model.isNotEmpty ? product.model : product.title;
    final (gradeBg, gradeFg) = _gradeColors();

    return Semantics(
      button: true,
      label: product.title,
      child: AppPressable(
        onTap: onTap,
        child: Container(
          width: 172,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.card,
            boxShadow: AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 148,
                width: double.infinity,
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.xl,
                        AppSpacing.md,
                        AppSpacing.sm,
                      ),
                      child: Hero(
                        tag: 'product-image-$productId',
                        child: AppNetworkImage(
                          url: product.imageUrl,
                          fit: BoxFit.contain,
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                    ),
                    // The grade leads. On a refurbished listing this is the
                    // thing being chosen between, so it sits on the photo
                    // rather than in a caption under it.
                    if (product.condition.isNotEmpty)
                      Positioned(
                        top: AppSpacing.sm,
                        left: AppSpacing.sm,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: gradeBg,
                            borderRadius: AppRadius.pill,
                          ),
                          child: Text(
                            product.condition.toUpperCase(),
                            style: AppTextStyles.overline
                                .copyWith(color: gradeFg),
                          ),
                        ),
                      ),
                    Positioned(
                      top: AppSpacing.xs,
                      right: AppSpacing.xs,
                      child: _WishlistButton(
                        productId: productId,
                        repository: repository,
                        wishlistStream: wishlistStream,
                        onTap: onWishlistTap,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (product.brand.isNotEmpty)
                      Text(
                        product.brand.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.overline.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium,
                    ),
                    if (product.storage.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        product.storage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    _priceRow(discount),
                    if (product.warrantyMonths > 0) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          const Icon(
                            Icons.verified_user_outlined,
                            size: 12,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              '${product.warrantyMonths}-month warranty',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Price, struck original and percentage off on one baseline — the layout
  /// every Indian marketplace uses, because it lets the eye read "what it
  /// costs / what it cost / how much less" in a single pass.
  Widget _priceRow(int discount) {
    if (product.price.isEmpty) {
      return Text('Price on request', style: AppTextStyles.bodySmall);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          product.price,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.price,
        ),
        if (discount > 0)
          Row(
            children: [
              Flexible(
                child: Text(
                  '₹ ${product.originalPriceValue}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    decoration: TextDecoration.lineThrough,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '$discount% off',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _WishlistButton extends StatelessWidget {
  const _WishlistButton({
    required this.productId,
    required this.repository,
    required this.wishlistStream,
    required this.onTap,
  });

  final String productId;
  final HomeRepository repository;
  final Stream<bool>? Function(String productId) wishlistStream;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: repository.watchAuthState(),
      builder: (context, authSnapshot) {
        final signedIn = authSnapshot.data != null;
        final stream = signedIn ? wishlistStream(productId) : null;

        return StreamBuilder<bool>(
          stream: stream ?? Stream<bool>.value(false),
          initialData: false,
          builder: (context, wishSnapshot) {
            final saved = wishSnapshot.data == true;

            return Material(
              color: AppColors.surface,
              shape: const CircleBorder(),
              elevation: 0,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: Icon(
                      saved
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      key: ValueKey<bool>(saved),
                      size: 18,
                      color:
                          saved ? AppColors.error : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
