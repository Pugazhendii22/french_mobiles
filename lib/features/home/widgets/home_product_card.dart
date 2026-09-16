import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:french_mobiles/features/home/data/home_models.dart';
import 'package:french_mobiles/features/home/data/home_repository.dart';
import 'package:french_mobiles/shared/motion/motion.dart';
import 'package:french_mobiles/shared/theme/app_colors.dart';
import 'package:french_mobiles/shared/theme/app_text_styles.dart';
import 'package:french_mobiles/shared/theme/app_theme.dart';
import 'package:french_mobiles/shared/widgets/app_badge.dart';
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

  @override
  Widget build(BuildContext context) {
    final productId = product.documentId ?? product.id;
    final discount = product.discountPercent;

    // The model alone: HomeProduct.title is "brand model", and the brand is
    // already the line above it.
    final name = product.model.isNotEmpty ? product.model : product.title;

    // Storage and condition are optional in the document; each is dropped
    // rather than rendered blank.
    final specs = [product.storage, product.condition]
        .where((s) => s.isNotEmpty)
        .join(' · ');

    return Semantics(
      button: true,
      label: product.title,
      child: AppPressable(
        onTap: onTap,
        child: Container(
          width: 168,
          decoration: BoxDecoration(
            // Raised, not outlined: the lift is what marks it tappable.
            color: AppColors.surface,
            borderRadius: AppRadius.card,
            boxShadow: AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // The photo sits on the card's own white, not in a tinted well.
              // A #F2F3F3 panel on a #FFFFFF card on a #F7F8F8 page is three
              // near-identical greys — it read as a smudge, not a frame.
              SizedBox(
                height: 152,
                width: double.infinity,
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.lg,
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
                    if (discount > 0)
                      Positioned(
                        top: AppSpacing.sm,
                        left: AppSpacing.sm,
                        child: AppBadge(
                          label: '$discount% OFF',
                          tone: AppBadgeTone.success,
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
                    // Sizes itself. The old fixed 40px box left a dead gap
                    // under every one-line name.
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium,
                    ),
                    if (specs.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        specs,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    if (product.price.isNotEmpty)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Flexible(
                            child: Text(
                              product.price,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.price,
                            ),
                          ),
                          if (discount > 0) ...[
                            const SizedBox(width: AppSpacing.xs),
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
                          ],
                        ],
                      )
                    else
                      Text('Price on request', style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
