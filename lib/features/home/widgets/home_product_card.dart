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
    this.width,
  });

  final HomeProduct product;
  final HomeRepository repository;
  final VoidCallback onTap;
  final VoidCallback onWishlistTap;

  /// Saved-state stream for this product, or null when signed out.
  final Stream<bool>? Function(String productId) wishlistStream;

  /// Null fills the available width, which is what a grid cell wants. Set it
  /// for a fixed-width card in a horizontally scrolling context.
  final double? width;

  /// Grade chip colours, following the convention the refurbished
  /// marketplaces share: the top grade reads as reassurance, the middle as
  /// neutral-positive, the lowest as a caution rather than a warning — a Fair
  /// phone is still fully functional, it just looks used.
  Color _gradeColor() {
    switch (product.conditionTone) {
      case ConditionTone.top:
        return AppColors.success;
      case ConditionTone.mid:
        return AppColors.onPrimarySoft;
      case ConditionTone.low:
        return AppColors.warning;
      case ConditionTone.unknown:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final productId = product.documentId ?? product.id;
    final discount = product.discountPercent;

    // The model alone: HomeProduct.title is "brand model", and the brand is
    // already the line above it.
    final name = product.model.isNotEmpty ? product.model : product.title;

    return Semantics(
      button: true,
      label: product.title,
      child: AppPressable(
        onTap: onTap,
        // No card, no border, no shadow. The cell sits directly on the page:
        // in a product grid the photo block is the only surface that needs to
        // exist, and every listing being a floating white box is what made
        // the grid read as boxes rather than products.
        child: SizedBox(
          width: width,
          // Fills the cell rather than shrink-wrapping inside it. The cell's
          // height is fixed by the grid, so a column that only takes what it
          // needs leaves the remainder as dead space under the price.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _imageBlock(productId),
              const SizedBox(height: 10),
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
              // Only when there is one. This used to render a single space to
              // hold the line open so prices stayed level across a row —
              // which is the gap between the name and the price on every
              // listing that has no storage to show. The spacer below keeps
              // them level without printing an empty line to do it.
              if (product.storage.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  product.storage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
              ],
              const Spacer(),
              _priceBlock(discount),
            ],
          ),
        ),
      ),
    );
  }

  /// The photo, sitting directly on the page like the details beneath it.
  ///
  /// No panel behind it: a white block on the #F7F8F8 page was one more box
  /// around something that did not need one, and it framed the product
  /// instead of showing it.
  ///
  /// Fixed height rather than a square: the grid pins cell height in logical
  /// pixels, so an aspect-ratio image would change the text budget every time
  /// the screen width changed.
  Widget _imageBlock(String productId) {
    final gradeFg = _gradeColor();

    return SizedBox(
      height: 150,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            // Less inset than before: with no panel edge to keep clear of,
            // the photo can use the space.
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Hero(
                tag: 'product-image-$productId',
                child: AppNetworkImage(
                  url: product.imageUrl,
                  fit: BoxFit.contain,
                  borderRadius: BorderRadius.zero,
                ),
              ),
            ),
          ),
          if (product.condition.isNotEmpty)
            Positioned(
              top: 0,
              left: 0,
              // A plain label rather than a filled pill: the colour still
              // carries the grade, without another shape on the page.
              child: Text(
                product.condition.toUpperCase(),
                style: AppTextStyles.overline.copyWith(color: gradeFg),
              ),
            ),
          Positioned(
            top: 0,
            right: 0,
            child: _WishlistButton(
              productId: productId,
              repository: repository,
              wishlistStream: wishlistStream,
              onTap: onWishlistTap,
            ),
          ),
        ],
      ),
    );
  }

  /// Price, then the struck original and percentage off on a second line —
  /// the figure being paid gets the full width and never competes for it.
  Widget _priceBlock(int discount) {
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

            // No circular backing: on the page ground a white disc reads as
            // yet another container, and the icon is legible without it.
            return Material(
              color: AppColors.transparent,
              shape: const CircleBorder(),
              elevation: 0,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(4),
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
