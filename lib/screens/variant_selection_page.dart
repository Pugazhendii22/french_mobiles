import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../shared/motion/motion.dart';
import '../shared/theme/app_colors.dart';
import '../shared/theme/app_text_styles.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/widgets.dart';
import 'device_evaluation_wizard.dart';

class VariantSelectionPage extends StatefulWidget {
  final String brandName;
  final String modelDocId;
  final String modelName;
  final String? imageUrl;

  const VariantSelectionPage({
    super.key,
    required this.brandName,
    required this.modelDocId,
    required this.modelName,
    this.imageUrl,
  });

  @override
  State<VariantSelectionPage> createState() => _VariantSelectionPageState();
}

class _VariantSelectionPageState extends State<VariantSelectionPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _variants = [];
  int? _selectedIndex;

  FirebaseFirestore get _catalogFirestore =>
      FirebaseFirestore.instanceFor(app: Firebase.app('catalogApp'));

  @override
  void initState() {
    super.initState();
    _loadVariants();
  }

  Future<void> _loadVariants() async {
    setState(() {
      _isLoading = true;
      _variants = [];
      _selectedIndex = null;
    });

    try {
      final snapshot = await _catalogFirestore
          .collection('brands')
          .doc(widget.brandName.toLowerCase())
          .collection('models')
          .doc(widget.modelDocId)
          .collection('variants')
          .get();

      final results = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        results.add({
          'id': doc.id,
          'storage': (data['storage'] ?? '').toString(),
          'base_price': data['base_price'] is num ? (data['base_price'] as num).toInt() : int.tryParse('${data['base_price']}') ?? 0,
        });
      }

      setState(() {
        _variants = results;
      });
    } catch (e) {
      setState(() {
        _variants = [];
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _continue() {
    final selected = _variants[_selectedIndex!];
    context.pushScreen(DeviceEvaluationWizard(
          brandName: widget.brandName,
          modelDocId: widget.modelDocId,
          modelName: widget.modelName,
          imageUrl: widget.imageUrl,
          basePrice: selected['base_price'] ?? 0,
          storage: (selected['storage'] ?? '').toString(),
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
          bottom: false,
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
                  title: 'Select storage',
                  content: _buildDeviceSummary(),
                ),
              ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
        bottomNavigationBar: AppBottomBar(
          child: AppPrimaryButton(
            label: 'Continue',
            icon: Icons.arrow_forward_rounded,
            onPressed: _selectedIndex == null ? null : _continue,
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceSummary() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            height: 56,
            width: 56,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: AppRadius.field,
            ),
            child: AppNetworkImage(
              url: widget.imageUrl ?? '',
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
                Text(
                  widget.brandName,
                  style: AppTextStyles.overline.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.modelName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenGutter,
        ),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        // 70 is what an AppSelectableTile measures.
        itemBuilder: (_, __) =>
            const AppShimmer(width: double.infinity, height: 70),
      );
    }

    if (_variants.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.screenGutter),
        child: AppEmptyState(
          title: 'No storage options',
          message: 'We could not load variants for this model.',
          icon: Icons.sd_storage_outlined,
          onRetry: _loadVariants,
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
      itemCount: _variants.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final variant = _variants[index];
        final storage = (variant['storage'] ?? '').toString();
        final price = variant['base_price'] as int? ?? 0;

        return AppReveal(
          index: index,
          child: AppSelectableTile(
            title: storage.isEmpty ? 'Standard variant' : storage,
            selected: _selectedIndex == index,
            trailingLabel: 'Up to',
            trailingText: '₹ $price',
            onTap: () => setState(() => _selectedIndex = index),
          ),
        );
      },
    );
  }
}
