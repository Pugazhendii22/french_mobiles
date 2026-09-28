import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/checkup_result.dart';
import '../models/quote_breakdown.dart';
import '../shared/widgets/quote_breakdown_view.dart';

import 'package:french_mobiles/features/shell/main_shell.dart';

import '../firebase/catalog_firebase.dart';
import '../profile/account_pages.dart';
import '../shared/motion/motion.dart';
import '../shared/services/order_reference.dart';
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

  /// The itemised quote behind [finalPayout].
  ///
  /// Null for a checkout reached from somewhere that has no breakdown to
  /// give; the summary then shows the totals alone, as it always did.
  final QuoteBreakdown? quote;

  /// What the automatic checkup found, or empty when it was skipped.
  ///
  /// Written onto the order as evidence for the pickup agent. It never
  /// affected [finalPayout] — the seller's own answers did — so it is stored
  /// alongside the quote rather than inside it.
  final List<CheckupResult> checkupResults;

  const PickupCheckoutPage({
    super.key,
    required this.brandName,
    required this.modelDocId,
    required this.modelName,
    this.imageUrl,
    required this.variant,
    required this.basePrice,
    required this.finalPayout,
    this.quote,
    this.checkupResults = const [],
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

  /// Applies an address returned by either the picker or the add sheet. Both
  /// hand back the same key shape.
  void _applyAddress(Map<String, dynamic> result) {
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

  Future<void> _pickAddress() async {
    final result = await context.pushScreen<Map<String, dynamic>?>(
      const SavedAddressesPage(selectMode: true),
      transition: AppTransition.rise,
    );
    if (result != null) _applyAddress(result);
  }

  /// Opens the existing add-address sheet directly, skipping the list.
  ///
  /// Reuses AddEditAddressSheet rather than duplicating the form, so the
  /// label chips, geolocation and Firestore write are all the same code the
  /// profile screen uses. The sheet returns what it saved, so the new address
  /// is selected here immediately.
  Future<void> _addAddress() async {
    final user = catalogAuth.currentUser;
    if (user == null) {
      await context.pushScreen(const LoginPage(),
          transition: AppTransition.rise);
      return;
    }
    if (!mounted) return;

    final saved = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => AddEditAddressSheet(
        addressRef: catalogFirestore
            .collection('users')
            .doc(user.uid)
            .collection('addresses'),
      ),
    );

    if (!mounted || saved == null) return;
    _applyAddress(saved);
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
        final loggedIn = await context.pushScreen<bool>(const LoginPage(),
        );
        if (loggedIn != true) {
          setState(() => _placingOrder = false);
          return;
        }
        user = catalogAuth.currentUser;
      }

      if (user == null) {
        if (!mounted) return;
        setState(() => _placingOrder = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Unable to determine user after login')));
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
        // Who to expect at the door, copied onto the order rather than looked
        // up from `users/{uid}` later. The inspector's screen would otherwise
        // need one read per job to show a name, every time it opened — and a
        // seller who renames themselves afterwards should not retroactively
        // change who an already-collected order was from.
        if (user.displayName?.trim().isNotEmpty ?? false)
          'customerName': user.displayName!.trim(),
        if (user.phoneNumber?.trim().isNotEmpty ?? false)
          'customerPhone': user.phoneNumber!.trim(),
        'addressLabel': _selectedAddressLabel,
        'addressFullText': _selectedAddressFullText,
        'addressLatitude': _selectedAddressLat,
        'addressLongitude': _selectedAddressLng,
        'status': 'placed',
        // Stored so the payout can still be explained after the fact — at
        // pickup, in support, or in a dispute. Additive: nothing that read
        // this document before is affected.
        if (widget.quote != null) 'quote': widget.quote!.toMap(),
        if (widget.quote != null) 'quoteValidUntil':
            Timestamp.fromDate(widget.quote!.validUntil),
        // The automatic checkup, when it was run. Evidence for the agent
        // rather than an input to the price, so it sits beside the quote and
        // not inside it. Omitted entirely when the checkup was skipped, so a
        // skipped run is distinguishable from one that found nothing.
        if (widget.checkupResults.isNotEmpty)
          'checkup': [
            for (final result in widget.checkupResults)
              {
                'key': result.key,
                'title': result.title,
                'status': result.status.name,
                if (result.detail != null) 'detail': result.detail,
              },
          ],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // A speakable reference, minted before the write so it lands with the
      // order rather than in a second round trip. Null when one could not be
      // reserved, which is not worth failing a sale over — the order then
      // shows a slice of its document ID instead.
      final orders = catalogFirestore.collection('orders');
      final reference = await reserveOrderReference(orders);

      final ref = await orders.add({
        ...orderData,
        if (reference != null) 'reference': reference,
      });
      final orderId = ref.id;

      if (!mounted) return;

      // Replace the whole checkout flow with the confirmation. Everything
      // between home and here — address selection, the grading wizard,
      // variant and brand selection — is removed, so back from the
      // confirmation reaches home and a second order cannot be placed by
      // navigating backwards into a checkout whose order already exists.
      //
      // `route.isFirst` keeps HomePage, which main.dart installs as the
      // MaterialApp home and is therefore the bottom of the stack.
      // The shell remembers its tab, so returning to it is not the same
      // as returning Home. Say which.
      MainShell.goHome();
      Navigator.of(context).pushAndRemoveUntil(
        AppPageRoute<void>(
          builder: (_) => OrderTrackingPage(
            orderId: orderId,
            isConfirmation: true,
          ),
          transition: AppTransition.fadeThrough,
        ),
        (route) => route.isFirst,
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
              Row(
                children: [
                  Expanded(
                    child: Text('Pickup address', style: AppTextStyles.h3),
                  ),
                  TextButton.icon(
                    onPressed: _addAddress,
                    icon: const Icon(Icons.add_rounded,
                        size: 16, color: AppColors.primary),
                    label: Text(
                      'Add new',
                      style: AppTextStyles.label
                          .copyWith(color: AppColors.primary),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
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
                    AppAnimatedCount(
                      value: widget.finalPayout,
                      prefix: '₹ ',
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
          boxShadow: hasAddress ? AppShadows.card : null,
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

  /// Page level: this is a readout of what you already chose, not something
  /// to pick, so it needs no enclosure.
  Widget _buildDeviceCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
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

  /// Rules, not a box. The figures are already grouped under their own
  /// heading, so an enclosure only adds a line for the eye to cross.
  Widget _buildSummaryCard() {
    final deduction = widget.basePrice - widget.finalPayout;

    // The itemised quote if the wizard sent one. A single lumped "condition
    // adjustment" is what makes a seller suspect the number at the door: with
    // nothing to check it against, a fair revision and a bait-and-switch look
    // identical.
    final quote = widget.quote;
    if (quote != null) return QuoteBreakdownView(breakdown: quote);

    return AppGroup(
      bare: true,
      children: [
        _summaryRow('Base price', '₹ ${widget.basePrice}'),
        if (deduction > 0)
          _summaryRow('Condition adjustment', '− ₹ $deduction'),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Row(
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
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.bodySmall)),
          Text(value, style: AppTextStyles.priceSmall),
        ],
      ),
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
