import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../firebase/catalog_firebase.dart';
import '../screens/order_tracking_page.dart';
import '../shared/motion/motion.dart';
import '../shared/theme/app_colors.dart';
import '../shared/theme/app_text_styles.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/widgets.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  static const String _emptyMessage =
      'No orders yet — sell your first phone to see it here';

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  AppBadgeTone _statusTone(String? status) {
    switch (status) {
      case 'placed':
        return AppBadgeTone.warning;
      case 'agent_assigned':
        return AppBadgeTone.primary;
      case 'inspection':
        return AppBadgeTone.neutral;
      case 'paid':
        return AppBadgeTone.success;
      default:
        return AppBadgeTone.warning;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'placed':
        return 'Order Placed';
      case 'agent_assigned':
        return 'Agent Assigned';
      case 'inspection':
        return 'Under Inspection';
      case 'paid':
        return 'Completed & Paid';
      default:
        return 'Processing';
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = catalogAuth.currentUser?.uid;

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
                child: AppScreenHeader(title: 'My sell orders'),
              ),
              Expanded(
                child: userId == null
                    ? const Padding(
                        padding: EdgeInsets.all(AppSpacing.screenGutter),
                        child: AppEmptyState(
                          title: 'No orders yet',
                          message: _emptyMessage,
                          icon: Icons.receipt_long_outlined,
                        ),
                      )
                    : _buildList(userId),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One subscription per signed-in user, not one per frame.
  ///
  /// A stream created inside build is re-established on every rebuild, and
  /// each new listener bills a fresh read of every document it matches — the
  /// whole order list, every time.
  Stream<QuerySnapshot<Map<String, dynamic>>>? _ordersStream;
  String? _ordersUid;

  Stream<QuerySnapshot<Map<String, dynamic>>> _ordersFor(String userId) {
    if (_ordersUid != userId || _ordersStream == null) {
      _ordersUid = userId;
      _ordersStream = catalogFirestore
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots();
    }
    return _ordersStream!;
  }

  Widget _buildList(String userId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _ordersFor(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenGutter,
            ),
            children: const [
              AppGroup(
                children: [
                  OrderRowSkeleton(),
                  OrderRowSkeleton(),
                  OrderRowSkeleton(),
                ],
              ),
            ],
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.screenGutter),
            child: AppEmptyState(
              title: 'No orders yet',
              message: _emptyMessage,
              icon: Icons.receipt_long_outlined,
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenGutter,
            0,
            AppSpacing.screenGutter,
            AppSpacing.xxl,
          ),
          children: [
            // One enclosure around the whole list rather than a card per
            // order. These are entries in a ledger, not separate objects, and
            // a box each made the page read as a stack of containers.
            AppGroup(
              children: [
                for (var index = 0; index < docs.length; index++)
                  _rowFor(context, docs[index], index),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _rowFor(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    int index,
  ) {
    final d = doc.data();

    final payout = (d['finalPayout'] is num)
        ? (d['finalPayout'] as num).toInt()
        : int.tryParse('${d['finalPayout']}') ?? 0;
    final status = d['status'] as String?;

    return AppReveal(
      index: index,
      child: OrderRow(
        modelName: (d['modelName'] as String?) ?? '',
        storage: (d['storage'] as String?) ?? '',
        imageUrl: (d['imageUrl'] as String?) ?? '',
        payout: payout,
        date: _formatDate(d['createdAt'] as Timestamp?),
        statusLabel: _statusLabel(status),
        statusTone: _statusTone(status),
        onTap: () => context.pushScreen(OrderTrackingPage(orderId: doc.id)),
      ),
    );
  }
}

/// The shape of an [OrderRow] before the orders arrive.
///
/// Mirrors the row's structure rather than guessing a height. The height it
/// once stood in for was 15px short, so a list of three shifted by 45px the
/// moment the data landed — the jump a skeleton exists to prevent. Built from
/// the same pieces, it stays right when the row changes.
@visibleForTesting
class OrderRowSkeleton extends StatelessWidget {
  const OrderRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Row(
            children: [
              AppShimmer(
                width: 52,
                height: 52,
                borderRadius: AppRadius.field,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The two text lines the card reserves: model name, then
                    // storage and date.
                    AppShimmer(
                      width: double.infinity,
                      height: AppTextStyles.bodyMedium.fontSize! *
                          AppTextStyles.bodyMedium.height!,
                      borderRadius: AppRadius.pill,
                    ),
                    const SizedBox(height: 2),
                    AppShimmer(
                      width: 90,
                      height: AppTextStyles.caption.fontSize! *
                          AppTextStyles.caption.height!,
                      borderRadius: AppRadius.pill,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppShimmer(
                width: 64,
                height: AppTextStyles.price.fontSize! *
                    AppTextStyles.price.height!,
                borderRadius: AppRadius.pill,
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Divider(height: 1, thickness: 1, color: AppColors.border),
          ),
          Row(
            children: [
              // An AppBadge is its overline line-height plus 3px of padding
              // either side.
              AppShimmer(
                width: 88,
                height: AppTextStyles.overline.fontSize! *
                        AppTextStyles.overline.height! +
                    6,
                borderRadius: AppRadius.pill,
              ),
              const Spacer(),
              AppShimmer(
                width: 56,
                height: AppTextStyles.label.fontSize! *
                    AppTextStyles.label.height!,
                borderRadius: AppRadius.pill,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

@visibleForTesting
class OrderRow extends StatelessWidget {
  const OrderRow({
    super.key,
    required this.modelName,
    required this.storage,
    required this.imageUrl,
    required this.payout,
    required this.date,
    required this.statusLabel,
    required this.statusTone,
    required this.onTap,
  });

  final String modelName;
  final String storage;
  final String imageUrl;
  final int payout;
  final String date;
  final String statusLabel;
  final AppBadgeTone statusTone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
          children: [
            Row(
              children: [
                Container(
                  height: 52,
                  width: 52,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: AppRadius.field,
                  ),
                  child: AppNetworkImage(
                    url: imageUrl,
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
                        modelName.isEmpty ? 'Device' : modelName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium,
                      ),
                      if (storage.isNotEmpty || date.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          [storage, date].where((s) => s.isNotEmpty).join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text('₹ $payout', style: AppTextStyles.price),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Divider(height: 1, thickness: 1, color: AppColors.border),
            ),
            Row(
              children: [
                AppBadge(label: statusLabel, tone: statusTone),
                const Spacer(),
                Text(
                  'Track',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
