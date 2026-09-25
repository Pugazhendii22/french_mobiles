import 'package:cloud_firestore/cloud_firestore.dart';

import '../shared/services/order_reference.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../firebase/catalog_firebase.dart';
import '../screens/login_page.dart';
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
  static const String _signedOutMessage =
      'Sign in to track the phones you have sold.';

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
    // Orders is a tab, so this State outlives any one sign-in — MainShell
    // keeps every visited tab mounted rather than rebuilding it on switch.
    // A one-off catalogAuth.currentUser read here would go stale the moment
    // someone signs in or out somewhere else (checkout, Profile's logout,
    // the Orders tab's own sign-in gate on first visit) and never notice,
    // which is also how a *different* signed-in user could end up staring
    // at the previous user's cached order list. Watching authStateChanges()
    // keeps this in step with sign-in wherever it happens.
    return StreamBuilder<User?>(
      stream: catalogAuth.authStateChanges(),
      initialData: catalogAuth.currentUser,
      builder: (context, authSnapshot) {
        final userId = authSnapshot.data?.uid;

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
                        ? Padding(
                            padding:
                                const EdgeInsets.all(AppSpacing.screenGutter),
                            child: AppEmptyState(
                              title: 'Sign in to see your orders',
                              message: _signedOutMessage,
                              icon: Icons.receipt_long_outlined,
                              branded: true,
                              retryLabel: 'Sign in',
                              onRetry: () =>
                                  context.pushScreen(const LoginPage()),
                            ),
                          )
                        : _buildList(userId),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
          return ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenGutter,
            ),
            itemCount: 3,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              thickness: 1,
              color: AppColors.border,
            ),
            itemBuilder: (_, __) => const OrderRowSkeleton(),
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
              branded: true,
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
          // A hairline between orders and nothing around them, the same as
          // the Saved list.
          separatorBuilder: (_, __) => const Divider(
            height: 1,
            thickness: 1,
            color: AppColors.border,
          ),
          itemBuilder: (context, index) => _rowFor(context, docs[index], index),
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
        reference: displayReference(doc.id, d['reference'] as String?),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const AppShimmer(width: 64, height: 64),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppShimmer(
                      width: 110,
                      height: AppTextStyles.overline.fontSize! *
                          AppTextStyles.overline.height!,
                      borderRadius: AppRadius.pill,
                    ),
                    const SizedBox(height: 2),
                    AppShimmer(
                      width: double.infinity,
                      height: AppTextStyles.bodyMedium.fontSize! *
                          AppTextStyles.bodyMedium.height!,
                      borderRadius: AppRadius.pill,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    AppShimmer(
                      width: 72,
                      height: AppTextStyles.priceSmall.fontSize! *
                          AppTextStyles.priceSmall.height!,
                      borderRadius: AppRadius.pill,
                    ),
                  ],
                ),
              ),
              // The chevron sets the row height when it is taller than the
              // text beside it.
              const SizedBox(width: 20, height: 20),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              AppShimmer(
                width: OrderStage.count * 8 + (OrderStage.count - 1) * 14,
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
    this.reference = '',
    required this.stage,
    required this.onTap,
  });

  final String modelName;
  final String storage;
  final String imageUrl;
  final int payout;
  final String date;

  /// The speakable code, shown so a seller can quote it without opening
  /// the order.
  ///
  /// Optional: it joins the subtitle through the same empty-string filter as
  /// storage and date, so a row without one simply does not show it. Orders
  /// placed before references existed are the reason.
  final String reference;
  final OrderStage stage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = [storage, date, reference]
        .where((s) => s.isNotEmpty)
        .join(' · ');

    // Deliberately the same shape as a Saved row: 64px photo, a quiet line
    // above, the name, then the figure. No card and no coloured edge — those
    // were chrome, and the progress strip below already carries the colour
    // that matters.
    return AppPressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                SizedBox(
                  height: 64,
                  width: 64,
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
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.overline.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        modelName.isEmpty ? 'Device' : modelName,
                        // One line, unlike Saved's two: a product title is
                        // marketing copy and wraps, an order's model name is
                        // short. Letting it wrap makes the row's height
                        // depend on the name, and a skeleton cannot then
                        // match it at every width.
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '₹ $payout',
                        // The same green the quote breakdown gives "You
                        // receive". This figure is that promise, later on.
                        style: AppTextStyles.priceSmall
                            .copyWith(color: AppColors.onPrimarySoft),
                      ),
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
            const SizedBox(height: AppSpacing.md),
            _progress(),
          ],
        ),
      ),
    );
  }

  /// Where the order has got to, as four steps and a name. Kept as it was.
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
      ],
    );
  }
}
