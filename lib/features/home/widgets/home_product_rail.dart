import 'package:flutter/material.dart';

import 'package:french_mobiles/features/home/data/home_models.dart';
import 'package:french_mobiles/features/home/data/home_repository.dart';
import 'package:french_mobiles/features/home/widgets/home_product_card.dart';
import 'package:french_mobiles/shared/motion/motion.dart';
import 'package:french_mobiles/shared/theme/app_theme.dart';
import 'package:french_mobiles/shared/widgets/app_empty_state.dart';
import 'package:french_mobiles/shared/widgets/app_shimmer.dart';

/// Horizontally scrolling rail of device listings.
///
/// Owns the four states this data can be in — loading, error, empty, loaded —
/// so the page body stays declarative. The skeleton matches the real card's
/// footprint, so nothing shifts when the data arrives.
class HomeProductRail extends StatelessWidget {
  const HomeProductRail({
    super.key,
    required this.future,
    required this.repository,
    required this.onProductTap,
    required this.onWishlistTap,
    required this.wishlistStream,
    required this.onRetry,
    required this.emptyTitle,
    this.emptyMessage,
    this.searchQuery = '',
  });

  final Future<List<HomeProduct>> future;
  final HomeRepository repository;
  final ValueChanged<HomeProduct> onProductTap;
  final ValueChanged<HomeProduct> onWishlistTap;
  final Stream<bool>? Function(String productId) wishlistStream;
  final VoidCallback onRetry;
  final String emptyTitle;
  final String? emptyMessage;

  /// Client-side filter over the already-loaded rail. Filtering here rather
  /// than re-querying keeps typing free of extra Firestore reads.
  final String searchQuery;

  /// Sized to the card's tallest content: 152 image + 115 of text when the
  /// name wraps to two lines and both spec fields are present, plus slack.
  static const double _railHeight = 276;

  List<HomeProduct> _applySearch(List<HomeProduct> products) {
    final q = searchQuery.trim().toLowerCase();
    if (q.isEmpty) return products;
    return products
        .where((p) =>
            p.title.toLowerCase().contains(q) ||
            p.brand.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<HomeProduct>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _RailSkeleton();
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenGutter,
            ),
            child: AppEmptyState(
              title: 'Could not load devices',
              message: 'Check your connection and try again.',
              icon: Icons.wifi_off_rounded,
              onRetry: onRetry,
            ),
          );
        }

        final loaded = snapshot.data ?? const <HomeProduct>[];
        final products = _applySearch(loaded);

        if (products.isEmpty) {
          final searching = searchQuery.trim().isNotEmpty;
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenGutter,
            ),
            child: AppEmptyState(
              title: searching ? 'No matches' : emptyTitle,
              message: searching
                  ? 'Nothing here matches "${searchQuery.trim()}".'
                  : emptyMessage,
              icon: searching
                  ? Icons.search_off_rounded
                  : Icons.inventory_2_outlined,
            ),
          );
        }

        return SizedBox(
          height: _railHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenGutter,
            ),
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              final product = products[index];
              return AppReveal(
                index: index,
                direction: Axis.horizontal,
                child: HomeProductCard(
                product: product,
                repository: repository,
                onTap: () => onProductTap(product),
                  onWishlistTap: () => onWishlistTap(product),
                  wishlistStream: wishlistStream,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _RailSkeleton extends StatelessWidget {
  const _RailSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: HomeProductRail._railHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, __) => const AppShimmer(width: 168, height: 268),
      ),
    );
  }
}
