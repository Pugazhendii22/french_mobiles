import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../firebase/catalog_firebase.dart';
import '../screens/order_tracking_page.dart';
import '../models/order_status.dart';
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

    return AppReveal(
      index: index,
      child: OrderRow(
        modelName: (d['modelName'] as String?) ?? '',
        storage: (d['storage'] as String?) ?? '',
        imageUrl: (d['imageUrl'] as String?) ?? '',
        payout: payout,
        date: _formatDate(d['createdAt'] as Timestamp?),
        stage: OrderStage.fromStatus(d['status'] as String?),
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
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The status edge, grey until a status is known.
          Container(width: 3, color: AppColors.border),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  Row(
                    children: [
                      AppShimmer(
                        width: 44,
                        height: 44,
                        borderRadius: AppRadius.field,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
                  const SizedBox(height: AppSpacing.md),
                  // The progress strip: four dots, three connectors, a label.
                  Row(
                    children: [
                      AppShimmer(
                        width: OrderStage.count * 8 +
                            (OrderStage.count - 1) * 14,
                        height: 8,
                        borderRadius: AppRadius.pill,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      AppShimmer(
                        width: 96,
                        height: AppTextStyles.caption.fontSize! *
                            AppTextStyles.caption.height!,
                        borderRadius: AppRadius.pill,
                      ),
                      const Spacer(),
                      // The chevron is 18 and taller than the caption beside
                      // it, so it sets the row's height. Leaving it out made
                      // the skeleton two pixels short.
                      const SizedBox(height: 18, width: 18),
                    ],
                  ),
                ],
              ),
            ),
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
    required this.stage,
    required this.onTap,
  });

  final String modelName;
  final String storage;
  final String imageUrl;
  final int payout;
  final String date;
  final OrderStage stage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = [storage, date].where((s) => s.isNotEmpty).join(' · ');

    return AppSurface(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Colour down the edge rather than a badge alone: scanning a list
            // of orders, the question is which still owes you money, and an
            // edge answers it before anything has been read.
            Container(width: 3, color: stage.color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          height: 44,
                          width: 44,
                          child: AppNetworkImage(
                            url: imageUrl,
                            fit: BoxFit.contain,
                            borderRadius: BorderRadius.zero,
                            placeholderIcon: Icons.smartphone_rounded,
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
                              if (subtitle.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  subtitle,
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
                    const SizedBox(height: AppSpacing.md),
                    _progress(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Where the order has got to, as four steps and a name.
  ///
  /// This replaces a divider and a status footer, and the divider was the
  /// problem: once every order stopped being its own card, a rule inside a
  /// row and a rule between rows looked identical, so there was no telling
  /// where one order ended and the next began.
  Widget _progress() {
    return Row(
      children: [
        for (var i = 1; i <= OrderStage.count; i++) ...[
          if (i > 1)
            Container(
              width: 14,
              height: 2,
              color: i <= stage.step ? stage.color : AppColors.border,
            ),
          Container(
            height: 8,
            width: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i <= stage.step ? stage.color : AppColors.border,
            ),
          ),
        ],
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            stage.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(color: stage.color),
          ),
        ),
        const Icon(
          Icons.chevron_right_rounded,
          size: 18,
          color: AppColors.textTertiary,
        ),
      ],
    );
  }
}
