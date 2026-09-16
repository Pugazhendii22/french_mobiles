import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:french_mobiles/features/home/data/home_repository.dart';
import 'package:french_mobiles/shared/theme/app_colors.dart';
import 'package:french_mobiles/shared/theme/app_text_styles.dart';
import 'package:french_mobiles/shared/theme/app_theme.dart';

/// Greeting + avatar row at the top of the home screen.
///
/// The name comes from the user's Firestore profile document, falling back to
/// the auth display name, then to "Guest".
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.repository,
    required this.onProfileTap,
  });

  final HomeRepository repository;
  final VoidCallback onProfileTap;

  /// Collapses repeated words and drops a bare "hello" that some accounts
  /// carry as their display name.
  static String? _cleanDisplayName(String? raw) {
    final name = raw?.trim() ?? '';
    if (name.isEmpty) return null;
    final words = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final cleaned = words.toSet().join(' ');
    if (cleaned.isEmpty) return null;
    if (cleaned.toLowerCase() == 'hello') return null;
    return cleaned;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: repository.watchAuthState(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;

        if (user == null) {
          return _row(context, name: null, photoUrl: null);
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: repository.watchUserDoc(user.uid),
          builder: (context, userSnapshot) {
            String? name;
            String? photoUrl;

            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              final data = userSnapshot.data!.data();
              name = _cleanDisplayName(data?['name'] as String?);
              photoUrl = (data?['photoUrl'] as String?)?.trim();
            }

            name ??= _cleanDisplayName(user.displayName);
            photoUrl ??= user.photoURL;

            return _row(context, name: name, photoUrl: photoUrl);
          },
        );
      },
    );
  }

  Widget _row(BuildContext context, {String? name, String? photoUrl}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Hello, ${name ?? 'Guest'}', style: AppTextStyles.h2),
              const SizedBox(height: 2),
              Text(
                'What are you selling today?',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        _Avatar(photoUrl: photoUrl, onTap: onProfileTap),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.photoUrl, required this.onTap});

  final String? photoUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;

    return Semantics(
      button: true,
      label: 'Open profile',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.card,
            image: hasPhoto
                ? DecorationImage(
                    image: NetworkImage(photoUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          alignment: Alignment.center,
          child: hasPhoto
              ? null
              : const Icon(
                  Icons.person_outline_rounded,
                  size: 22,
                  color: AppColors.textSecondary,
                ),
        ),
      ),
    );
  }
}
