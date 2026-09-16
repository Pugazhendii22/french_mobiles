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

  Widget _buildList(String userId) {
    final stream = catalogFirestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenGutter,
            ),
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (_, __) =>
                const AppShimmer(width: double.infinity, height: 116),
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

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenGutter,
            0,
            AppSpacing.screenGutter,
            AppSpacing.xxl,
          ),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final d = doc.data();

            final modelName = (d['modelName'] as String?) ?? '';
            final storage = (d['storage'] as String?) ?? '';
            final imageUrl = (d['imageUrl'] as String?) ?? '';
            final status = d['status'] as String?;
            final payout = (d['finalPayout'] is num)
                ? (d['finalPayout'] as num).toInt()
                : int.tryParse('${d['finalPayout']}') ?? 0;
            final createdAt = d['createdAt'] as Timestamp?;

            return AppReveal(
              index: index,
              child: _OrderCard(
                modelName: modelName,
                storage: storage,
                imageUrl: imageUrl,
                payout: payout,
                date: _formatDate(createdAt),
                statusLabel: _statusLabel(status),
                statusTone: _statusTone(status),
                onTap: () =>
                    context.pushScreen(OrderTrackingPage(orderId: doc.id)),
              ),
            );
          },
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
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
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.card,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.card,
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.card,
        ),
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
      ),
    );
  }
}
