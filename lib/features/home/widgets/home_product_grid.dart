import 'package:flutter/material.dart';

import 'package:french_mobiles/features/home/data/home_models.dart';
import 'package:french_mobiles/features/home/data/home_repository.dart';
import 'package:french_mobiles/features/home/widgets/home_product_card.dart';
import 'package:french_mobiles/shared/motion/motion.dart';
import 'package:french_mobiles/shared/theme/app_theme.dart';
import 'package:french_mobiles/shared/widgets/app_empty_state.dart';
import 'package:french_mobiles/shared/widgets/app_shimmer.dart';

/// Two-column grid of device listings.
///
/// **Returns slivers.** The home body is a [CustomScrollView], so this belongs
/// directly in its `slivers` list — not wrapped in a [SliverToBoxAdapter].
/// Putting a boxed [GridView] inside the outer scroll would mean either a
/// nested scrollable or `shrinkWrap`, both of which cost a full layout pass
/// over every child on every frame. As a sliver the grid builds only the
/// cells actually on screen.
///
/// Owns the four states this data can be in — loading, error, empty, loaded —
/// so the page body stays declarative.
class HomeProductGrid extends StatelessWidget {
  const HomeProductGrid({
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

  /// Client-side filter over the already-loaded list. Filtering here rather
  /// than re-querying keeps typing free of extra Firestore reads.
  final String searchQuery;

  /// Cell height in logical pixels.
  ///
  /// Deliberately [SliverGridDelegateWithFixedCrossAxisCount.mainAxisExtent]
  /// rather than `childAspectRatio`. A ratio derives height from width, so a
  /// narrower screen produces a shorter cell — while the card's content does
  /// not shrink with it. That guarantees overflow on small devices. The card's
  /// content is a fixed stack of text lines, so its height must be pinned
  /// directly.
  ///
  /// Measured against the tallest possible cell, not guessed:
  ///   photo block                 150  + 10 gap
  ///   brand overline               14  + 2 gap
  ///   model name, 2 lines          40  + 2 gap
  ///   storage                      16  + 6 gap
  ///   price                        20
  ///   struck original + % off      16
  ///                               ----
  ///                               276
  static const double _cellHeight = 280;

  static const double _gutter = AppSpacing.md;

  List<HomeProduct> _applySearch(List<HomeProduct> products) {
    final q = searchQuery.trim().toLowerCase();
    if (q.isEmpty) return products;
    return products
        .where((p) =>
            p.title.toLowerCase().contains(q) ||
            p.brand.toLowerCase().contains(q))
        .toList();
  }

  static const SliverGridDelegateWithFixedCrossAxisCount _delegate =
      SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    crossAxisSpacing: _gutter,
    mainAxisSpacing: _gutter,
    mainAxisExtent: _cellHeight,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<HomeProduct>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _padded(
            SliverGrid(
              gridDelegate: _delegate,
              delegate: SliverChildBuilderDelegate(
                (_, __) => const _CellSkeleton(),
                childCount: 4,
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return _box(
            AppEmptyState(
              title: 'Could not load devices',
              message: 'Check your connection and try again.',
              icon: Icons.wifi_off_rounded,
              onRetry: onRetry,
            ),
          );
        }

        final products = _applySearch(snapshot.data ?? const <HomeProduct>[]);

        if (products.isEmpty) {
          final searching = searchQuery.trim().isNotEmpty;
          return _box(
            AppEmptyState(
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

        // An odd count simply leaves the last cell alone on its row: the
        // delegate sizes every cell identically, so a lone card keeps the
        // same width as a paired one rather than stretching across.
        return _padded(
          SliverGrid(
            gridDelegate: _delegate,
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final product = products[index];
                return AppReveal(
                  index: index,
                  slots: 6,
                  child: HomeProductCard(
                    product: product,
                    repository: repository,
                    onTap: () => onProductTap(product),
                    onWishlistTap: () => onWishlistTap(product),
                    wishlistStream: wishlistStream,
                  ),
                );
              },
              childCount: products.length,
            ),
          ),
        );
      },
    );
  }

  Widget _padded(Widget sliver) => SliverPadding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenGutter,
        ),
        sliver: sliver,
      );

  Widget _box(Widget child) => _padded(SliverToBoxAdapter(child: child));
}

/// Mirrors the cell's shape — photo block, then three text lines — so nothing
/// shifts when the data lands.
class _CellSkeleton extends StatelessWidget {
  const _CellSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppShimmer(width: double.infinity, height: 150),
        const SizedBox(height: 10),
        AppShimmer(
          width: 60,
          height: 12,
          borderRadius: AppRadius.pill,
        ),
        const SizedBox(height: 6),
        AppShimmer(
          width: double.infinity,
          height: 14,
          borderRadius: AppRadius.pill,
        ),
        const SizedBox(height: 10),
        AppShimmer(
          width: 80,
          height: 16,
          borderRadius: AppRadius.pill,
        ),
      ],
    );
  }
}
