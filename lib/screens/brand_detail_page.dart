import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../models/model_detail.dart';
import '../shared/motion/motion.dart';
import '../shared/theme/app_colors.dart';
import '../shared/theme/app_text_styles.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/widgets.dart';
import 'variant_selection_page.dart';

class BrandDetailPage extends StatefulWidget {
  final String brandName;
  final Color themeColor;

  const BrandDetailPage({
    super.key,
    required this.brandName,
    required this.themeColor,
  });

  @override
  State<BrandDetailPage> createState() => _BrandDetailPageState();
}

class _BrandDetailPageState extends State<BrandDetailPage> {
  final TextEditingController _modelSearchController = TextEditingController();
  String _selectedCategory = 'All';
  List<ModelDetail> _allBrandModels = [];
  List<ModelDetail> _filteredModels = [];
  bool _isLoadingModels = true;

  FirebaseFirestore get _catalogFirestore =>
      FirebaseFirestore.instanceFor(app: Firebase.app('catalogApp'));

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  @override
  void dispose() {
    _modelSearchController.dispose();
    super.dispose();
  }

  int _parsePrice(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  Future<void> _loadModels() async {
    setState(() {
      _isLoadingModels = true;
      _filteredModels = [];
    });

    try {
      final querySnapshot = await _catalogFirestore
          .collection('brands')
          .doc(widget.brandName.toLowerCase())
          .collection('models')
          .get();

      final models = <ModelDetail>[];

      final variantResults = await Future.wait(
        querySnapshot.docs.map((doc) async {
          final modelData = doc.data();
          final variantsSnapshot = await _catalogFirestore
              .collection('brands')
              .doc(widget.brandName.toLowerCase())
              .collection('models')
              .doc(doc.id)
              .collection('variants')
              .get();

          int highestBasePrice = 0;
          for (final variantDoc in variantsSnapshot.docs) {
            final variantData = variantDoc.data();
            final variantPrice = _parsePrice(variantData['base_price']);
            if (variantPrice > highestBasePrice) {
              highestBasePrice = variantPrice;
            }
          }

          final modelName = (modelData['model'] ?? 'Unknown Model').toString();
          final imageUrl = (modelData['image_url'] ?? '').toString().trim();
          final releaseYear = modelData['release_year'];
          final category =
              releaseYear == null ? 'Unknown' : releaseYear.toString();

          return ModelDetail(
            name: modelName,
            category: category,
            maxPrice: highestBasePrice == 0
                ? _parsePrice(modelData['base_price'])
                : highestBasePrice,
            imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
            docId: doc.id,
          );
        }),
      );

      models.addAll(variantResults);

      setState(() {
        _allBrandModels = models;
        _filteredModels = _applyFilters(_modelSearchController.text);
      });
    } catch (_) {
      setState(() {
        _allBrandModels = [];
        _filteredModels = [];
      });
    } finally {
      setState(() {
        _isLoadingModels = false;
      });
    }
  }

  List<ModelDetail> _applyFilters(String query) {
    final searchQuery = query.toLowerCase();
    return _allBrandModels.where((model) {
      final matchesQuery = model.name.toLowerCase().contains(searchQuery);
      final matchesCategory =
          _selectedCategory == 'All' || model.category == _selectedCategory;
      return matchesQuery && matchesCategory;
    }).toList();
  }

  Future<void> _filterModels(String query) async {
    setState(() {
      _filteredModels = _applyFilters(query);
    });
  }

  void _openModel(ModelDetail item) {
    context.pushScreen(VariantSelectionPage(
          brandName: widget.brandName,
          modelDocId: item.docId!,
          modelName: item.name,
          imageUrl: item.imageUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = [
      'All',
      ...{for (final m in _allBrandModels) m.category}
    ];

    return Theme(
      data: AppTheme.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusScope.of(context).unfocus(),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenGutter,
                    AppSpacing.lg,
                    AppSpacing.screenGutter,
                    AppSpacing.lg,
                  ),
                  child: AppScreenHeader(
                    title: widget.brandName,
                    content: AppSearchField(
                      controller: _modelSearchController,
                      hintText: 'Search ${widget.brandName} models',
                      onChanged: _filterModels,
                    ),
                  ),
                ),
                if (categories.length > 2) _buildCategoryRow(categories),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryRow(List<String> categories) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenGutter,
          ),
          itemCount: categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
          itemBuilder: (context, index) {
            final cat = categories[index];
            return AppFilterChip(
              label: cat,
              selected: cat == _selectedCategory,
              onTap: () {
                setState(() {
                  _selectedCategory = cat;
                  _filteredModels = _applyFilters(_modelSearchController.text);
                });
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoadingModels) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenGutter,
          0,
          AppSpacing.screenGutter,
          AppSpacing.xxl,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          childAspectRatio: 0.74,
        ),
        itemCount: 4,
        itemBuilder: (_, __) => const ModelCardSkeleton(),
      );
    }

    if (_filteredModels.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.screenGutter),
        child: AppEmptyState(
          title: _allBrandModels.isEmpty
              ? 'No models available'
              : 'No matching models',
          message: _allBrandModels.isEmpty
              ? 'We could not load ${widget.brandName} models right now.'
              : 'Try a different search or category.',
          icon: _allBrandModels.isEmpty
              ? Icons.smartphone_outlined
              : Icons.search_off_rounded,
          onRetry: _allBrandModels.isEmpty ? _loadModels : null,
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        0,
        AppSpacing.screenGutter,
        AppSpacing.xxl,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.74,
      ),
      itemCount: _filteredModels.length,
      itemBuilder: (context, index) {
        final model = _filteredModels[index];
        return AppReveal(
          index: index,
          slots: 6,
          child: _ModelCard(model: model, onTap: () => _openModel(model)),
        );
      },
    );
  }
}

