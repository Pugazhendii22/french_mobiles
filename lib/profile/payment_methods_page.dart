import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../firebase/catalog_firebase.dart';
import '../shared/theme/app_colors.dart';
import '../shared/theme/app_text_styles.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/widgets.dart';

/// Where a payout is sent.
///
/// This page used to show two invented UPI IDs — `alex.shopping@okaxis` and
/// `9876543210@ybl` — presented as the signed-in user's own saved accounts.
/// In an app that pays people money, showing a stranger's payout address as
/// if it were theirs is worse than showing nothing: it invites someone to
/// assume their money is already routed somewhere it is not.
///
/// Stored at `users/{uid}/paymentMethods`, mirroring how addresses work, with
/// the same single-default rule.
class PaymentMethodsPage extends StatefulWidget {
  const PaymentMethodsPage({super.key});

  @override
  State<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends State<PaymentMethodsPage> {
  CollectionReference<Map<String, dynamic>>? _methodsRef;

  /// Subscribed once: a stream built during build re-listens every frame.
  Stream<QuerySnapshot<Map<String, dynamic>>>? _methodsStream;

  @override
  void initState() {
    super.initState();
    try {
      final user = catalogAuth.currentUser;
      if (user != null) {
        _methodsRef = catalogFirestore
            .collection('users')
            .doc(user.uid)
            .collection('paymentMethods');
      }
    } catch (_) {
      // main() tolerates Firebase failing to initialise, so this page has to
      // as well. Without a collection it shows the signed-out state rather
      // than taking the profile down with it.
    }
  }

  Future<void> _add() async {
    final ref = _methodsRef;
    if (ref == null) return;

    final upiId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => const _AddUpiSheet(),
    );

    if (upiId == null || !mounted) return;

    try {
      // The first one added becomes the default, so a user who adds exactly
      // one is never left with a payout that has nowhere to go.
      final existing = await ref.get();
      await ref.add({
        'upiId': upiId,
        'isDefault': existing.docs.isEmpty,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  Future<void> _setDefault(String docId) async {
    final ref = _methodsRef;
    if (ref == null) return;
    try {
      final batch = catalogFirestore.batch();
      final snap = await ref.get();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'isDefault': doc.id == docId});
      }
      await batch.commit();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to set default: $e')));
    }
  }

  Future<void> _remove(String docId, bool wasDefault) async {
    final ref = _methodsRef;
    if (ref == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this UPI ID?'),
        content: const Text(
          'Payouts will not be sent here any more.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Remove',
                style: AppTextStyles.label.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.doc(docId).delete();

      // Removing the default would otherwise leave every remaining account
      // non-default, and the payout with no destination.
      if (wasDefault) {
        final remaining = await ref.orderBy('createdAt').limit(1).get();
        if (remaining.docs.isNotEmpty) {
          await remaining.docs.first.reference.update({'isDefault': true});
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not remove: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(AppSpacing.screenGutter,
                    AppSpacing.lg, AppSpacing.screenGutter, AppSpacing.lg),
                child: AppScreenHeader(title: 'Payment methods'),
              ),
              Expanded(child: _body()),
            ],
          ),
        ),
        bottomNavigationBar: _methodsRef == null
            ? null
            : AppBottomBar(
                child: AppPrimaryButton(
                  label: 'Add a UPI ID',
                  icon: Icons.add_rounded,
                  onPressed: _add,
                ),
              ),
      ),
    );
  }

  Widget _body() {
    final ref = _methodsRef;
    if (ref == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: AppEmptyState(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Sign in to add a payout account',
            message: 'Your UPI details are saved to your account so a payout '
                'can reach you.',
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _methodsStream ??=
          ref.orderBy('createdAt', descending: false).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final docs = snapshot.data?.docs ?? const [];
        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: AppEmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: 'No payout account yet',
                message: 'Add the UPI ID you want to be paid on. You can do '
                    'this before or after booking a pickup.',
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenGutter, 0,
              AppSpacing.screenGutter, AppSpacing.xxxl),
          children: [
            Text('Where we send your payout', style: AppTextStyles.bodySmall),
            const SizedBox(height: AppSpacing.md),
            AppGroup(
              children: [
                for (final doc in docs) _row(doc),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _payoutNote(),
          ],
        );
      },
    );
  }

  Widget _row(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final upiId = (data['upiId'] ?? '').toString();
    final isDefault = data['isDefault'] == true;

    return AppSurface(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      onTap: isDefault ? null : () => _setDefault(doc.id),
      child: Row(
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: const BoxDecoration(
              color: AppColors.surfaceMuted,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.account_balance_wallet_outlined,
                size: 18, color: AppColors.textSecondary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(upiId,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyMedium),
                    ),
                    if (isDefault) ...[
                      const SizedBox(width: AppSpacing.sm),
                      const AppBadge(
                          label: 'DEFAULT', tone: AppBadgeTone.primary),
                    ],
                  ],
                ),
                if (!isDefault) ...[
                  const SizedBox(height: 2),
                  Text('Tap to make this the default',
                      style: AppTextStyles.caption),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: () => _remove(doc.id, isDefault),
            icon: const Icon(Icons.delete_outline_rounded,
                size: 20, color: AppColors.textTertiary),
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }

  Widget _payoutNote() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: AppRadius.card,
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt_rounded,
              size: 18, color: AppColors.onPrimarySoft),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Payouts are released to your default account once your device '
              'passes inspection.',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.onPrimarySoft),
            ),
          ),
        ],
      ),
    );
  }
}

/// Collects a UPI ID.
class _AddUpiSheet extends StatefulWidget {
  const _AddUpiSheet();

  @override
  State<_AddUpiSheet> createState() => _AddUpiSheetState();
}

class _AddUpiSheetState extends State<_AddUpiSheet> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// A UPI ID is `handle@provider`. Checked here because a typo means the
  /// money goes nowhere, and the user finds out at payout rather than now.
  String? _validate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Enter your UPI ID';

    final parts = trimmed.split('@');
    if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) {
      return 'A UPI ID looks like yourname@bank';
    }
    if (trimmed.contains(' ')) return 'A UPI ID cannot contain spaces';
    return null;
  }

  void _submit() {
    final problem = _validate(_controller.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md,
              AppSpacing.xl, AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: AppRadius.pill,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Add a UPI ID', style: AppTextStyles.h2),
              const SizedBox(height: AppSpacing.xs),
              Text('This is where your payout will be sent.',
                  style: AppTextStyles.bodySmall),
              const SizedBox(height: AppSpacing.xl),
              TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                style: AppTextStyles.body,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: 'yourname@bank',
                  errorText: _error,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppPrimaryButton(label: 'Save', onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}
