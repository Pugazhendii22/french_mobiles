import 'package:flutter/material.dart';

import '../../models/checkup_result.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/widgets.dart';

/// Shared chrome for a checkup test page.
///
/// Reproduces the structure the nine original tests already use — page
/// background, `Checkup · X` header, and a body that swaps to a verdict once
/// a result exists — so the newer tests are visually indistinguishable from
/// the ones written before it.
class CheckupTestShell extends StatelessWidget {
  const CheckupTestShell({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenGutter,
                AppSpacing.lg, AppSpacing.screenGutter, AppSpacing.lg),
            child: AppScreenHeader(title: 'Checkup · $title'),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// The instruction card every test opens with.
class CheckupInstruction extends StatelessWidget {
  const CheckupInstruction({
    super.key,
    required this.icon,
    required this.text,
    this.tone,
  });

  final IconData icon;
  final String text;

  /// Overrides the icon colour; defaults to the brand accent.
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Icon(icon, color: tone ?? AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.body.copyWith(
                fontSize: 13.5,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom controls for a test that can be retried.
///
/// Retry is new to this group of tests. The nine original pages offer only
/// pass / fail / skip, and are deliberately left alone — these tests earn a
/// retry because each depends on something transient: a sound the user may
/// have missed, a sensor that needs a second pass, a number misheard.
///
/// [onRetry] null hides the retry action, for the phase of a test where
/// retrying makes no sense (nothing has been attempted yet).
class CheckupActions extends StatelessWidget {
  const CheckupActions({
    super.key,
    required this.onIssue,
    required this.onSkip,
    this.onRetry,
    this.retryLabel = 'Retry',
    this.primary,
    this.primaryLabel,
    this.attempt = 1,
  });

  final VoidCallback onIssue;
  final VoidCallback onSkip;
  final VoidCallback? onRetry;
  final String retryLabel;

  /// Optional confirming action, e.g. "Yes, I heard it".
  final VoidCallback? primary;
  final String? primaryLabel;

  /// Shown beside retry once a test has been attempted more than once, so the
  /// user can see the app registered their earlier attempts.
  final int attempt;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (primary != null)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: primary,
              child: Text(
                primaryLabel ?? 'Continue',
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        if (primary != null) const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: onIssue,
                child: Text(
                  'Issue found',
                  style:
                      AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.borderStrong),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(
                    attempt > 1 ? '$retryLabel ($attempt)' : retryLabel,
                    style: AppTextStyles.body
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: onSkip,
            child: Text(
              'Skip this test',
              style: AppTextStyles.body.copyWith(color: AppColors.textTertiary),
            ),
          ),
        ),
      ],
    );
  }
}

/// Result plumbing shared by the retryable tests.
///
/// Mirrors the original pages exactly: hold a result, show a verdict, then
/// auto-pop after 1500ms so the orchestrator advances on its own.
mixin CheckupTestFlow<T extends StatefulWidget> on State<T> {
  CheckupResult? result;

  /// Stable identifiers written into every [CheckupResult] this page emits.
  String get testKey;
  String get testTitle;

  /// Called before a result is recorded, to release hardware.
  void disposeHardware() {}

  void setResult(CheckupResult value) {
    disposeHardware();
    if (!mounted) return;
    setState(() => result = value);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) Navigator.of(context).pop(result);
    });
  }

  void markPass(String detail) => setResult(CheckupResult(
        key: testKey,
        title: testTitle,
        status: CheckupStatus.pass,
        detail: detail,
      ));

  void markFail(String detail) => setResult(CheckupResult(
        key: testKey,
        title: testTitle,
        status: CheckupStatus.fail,
        detail: detail,
      ));

  void markNotAvailable(String detail) => setResult(CheckupResult(
        key: testKey,
        title: testTitle,
        status: CheckupStatus.notAvailable,
        detail: detail,
      ));

  void skipTest() {
    disposeHardware();
    Navigator.of(context).pop(CheckupResult(
      key: testKey,
      title: testTitle,
      status: CheckupStatus.skipped,
      detail: 'Skipped by user',
    ));
  }
}

/// The settled view shown for 1500ms before the page pops.
class CheckupVerdict extends StatelessWidget {
  const CheckupVerdict({super.key, required this.result});

  final CheckupResult result;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(result.status.icon, size: 56, color: result.status.color),
            const SizedBox(height: AppSpacing.lg),
            Text(
              result.status.label,
              style: AppTextStyles.h3.copyWith(color: result.status.color),
            ),
            if (result.detail != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                result.detail!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
