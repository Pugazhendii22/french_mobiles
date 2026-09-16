import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../firebase/catalog_firebase.dart';
import '../profile/account_pages.dart';
import '../shared/theme/app_colors.dart';
import '../shared/theme/app_text_styles.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/widgets.dart';
import 'login_page.dart';
import 'order_tracking_page.dart';

class PickupCheckoutPage extends StatefulWidget {
  final String brandName;
  final String modelDocId;
  final String modelName;
  final String? imageUrl;
  final String variant; // storage string
  final int basePrice;
  final int finalPayout;

  const PickupCheckoutPage({
    super.key,
    required this.brandName,
    required this.modelDocId,
    required this.modelName,
    this.imageUrl,
    required this.variant,
    required this.basePrice,
    required this.finalPayout,
  });

  @override
  State<PickupCheckoutPage> createState() => _PickupCheckoutPageState();
}

class _PickupCheckoutPageState extends State<PickupCheckoutPage> {
  String? _selectedAddressLabel;
  String? _selectedAddressFullText;
  double? _selectedAddressLat;
  double? _selectedAddressLng;
  bool _loadingAddress = false;
  bool _placingOrder = false;

  @override
  void initState() {
    super.initState();
    _loadDefaultAddress();
  }

  Future<void> _loadDefaultAddress() async {
    final user = catalogAuth.currentUser;
    if (user == null) return;
    setState(() => _loadingAddress = true);
    try {
      final col = catalogFirestore.collection('users').doc(user.uid).collection('addresses');
      final snap = await col.where('isDefault', isEqualTo: true).limit(1).get();
      if (snap.docs.isNotEmpty) {
        final d = snap.docs.first.data();
        setState(() {
          _selectedAddressLabel = (d['label'] as String?) ?? 'Other';
          _selectedAddressFullText = (d['fullAddress'] as String?) ?? '';
          _selectedAddressLat = (d['latitude'] as num?)?.toDouble();
          _selectedAddressLng = (d['longitude'] as num?)?.toDouble();
        });
      }
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loadingAddress = false);
    }
  }

  Future<void> _pickAddress() async {
    final result = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(
        builder: (context) => const SavedAddressesPage(selectMode: true),
      ),
    );
    if (result != null) {
      setState(() {
        _selectedAddressLabel =
            (result['label'] as String?) ?? _selectedAddressLabel;
        _selectedAddressFullText =
            (result['fullAddress'] as String?) ?? _selectedAddressFullText;
        _selectedAddressLat =
            (result['latitude'] as num?)?.toDouble() ?? _selectedAddressLat;
        _selectedAddressLng =
            (result['longitude'] as num?)?.toDouble() ?? _selectedAddressLng;
      });
    }
  }

  Future<void> _placeOrder() async {
    if (_selectedAddressFullText == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a pickup address')));
      return;
    }

    setState(() => _placingOrder = true);

    try {
      var user = catalogAuth.currentUser;
      if (user == null) {
        final loggedIn = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
        if (loggedIn != true) {
          setState(() => _placingOrder = false);
          return;
        }
        user = catalogAuth.currentUser;
      }

      if (user == null) {
        setState(() => _placingOrder = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to determine user after login')));
        return;
      }

      final orderData = {
        'userId': user.uid,
        'brand': widget.brandName,
        'modelDocId': widget.modelDocId,
        'modelName': widget.modelName,
        'storage': widget.variant,
        'imageUrl': widget.imageUrl,
        'basePrice': widget.basePrice,
        'finalPayout': widget.finalPayout,
        'addressLabel': _selectedAddressLabel,
        'addressFullText': _selectedAddressFullText,
        'addressLatitude': _selectedAddressLat,
        'addressLongitude': _selectedAddressLng,
        'status': 'placed',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final ref = await catalogFirestore.collection('orders').add(orderData);
      final orderId = ref.id;

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => OrderTrackingPage(orderId: orderId)),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to place order: $e')));
    } finally {
      if (mounted) setState(() => _placingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenGutter,
              AppSpacing.lg,
              AppSpacing.screenGutter,
              AppSpacing.xxl,
            ),
            children: [
              const AppScreenHeader(title: 'Pickup & payout'),
              const SizedBox(height: AppSpacing.xl),
              Text('Pickup address', style: AppTextStyles.h3),
              const SizedBox(height: AppSpacing.md),
              _buildAddressCard(),
              const SizedBox(height: AppSpacing.xl),
              Text('Your device', style: AppTextStyles.h3),
              const SizedBox(height: AppSpacing.md),
              _buildDeviceCard(),
              const SizedBox(height: AppSpacing.xl),
              Text('Payout summary', style: AppTextStyles.h3),
              const SizedBox(height: AppSpacing.md),
              _buildSummaryCard(),
              const SizedBox(height: AppSpacing.lg),
              _buildReassurance(),
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
                    Text('You receive', style: AppTextStyles.caption),
                    Text(
                      '₹ ${widget.finalPayout}',
                      style: AppTextStyles.h2.copyWith(
                        color: AppColors.onPrimarySoft,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              AppPrimaryButton(
                label: 'Place order',
                expand: false,
                loading: _placingOrder,
                onPressed: _placeOrder,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddressCard() {
    if (_loadingAddress) {
      return const AppShimmer(width: double.infinity, height: 84);
    }

    final hasAddress = _selectedAddressFullText != null;

    return InkWell(
      onTap: _pickAddress,
      borderRadius: AppRadius.card,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.card,
          border: Border.all(
            color: hasAddress ? AppColors.border : AppColors.warning,
          ),
        ),
        child: Row(
          children: [
            Container(
              height: 36,
              width: 36,
              decoration: BoxDecoration(
                color: hasAddress
                    ? AppColors.primarySoft
                    : AppColors.warningSoft,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.location_on_outlined,
                size: 18,
                color:
                    hasAddress ? AppColors.onPrimarySoft : AppColors.warning,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _selectedAddressLabel ?? 'Add a pickup address',
                    style: AppTextStyles.bodyMedium,
                  ),
                  if (hasAddress) ...[
                    const SizedBox(height: 2),
                    Text(
                      _selectedAddressFullText!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
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
                Text(widget.modelName, style: AppTextStyles.bodyMedium),
                if (widget.variant.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  AppBadge(label: widget.variant),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final deduction = widget.basePrice - widget.finalPayout;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _summaryRow('Base price', '₹ ${widget.basePrice}'),
          if (deduction > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            _summaryRow('Condition adjustment', '− ₹ $deduction'),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Divider(height: 1, thickness: 1, color: AppColors.border),
          ),
          Row(
            children: [
              Expanded(
                child: Text('Final payout', style: AppTextStyles.bodyMedium),
              ),
              Text(
                '₹ ${widget.finalPayout}',
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.onPrimarySoft,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      children: [
        Expanded(child: Text(label, style: AppTextStyles.bodySmall)),
        Text(value, style: AppTextStyles.priceSmall),
      ],
    );
  }

  Widget _buildReassurance() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: AppRadius.card,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.shield_outlined,
            size: 18,
            color: AppColors.onPrimarySoft,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Final price is confirmed at pickup after a quick check. '
              'Payment is instant.',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.onPrimarySoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
