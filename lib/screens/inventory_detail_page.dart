import 'package:flutter/material.dart';

import '../shared/motion/motion.dart';
import '../shared/theme/app_colors.dart';
import '../shared/theme/app_text_styles.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/widgets.dart';

/// Detail view for a second-hand listing.
///
/// Still a placeholder in one respect: the buy action is not implemented and
/// shows a snackbar, exactly as before.
class InventoryDetailPlaceholder extends StatefulWidget {
  final String? documentId;
  final Map<String, dynamic> data;

  const InventoryDetailPlaceholder({
    super.key,
    required this.data,
    this.documentId,
  });

  @override
  State<InventoryDetailPlaceholder> createState() =>
      _InventoryDetailPlaceholderState();
}

class _InventoryDetailPlaceholderState
    extends State<InventoryDetailPlaceholder> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<String> _collectImages() {
    final d = widget.data;
    if (d['images'] is List) {
      return List<String>.from((d['images'] as List).whereType<String>());
    }
    if (d['photos'] is List) {
      return List<String>.from((d['photos'] as List).whereType<String>());
    }
    final candidates = <String>[];
    if (d['photo1Url'] is String && (d['photo1Url'] as String).isNotEmpty) {
      candidates.add(d['photo1Url'] as String);
    }
    if (d['imageUrl'] is String && (d['imageUrl'] as String).isNotEmpty) {
      candidates.add(d['imageUrl'] as String);
    }
    if (d['photo'] is String && (d['photo'] as String).isNotEmpty) {
      candidates.add(d['photo'] as String);
    }
    return candidates.isEmpty
        ? ['https://via.placeholder.com/600x400?text=No+Image']
        : candidates;
  }

  int _safeInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) {
      return int.tryParse(v.replaceAll(RegExp('[^0-9]'), '')) ?? 0;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final images = _collectImages();
    final brand = (d['brand'] ?? d['maker'] ?? '')?.toString() ?? '';
    final model =
        (d['model'] ?? d['title'] ?? d['name'] ?? '')?.toString() ?? '';
    final description = (d['description'] ?? d['desc'] ?? '')?.toString() ?? '';

    final rawFinal =
        d['salePrice'] ?? d['finalPrice'] ?? d['price'] ?? d['finalPayout'];
    final finalPrice = _safeInt(rawFinal);
    final rawOriginal = d['originalPrice'] ?? d['mrp'] ?? d['basePrice'];
    final originalPrice = _safeInt(rawOriginal);
    int discountPercent = 0;
    if (originalPrice > 0 && originalPrice > finalPrice) {
      discountPercent =
          ((originalPrice - finalPrice) * 100 / originalPrice).round();
    }

    final Map<String, dynamic> specs = {};
    if (d['specs'] is Map) specs.addAll(Map<String, dynamic>.from(d['specs']));
    for (final key in [
      'brand',
      'model',
      'ram',
      'storage',
      'battery',
      'processor',
      'color',
      'os'
    ]) {
      if (d.containsKey(key) && d[key] != null) {
        specs[key.toUpperCase()] = d[key].toString();
      }
    }

    final title = model.isNotEmpty
        ? '$brand $model'.trim()
        : (brand.isNotEmpty ? brand : 'Product');

    return Theme(
      data: AppTheme.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenGutter,
                  AppSpacing.lg,
                  AppSpacing.screenGutter,
                  AppSpacing.lg,
                ),
                sliver: SliverToBoxAdapter(
                  child: AppScreenHeader(title: title),
                ),
              ),
              SliverToBoxAdapter(child: _buildGallery(images)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenGutter,
                  AppSpacing.xl,
                  AppSpacing.screenGutter,
                  AppSpacing.xxxl,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildPricing(finalPrice, originalPrice, discountPercent),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text('Description', style: AppTextStyles.h3),
                      const SizedBox(height: AppSpacing.sm),
                      Text(description, style: AppTextStyles.body),
                    ],
                    if (specs.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text('Specifications', style: AppTextStyles.h3),
                      const SizedBox(height: AppSpacing.md),
                      _buildSpecs(specs),
                    ],
                  ]),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: AppBottomBar(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Price', style: AppTextStyles.caption),
                    AppAnimatedCount(
                      value: finalPrice,
                      prefix: '₹ ',
                      style: AppTextStyles.h3,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: AppPrimaryButton(
                  label: 'Buy now',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Buy flow not implemented'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGallery(List<String> images) {
    return SizedBox(
      height: 280,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenGutter,
                ),
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.card,
                  border: Border.all(color: AppColors.border),
                ),
                child: index == 0 && widget.documentId != null
                    // Receives the flight from the home rail / wishlist. Only
                    // the first frame participates; the rest just page.
                    ? Hero(
                        tag: 'product-image-${widget.documentId}',
                        child: AppNetworkImage(
                          url: images[index],
                          fit: BoxFit.contain,
                          borderRadius: BorderRadius.zero,
                        ),
                      )
                    : AppNetworkImage(
                        url: images[index],
                        fit: BoxFit.contain,
                        borderRadius: BorderRadius.zero,
                      ),
              );
            },
          ),
          if (images.length > 1)
            Positioned(
              bottom: AppSpacing.md,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(images.length, (i) {
                  final active = _currentIndex == i;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active ? AppColors.primary : AppColors.borderStrong,
                      borderRadius: AppRadius.pill,
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPricing(int finalPrice, int originalPrice, int discountPercent) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('₹ $finalPrice', style: AppTextStyles.h1),
        if (originalPrice > 0) ...[
          const SizedBox(width: AppSpacing.md),
          Text(
            '₹ $originalPrice',
            style: AppTextStyles.bodySmall.copyWith(
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ],
        if (discountPercent > 0) ...[
          const SizedBox(width: AppSpacing.md),
          AppBadge(
            label: '$discountPercent% OFF',
            tone: AppBadgeTone.success,
          ),
        ],
      ],
    );
  }

  Widget _buildSpecs(Map<String, dynamic> specs) {
    final entries = specs.entries.toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                indent: AppSpacing.lg,
                endIndent: AppSpacing.lg,
                color: AppColors.border,
              ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      entries[i].key,
                      style: AppTextStyles.caption,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      '${entries[i].value}',
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
