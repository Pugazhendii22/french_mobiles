import 'package:flutter/material.dart';

import '../../features/shell/main_shell.dart';
import '../../models/checkup_result.dart';
import '../../shared/motion/motion.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/widgets.dart';

/// Final screen — lists every test with pass / fail / skip / N/A and an overall
/// verdict.
///
/// Anything that did not pass can be run again from here. A hardware test can
/// fail for reasons that are nothing to do with the hardware — a beep missed
/// because someone walked past, a permission dialog dismissed by reflex, a SIM
/// that was not in the phone yet — and without this the only remedy was to run
/// all nineteen tests again. The re-run replaces that test's row in place
/// rather than appending a second one.
class CheckupSummaryPage extends StatefulWidget {
  final List<CheckupResult> results;

  /// Runs one test again and returns its new result, or null if the user
  /// backed out. Null callback hides the retry affordance entirely, which is
  /// what a summary opened without an orchestrator behind it wants.
  final Future<CheckupResult?> Function(String key)? onRetest;

  /// Replaces the default "back to the home screen" behaviour of Done.
  ///
  /// The sell flow sets this so finishing the checkup returns to the sell
  /// flow with the results, rather than dropping the seller on the home
  /// screen half way through selling a phone.
  final VoidCallback? onDone;

  const CheckupSummaryPage({
    super.key,
    required this.results,
    this.onRetest,
    this.onDone,
  });

  @override
  State<CheckupSummaryPage> createState() => _CheckupSummaryPageState();
}

class _CheckupSummaryPageState extends State<CheckupSummaryPage> {
  late List<CheckupResult> results = List.of(widget.results);

  /// The test being re-run, so its row can show progress and the rest can be
  /// held still — two retests at once would race for the same hardware.
  String? _retesting;

  Future<void> _retest(CheckupResult result) async {
    final onRetest = widget.onRetest;
    if (onRetest == null || _retesting != null) return;

    setState(() => _retesting = result.key);
    final updated = await onRetest(result.key);
    if (!mounted) return;

    setState(() {
      _retesting = null;
      if (updated == null) return;
      final index = results.indexWhere((r) => r.key == updated.key);
      if (index >= 0) {
        results[index] = updated;
      } else {
        results.add(updated);
      }
    });
  }

  int _count(CheckupStatus status) =>
      results.where((r) => r.status == status).length;

  int get _passes => _count(CheckupStatus.pass);
  int get _fails => _count(CheckupStatus.fail);

  /// What the run amounts to, in the order that matters to someone selling a
  /// phone: a failure outranks everything, and an untested phone is not a
  /// passed one — so "all passed" has to mean every test actually ran.
  (IconData, Color, String) get _headline {
    if (results.isEmpty) {
      return (
        Icons.rule_rounded,
        AppColors.textSecondary,
        'Nothing tested yet'
      );
    }
    if (_fails > 0) {
      return (
        Icons.error_outline_rounded,
        AppColors.error,
        _fails == 1 ? '1 issue found' : '$_fails issues found',
      );
    }
    if (_passes == results.length) {
      return (Icons.verified_rounded, AppColors.success, 'All tests passed');
    }
    return (
      Icons.rule_rounded,
      AppColors.textSecondary,
      '$_passes of ${results.length} passed',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenGutter,
                AppSpacing.lg, AppSpacing.screenGutter, AppSpacing.lg),
            child: AppScreenHeader(
              title: 'Checkup Results',
              content: _verdict(),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                0,
                AppSpacing.screenGutter,
                AppSpacing.xxxl,
              ),
              children: [
                if (results.isEmpty)
                  const AppEmptyState(
                    icon: Icons.fact_check_outlined,
                    title: 'No results',
                    message: 'Run a test from the checkup list to see how '
                        'this phone scores.',
                  )
                else
                  // One enclosure around the whole report rather than a card
                  // per line: this is a single document, not a feed.
                  AppGroup(
                    children: [
                      for (var i = 0; i < results.length; i++)
                        AppReveal(index: i, child: _resultRow(results[i])),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _doneBar(context),
    );
  }

  /// The overall result, sitting on the page under the title. No panel: it is
  /// the headline for the list below, and boxing it would set it competing
  /// with the report itself.
  Widget _verdict() {
    final (icon, colour, label) = _headline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, color: colour, size: 28),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child:
                  Text(label, style: AppTextStyles.h3.copyWith(color: colour)),
            ),
          ],
        ),
        if (results.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              // Only the statuses that actually occurred; a row of zeroes
              // reads as noise.
              for (final status in CheckupStatus.values)
                if (_count(status) > 0)
                  AppBadge(
                    label: '${_count(status)} ${status.label.toLowerCase()}',
                    tone: status.badgeTone,
                    icon: status.icon,
                  ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _resultRow(CheckupResult result) {
    return AppSurface(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child:
                Icon(result.status.icon, color: result.status.color, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  result.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium,
                ),
                if ((result.detail ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(result.detail!, style: AppTextStyles.caption),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBadge(
                  label: result.status.label, tone: result.status.badgeTone),
              if (_canRetest(result)) ...[
                const SizedBox(height: AppSpacing.xs),
                _retestButton(result),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Every row can be run again, passes included — a pass can be a fluke as
  /// easily as a fail can be bad luck, and someone who wants to satisfy
  /// themselves about a result should not have to re-run the whole checkup.
  bool _canRetest(CheckupResult result) => widget.onRetest != null;

  Widget _retestButton(CheckupResult result) {
    final busy = _retesting == result.key;
    final blocked = _retesting != null && !busy;

    return TextButton.icon(
      onPressed: blocked ? null : () => _retest(result),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 2,
        ),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: AppColors.primary,
      ),
      icon: busy
          ? const SizedBox(
              height: 13,
              width: 13,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
          : const Icon(Icons.refresh_rounded, size: 15),
      label: Text(
        busy ? 'Running' : 'Retry',
        style: AppTextStyles.caption.copyWith(
          color: blocked ? AppColors.textTertiary : AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _doneBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.md,
        AppSpacing.screenGutter,
        AppSpacing.md + MediaQuery.paddingOf(context).bottom,
      ),
      child: AppPrimaryButton(
        label: widget.onDone == null ? 'Done' : 'Use these results',
        onPressed: widget.onDone ??
            () {
              MainShell.goHome();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
      ),
    );
  }
}
