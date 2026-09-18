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
class CheckupSummaryPage extends StatelessWidget {
  final List<CheckupResult> results;

  const CheckupSummaryPage({super.key, required this.results});

  int _count(CheckupStatus status) =>
      results.where((r) => r.status == status).length;

  int get _passes => _count(CheckupStatus.pass);
  int get _fails => _count(CheckupStatus.fail);

  /// What the run amounts to, in the order that matters to someone selling a
  /// phone: a failure outranks everything, and an untested phone is not a
  /// passed one — so "all passed" has to mean every test actually ran.
  (IconData, Color, String) get _headline {
    if (results.isEmpty) {
      return (Icons.rule_rounded, AppColors.textSecondary, 'Nothing tested yet');
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
              child: Text(label, style: AppTextStyles.h3.copyWith(color: colour)),
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
            child: Icon(result.status.icon, color: result.status.color, size: 20),
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
          AppBadge(label: result.status.label, tone: result.status.badgeTone),
        ],
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
        label: 'Done',
        onPressed: () {
          MainShell.goHome();
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
      ),
    );
  }
}
