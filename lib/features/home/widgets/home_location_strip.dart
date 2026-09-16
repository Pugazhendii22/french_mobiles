import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:french_mobiles/features/home/data/home_repository.dart';
import 'package:french_mobiles/shared/theme/app_colors.dart';
import 'package:french_mobiles/shared/theme/app_text_styles.dart';
import 'package:french_mobiles/shared/theme/app_theme.dart';

/// Delivery-address strip.
///
/// Signed out, it prompts to sign in. Signed in, it streams the user's
/// addresses and shows the default one; tapping opens the address picker.
class HomeLocationStrip extends StatelessWidget {
  const HomeLocationStrip({
    super.key,
    required this.repository,
    required this.uid,
    required this.onTap,
  });

  final HomeRepository repository;

  /// Null when signed out.
  final String? uid;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return _shell(context, text: 'Select delivery address', muted: true);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: repository.watchAddresses(uid!),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _shell(context, text: 'Address unavailable', muted: true);
        }

        final docs = snapshot.data?.docs ?? const [];
        final resolved = HomeRepository.resolveDisplayAddress(docs);

        return _shell(
          context,
          text: resolved ?? 'Add delivery address',
          muted: resolved == null,
        );
      },
    );
  }

  Widget _shell(
    BuildContext context, {
    required String text,
    required bool muted,
  }) {
    return Semantics(
      button: true,
      label: 'Delivery address: $text',
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.pill,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: AppRadius.pill,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_on_rounded,
                size: 16,
                color: AppColors.onPrimarySoft,
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: muted
                        ? AppColors.textSecondary
                        : AppColors.onPrimarySoft,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: AppColors.onPrimarySoft,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