/// A model tile: image, name, release year and the best price on offer.
/// The shape of a [_ModelCard] before its data arrives.
///
/// Public so its fit inside a grid cell can be tested: the heights here are
/// fixed while the cell's height comes from an aspect ratio, so a narrow
/// screen is where the two disagree.
///
/// Mirrors the card rather than filling the cell with one grey block: a
/// skeleton's whole job is to show what is coming, so that the page does not
/// jump when it lands. A solid rectangle promises a shape it then fails to
/// deliver, which is worse than showing nothing.
@visibleForTesting
class ModelCardSkeleton extends StatelessWidget {
  const ModelCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The photo panel.
          const Expanded(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: AppShimmer(width: double.infinity, height: 1000),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Two lines of model name, matching the 40px the card
                // reserves for it.
                AppShimmer(
                  width: double.infinity,
                  height: 13,
                  borderRadius: AppRadius.pill,
                ),
                const SizedBox(height: 6),
                AppShimmer(
                  width: 70,
                  height: 13,
                  borderRadius: AppRadius.pill,
                ),
                const SizedBox(height: AppSpacing.md),
                AppShimmer(
                  width: 36,
                  height: 10,
                  borderRadius: AppRadius.pill,
                ),
                const SizedBox(height: 6),
                AppShimmer(
                  width: 84,
                  height: 18,
                  borderRadius: AppRadius.pill,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({required this.model, required this.onTap});

  final ModelDetail model;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: model.name,
      child: AppPressable(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.card,
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppRadius.lg),
                    ),
                  ),
                  child: AppNetworkImage(
                    url: model.imageUrl ?? '',
                    fit: BoxFit.contain,
                    borderRadius: BorderRadius.zero,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 40,
                      child: Text(
                        model.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text('Up to', style: AppTextStyles.caption),
                    Text(
                      '₹ ${model.maxPrice}',
                      style: AppTextStyles.price.copyWith(
                        color: AppColors.onPrimarySoft,
                      ),
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
