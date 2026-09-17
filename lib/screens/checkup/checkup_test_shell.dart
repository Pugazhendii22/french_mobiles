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
    this.busy = false,
  });

  final IconData icon;
  final String text;

  /// Overrides the icon colour; defaults to the brand accent.
  final Color? tone;

  /// Swaps the icon for a spinner while the test is working, for the tests
  /// whose instruction card doubles as their progress readout.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          if (busy)
            SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: tone ?? AppColors.primary,
              ),
            )
          else
            Icon(icon, color: tone ?? AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.body.copyWith(
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
    this.skipLabel = 'Skip this test',
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

  /// Overridden by the tests that run in steps, where skipping means this
  /// step rather than the whole test.
  final String skipLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (primary != null) ...[
          AppPrimaryButton(label: primaryLabel ?? 'Continue', onPressed: primary),
          const SizedBox(height: AppSpacing.md),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.field,
                  ),
                ),
                onPressed: onIssue,
                child: Text(
                  'Issue found',
                  style: AppTextStyles.button.copyWith(color: AppColors.error),
                ),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.borderStrong),
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.field,
                    ),
                  ),
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(
                    attempt > 1 ? '$retryLabel ($attempt)' : retryLabel,
                    style: AppTextStyles.button
                        .copyWith(color: AppColors.textPrimary),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: TextButton(
            onPressed: onSkip,
            child: Text(
              skipLabel,
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
///
/// [action] adds something for the user to do instead, for a verdict they can
/// act on — a denied permission they could go and grant. A page showing one
/// must hold rather than auto-pop, or the control is on screen for a second
/// and a half and then gone.
class CheckupVerdict extends StatelessWidget {
  const CheckupVerdict({super.key, required this.result, this.action});

  final CheckupResult result;
  final Widget? action;

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
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// What to offer when a permission has been permanently denied.
///
/// The app cannot ask again once the user has chosen "don't ask again", so
/// the only route left is the system settings screen. [onContinue] carries on
/// with the checkup, since the page holds instead of popping on its own.
class CheckupPermissionAction extends StatelessWidget {
  const CheckupPermissionAction({
    super.key,
    required this.onOpenSettings,
    required this.onContinue,
  });

  final VoidCallback onOpenSettings;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            elevation: 0,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.pill),
          ),
          onPressed: onOpenSettings,
          icon: const Icon(Icons.settings_outlined, size: 18),
          label: Text('Open Settings', style: AppTextStyles.button),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: onContinue,
          child: Text(
            'Continue without it',
            style:
                AppTextStyles.button.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// The lone "skip" affordance, for a test that runs itself and offers the
/// user nothing to confirm — there is no pass or fail for them to report, so
/// [CheckupActions] would be three buttons where one belongs.
class CheckupSkipButton extends StatelessWidget {
  const CheckupSkipButton({
    super.key,
    required this.onSkip,
    this.label = 'Skip this test',
  });

  final VoidCallback onSkip;

  /// Overridden by the tests that run in steps, where skipping means this
  /// step rather than the whole test.
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: onSkip,
        child: Text(
          label,
          style: AppTextStyles.body.copyWith(color: AppColors.textTertiary),
        ),
      ),
    );
  }
}
