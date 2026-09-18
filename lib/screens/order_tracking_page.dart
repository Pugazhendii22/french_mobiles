import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:french_mobiles/features/shell/main_shell.dart';

import '../firebase/catalog_firebase.dart';
import '../shared/motion/motion.dart';
import '../shared/theme/app_colors.dart';
import '../shared/theme/app_text_styles.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/widgets.dart';

class OrderTrackingPage extends StatefulWidget {
  final String orderId;

  /// True when this screen is the confirmation shown immediately after an
  /// order is placed, rather than an order opened from the orders list.
  ///
  /// In that case the checkout stack has already been cleared by the caller,
  /// the header hides its back affordance, a Go to home action is shown, and
  /// a system back gesture is routed to home. Browsing an existing order from
  /// the list keeps ordinary back behaviour.
  final bool isConfirmation;

  const OrderTrackingPage({
    super.key,
    required this.orderId,
    this.isConfirmation = false,
  });

  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage> {
  /// Pickup milestones, in order. Index + 1 matches the `currentStep` the
  /// order's `status` field maps to.
  static const List<(IconData, String, String)> _steps = [
    (
      Icons.receipt_long_outlined,
      'Order placed',
      'We have your request and are assigning an agent.',
    ),
    (
      Icons.person_pin_circle_outlined,
      'Agent assigned',
      'A pickup partner is on the way to your address.',
    ),
    (
      Icons.fact_check_outlined,
      'Inspection',
      'Your device is being verified against its grading.',
    ),
    (
      Icons.payments_outlined,
      'Paid',
      'Payment has been released to you.',
    ),
  ];

  /// Returns to the first route in the stack, which is HomePage.
  void _goHome() {
    MainShell.goHome();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    // Belt and braces. The caller already cleared the checkout stack, so the
    // only route beneath this one is home — but intercepting the pop makes
    // the destination explicit rather than incidental, and covers the
    // predictive-back gesture as well as the hardware button.
    return PopScope(
      canPop: !widget.isConfirmation,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _goHome();
      },
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Theme(
      data: AppTheme.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: catalogFirestore
                .collection('orders')
                .doc(widget.orderId)
                .snapshots(),
            builder: (context, snapshot) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenGutter,
                  AppSpacing.lg,
                  AppSpacing.screenGutter,
                  AppSpacing.xxl,
                ),
                children: [
                  AppScreenHeader(
                    title: widget.isConfirmation
                        ? 'Order confirmed'
                        : 'Track sell order',
                    // Nothing to go back to from a confirmation: the flow
                    // that led here no longer exists on the stack.
                    showBack: !widget.isConfirmation,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  ..._buildContent(snapshot),
                ],
              );
            },
          ),
        ),
        bottomNavigationBar: widget.isConfirmation
            ? AppBottomBar(
                child: AppPrimaryButton(
                  label: 'Go to home',
                  icon: Icons.home_rounded,
                  onPressed: _goHome,
                ),
              )
            : null,
      ),
    );
  }

  List<Widget> _buildContent(
    AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const [
        AppShimmer(width: double.infinity, height: 88),
        SizedBox(height: AppSpacing.lg),
        AppShimmer(width: double.infinity, height: 240),
      ];
    }

    if (!snapshot.hasData || !snapshot.data!.exists) {
      return const [
        AppEmptyState(
          title: 'Order not found',
          message: 'We could not find this order.',
          icon: Icons.receipt_long_outlined,
        ),
      ];
    }

    final d = snapshot.data!.data()!;

    final String? status = d['status'] as String?;
    int currentStep = 1;
    switch (status) {
      case 'placed':
        currentStep = 1;
        break;
      case 'agent_assigned':
        currentStep = 2;
        break;
      case 'inspection':
        currentStep = 3;
        break;
      case 'paid':
        currentStep = 4;
        break;
      default:
        currentStep = 1;
    }

    final modelName = (d['modelName'] as String?) ?? '';
    final storage = (d['storage'] as String?) ?? '';
    final finalPayout = (d['finalPayout'] is num)
        ? (d['finalPayout'] as num).toInt()
        : int.tryParse('${d['finalPayout']}') ?? 0;
    final addressFull = (d['addressFullText'] as String?) ?? '';

    return [
      AppReveal(index: 0, child: _buildConfirmation()),
      const SizedBox(height: AppSpacing.lg),
      AppReveal(index: 1, child: _buildTimeline(currentStep)),
      const SizedBox(height: AppSpacing.lg),
      AppReveal(
        index: 2,
        child: _buildDetails(modelName, storage, finalPayout, addressFull),
      ),
    ];
  }

  Widget _buildConfirmation() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.successSoft,
        borderRadius: AppRadius.card,
      ),
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: AppMotion.slow,
            curve: AppMotion.emphasis,
            builder: (context, v, child) =>
                Transform.scale(scale: v, child: child),
            child: const Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 32,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Order placed successfully',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Order ID: ${widget.orderId}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(int currentStep) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Order progress', style: AppTextStyles.h3),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < _steps.length; i++)
            _TimelineRow(
              icon: _steps[i].$1,
              title: _steps[i].$2,
              description: _steps[i].$3,
              done: i + 1 <= currentStep,
              active: i + 1 == currentStep,
              isLast: i == _steps.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _buildDetails(
    String modelName,
    String storage,
    int finalPayout,
    String addressFull,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Order details', style: AppTextStyles.h3),
          const SizedBox(height: AppSpacing.md),
          if (modelName.isNotEmpty)
            _detailRow(
              'Device',
              [modelName, storage].where((s) => s.isNotEmpty).join(' · '),
            ),
          _detailRow('Payout', '₹ $finalPayout'),
          if (addressFull.isNotEmpty) _detailRow('Pickup', addressFull),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: AppTextStyles.caption),
          ),
          Expanded(
            flex: 3,
            child: Text(value, style: AppTextStyles.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// One milestone in the pickup timeline, with the connector to the next.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.done,
    required this.active,
    required this.isLast,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool done;
  final bool active;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final markColor = done ? AppColors.primary : AppColors.surfaceMuted;
    final iconColor = done ? AppColors.onPrimary : AppColors.textTertiary;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 32,
                width: 32,
                decoration: BoxDecoration(
                  color: markColor,
                  shape: BoxShape.circle,
                  border: active
                      ? Border.all(color: AppColors.primarySoft, width: 3)
                      : null,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 16, color: iconColor),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    color: done ? AppColors.primary : AppColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: done
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (active) ...[
                        const SizedBox(width: AppSpacing.sm),
                        const AppBadge(
                          label: 'NOW',
                          tone: AppBadgeTone.primary,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(description, style: AppTextStyles.caption),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
