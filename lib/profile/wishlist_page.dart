import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../firebase/catalog_firebase.dart';
import '../firebase/wishlist_service.dart';
import '../screens/inventory_detail_page.dart';
import '../screens/login_page.dart';
import '../shared/theme/app_colors.dart';
import '../shared/theme/app_text_styles.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/widgets.dart';

class WishlistPage extends StatelessWidget {
  const WishlistPage({super.key});

  Future<void> _openItem(BuildContext context, WishlistItem item) async {
    Map<String, dynamic> data = {
      'id': item.productId,
      'brand': item.brand,
      'model': item.title,
      'salePrice': item.price,
      'photo1Url': item.imageUrl,
      if (item.snapshot != null) ...item.snapshot!,
    };

    try {
      final doc = await FirebaseFirestore.instance
          .collection('second_hand_mobiles')
          .doc(item.productId)
          .get();
      if (doc.exists && doc.data() != null) {
        data = doc.data()!;
      }
    } catch (_) {}

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InventoryDetailPlaceholder(
          documentId: item.productId,
          data: data,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.screenGutter,
                  AppSpacing.lg,
                  AppSpacing.screenGutter,
                  AppSpacing.lg,
                ),
                child: AppScreenHeader(title: 'My wishlist'),
              ),
              Expanded(
                child: StreamBuilder<User?>(
                  stream: catalogAuth.authStateChanges(),
                  builder: (context, authSnap) {
                    final user = authSnap.data;
                    if (user == null) {
                      return Padding(
                        padding: const EdgeInsets.all(AppSpacing.screenGutter),
                        child: AppEmptyState(
                          title: 'Sign in to see your wishlist',
                          message: 'Saved devices appear here once you sign in.',
                          icon: Icons.favorite_border_rounded,
                          retryLabel: 'Sign in',
                          onRetry: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginPage(),
                            ),
                          ),
                        ),
                      );
                    }
                    return _buildList(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    return StreamBuilder<List<WishlistItem>>(
      stream: WishlistService.watchAll(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenGutter,
            ),
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (_, __) =>
                const AppShimmer(width: double.infinity, height: 88),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.screenGutter),
            child: AppEmptyState(
              title: 'Could not load wishlist',
              message: '${snapshot.error}',
              icon: Icons.wifi_off_rounded,
            ),
          );
        }

        final items = snapshot.data ?? const <WishlistItem>[];
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.screenGutter),
            child: AppEmptyState(
              title: 'Your wishlist is empty',
              message: 'Tap the heart on a phone to save it here.',
              icon: Icons.favorite_border_rounded,
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenGutter,
            0,
            AppSpacing.screenGutter,
            AppSpacing.xxl,
          ),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) {
            final item = items[index];
            return _WishlistCard(
              item: item,
              onTap: () => _openItem(context, item),
              onRemove: () => WishlistService.remove(item.productId),
            );
          },
        );
      },
    );
  }
}

class _WishlistCard extends StatelessWidget {
  const _WishlistCard({
    required this.item,
    required this.onTap,
    required this.onRemove,
  });

  final WishlistItem item;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.card,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.card,
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              height: 64,
              width: 64,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: AppRadius.field,
              ),
              child: AppNetworkImage(
                url: item.imageUrl,
                fit: BoxFit.contain,
                borderRadius: BorderRadius.zero,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.brand.isNotEmpty)
                    Text(
                      item.brand.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.overline.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium,
                  ),
                  if (item.price.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(item.price, style: AppTextStyles.priceSmall),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Remove from wishlist',
              icon: const Icon(
                Icons.favorite_rounded,
                size: 20,
                color: AppColors.error,
              ),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}
