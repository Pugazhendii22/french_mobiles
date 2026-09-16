import 'package:flutter/material.dart';

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
extension CheckupStatusVisuals on CheckupStatus {
  Color get color => switch (this) {
        CheckupStatus.pass => const Color(0xFF16A34A),
        CheckupStatus.fail => const Color(0xFFDC2626),
        CheckupStatus.skipped => const Color(0xFFF59E0B),
        CheckupStatus.notAvailable => const Color(0xFF6B7280),
      };

  IconData get icon => switch (this) {
        CheckupStatus.pass => Icons.check_circle,
        CheckupStatus.fail => Icons.cancel,
        CheckupStatus.skipped => Icons.remove_circle_outline,
        CheckupStatus.notAvailable => Icons.info_outline,
      };

  String get label => switch (this) {
        CheckupStatus.pass => 'PASS',
        CheckupStatus.fail => 'FAIL',
        CheckupStatus.skipped => 'SKIPPED',
        CheckupStatus.notAvailable => 'N/A',
      };
}