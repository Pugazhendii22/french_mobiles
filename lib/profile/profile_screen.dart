import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../firebase/catalog_firebase.dart';
import '../screens/edit_profile_page.dart';
import '../shared/motion/motion.dart';
import '../shared/theme/app_colors.dart';
import '../shared/theme/app_text_styles.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/widgets.dart';
import 'account_pages.dart';
import 'orders_page.dart';
import 'support_page.dart';
import 'wishlist_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  void _open(Widget page) {
    context.pushScreen(page);
  }

  void _confirmLogout() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
        title: Text('Confirm logout', style: AppTextStyles.h3),
        content: Text(
          'Are you sure you want to log out of your account?',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTextStyles.label.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              // Captured before the await: the dialog can be dismissed while
              // sign-out is in flight, and its context would then be dead.
              final navigator = Navigator.of(context);
              await catalogAuth.signOut();
              navigator.pop();
              navigator.popUntil((route) => route.isFirst);
            },
            child: Text(
              'Log out',
              style: AppTextStyles.label.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = catalogAuth.currentUser;

    return Theme(
      data: AppTheme.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenGutter,
              AppSpacing.lg,
              AppSpacing.screenGutter,
              AppSpacing.xxl,
            ),
            children: [
              const AppScreenHeader(title: 'My profile'),
              const SizedBox(height: AppSpacing.xl),
              if (user == null)
                const AppEmptyState(
                  title: "You're not signed in",
                  message: 'Sign in to view your profile.',
                  icon: Icons.person_outline_rounded,
                )
              else ...[
                AppReveal(index: 0, child: _buildHeaderCard(user.uid)),
                const SizedBox(height: AppSpacing.xl),
                AppReveal(index: 1, child: _buildQuickActions()),
                const SizedBox(height: AppSpacing.xl),
                Text('Account', style: AppTextStyles.h3),
                const SizedBox(height: AppSpacing.md),
                _buildMenu([
                  (Icons.location_on_outlined, 'Saved addresses',
                      () => _open(const SavedAddressesPage())),
                  (Icons.credit_card_outlined, 'Payment methods',
                      () => _open(const PaymentMethodsPage())),
                  (Icons.notifications_none_rounded,
                      'Notification preferences',
                      () => _open(const NotificationPreferencesPage())),
                  (Icons.lock_outline_rounded, 'Privacy & security',
                      () => _open(const PrivacySecurityPage())),
                ]),
                const SizedBox(height: AppSpacing.xl),
                Text('Support', style: AppTextStyles.h3),
                const SizedBox(height: AppSpacing.md),
                _buildMenu([
                  (Icons.help_outline_rounded, 'Help centre',
                      () => _open(const HelpCenterPage())),
                  (Icons.support_agent_rounded, 'Contact support',
                      () => _open(const SupportPage())),
                  (Icons.info_outline_rounded, 'About us',
                      () => _open(const AboutUsPage())),
                ]),
                const SizedBox(height: AppSpacing.xl),
                OutlinedButton.icon(
                  onPressed: _confirmLogout,
                  icon: const Icon(
                    Icons.logout_rounded,
                    size: 18,
                    color: AppColors.error,
                  ),
                  label: Text(
                    'Log out',
                    style: AppTextStyles.button.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(String uid) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: catalogFirestore.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const AppShimmer(width: double.infinity, height: 112);
        }

        final data = snapshot.data!.data() ?? {};
        final name = (data['name'] as String?)?.trim() ?? 'Not provided';
        final email = (data['email'] as String?)?.trim() ?? 'Not provided';
        final phone = (data['phone'] as String?)?.trim() ?? '';
        final photoUrl = (data['photoUrl'] as String?)?.trim() ?? '';

        return Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.card,
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              Container(
                height: 60,
                width: 60,
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                child: photoUrl.isNotEmpty
                    ? AppNetworkImage(
                        url: photoUrl,
                        height: 60,
                        width: 60,
                        fit: BoxFit.cover,
                        borderRadius: BorderRadius.zero,
                        placeholderIcon: Icons.person_outline_rounded,
                      )
                    : const Icon(
                        Icons.person_outline_rounded,
                        size: 28,
                        color: AppColors.textTertiary,
                      ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.h3,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      phone.isNotEmpty ? phone : email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              TextButton(
                onPressed: () => _open(const EditProfilePage()),
                child: Text(
                  'Edit',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    final actions = <(IconData, String, VoidCallback)>[
      (Icons.receipt_long_outlined, 'Orders', () => _open(const OrdersPage())),
      (
        Icons.favorite_border_rounded,
        'Wishlist',
        () => _open(const WishlistPage())
      ),
      (
        Icons.support_agent_rounded,
        'Support',
        () => _open(const SupportPage())
      ),
    ];

    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.md),
          Expanded(
            child: InkWell(
              onTap: actions[i].$3,
              borderRadius: AppRadius.card,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.lg,
                  horizontal: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.card,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(actions[i].$1, size: 22, color: AppColors.primary),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      actions[i].$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMenu(List<(IconData, String, VoidCallback)> items) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                indent: AppSpacing.lg,
                endIndent: AppSpacing.lg,
                color: AppColors.border,
              ),
            AppListTile(
              title: items[i].$2,
              leadingIcon: items[i].$1,
              onTap: items[i].$3,
            ),
          ],
        ],
      ),
    );
  }
}
