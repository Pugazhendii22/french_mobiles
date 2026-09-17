import 'package:flutter/material.dart';

import '../shared/theme/app_colors.dart';
import '../shared/widgets/app_badge.dart';

/// Outcome for a single hardware autocheckup test.
///
/// Every test screen produces exactly one of these, written back to the
/// orchestrator when the page is popped.
enum CheckupStatus { pass, fail, skipped, notAvailable }

/// Simple pass / fail / skip record shared by all checkup test screens.
class CheckupResult {
  final String key;
  final String title;
  final CheckupStatus status;
  final String? detail;

  const CheckupResult({
    required this.key,
    required this.title,
    required this.status,
    this.detail,
  });
}

/// UI helpers so every screen and the summary page render a status the
/// same way (green pass / red fail / amber skipped).
///
/// Colours come from [AppColors] rather than being defined here, so a status
/// in the checkup matches the same status anywhere else in the app.
extension CheckupStatusVisuals on CheckupStatus {
  Color get color => switch (this) {
        CheckupStatus.pass => AppColors.success,
        CheckupStatus.fail => AppColors.error,
        CheckupStatus.skipped => AppColors.warning,
        CheckupStatus.notAvailable => AppColors.textSecondary,
      };

  /// The soft background matching [color], for a tinted panel or chip.
  Color get softColor => switch (this) {
        CheckupStatus.pass => AppColors.successSoft,
        CheckupStatus.fail => AppColors.errorSoft,
        CheckupStatus.skipped => AppColors.warningSoft,
        CheckupStatus.notAvailable => AppColors.surfaceMuted,
      };

  /// The [AppBadge] preset carrying this status, so status pills in the
  /// checkup are the same component used everywhere else.
  AppBadgeTone get badgeTone => switch (this) {
        CheckupStatus.pass => AppBadgeTone.success,
        CheckupStatus.fail => AppBadgeTone.error,
        CheckupStatus.skipped => AppBadgeTone.warning,
        CheckupStatus.notAvailable => AppBadgeTone.neutral,
      };

  IconData get icon => switch (this) {
        CheckupStatus.pass => Icons.check_circle_rounded,
        CheckupStatus.fail => Icons.cancel_rounded,
        CheckupStatus.skipped => Icons.remove_circle_outline_rounded,
        CheckupStatus.notAvailable => Icons.info_outline_rounded,
      };

  String get label => switch (this) {
        CheckupStatus.pass => 'PASS',
        CheckupStatus.fail => 'FAIL',
        CheckupStatus.skipped => 'SKIPPED',
        CheckupStatus.notAvailable => 'N/A',
      };
}
