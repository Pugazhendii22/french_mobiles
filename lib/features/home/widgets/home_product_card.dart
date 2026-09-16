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

  @override
  Widget build(BuildContext context) {
    final productId = product.documentId ?? product.id;

    return Semantics(
      button: true,
      label: product.title,
      child: AppPressable(
        onTap: onTap,
        child: Container(
          width: 164,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.card,
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  Container(
                    height: 132,
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppRadius.lg),
                      ),
                    ),
                    // Shares the image with the detail page, so the photo
                    // flies into place instead of the screen cutting.
                    child: Hero(
                      tag: 'product-image-$productId',
                      child: AppNetworkImage(
                        url: product.imageUrl,
                        fit: BoxFit.contain,
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                  ),
                  Positioned(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: _WishlistButton(
                      productId: productId,
                      repository: repository,
                      wishlistStream: wishlistStream,
                      onTap: onWishlistTap,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
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
                          color: AppColors.textSecondary,
                        ),
                      ),
                    const SizedBox(height: 2),
                    SizedBox(
                      height: 40,
                      child: Text(
                        product.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (product.price.isNotEmpty)
                      Text(product.price, style: AppTextStyles.price)
                    else
                      Text(
                        'Price on request',
                        style: AppTextStyles.bodySmall,
                      ),
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
