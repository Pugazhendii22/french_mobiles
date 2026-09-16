import 'package:flutter/material.dart';

import '../../models/checkup_result.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/widgets.dart';

/// Final screen — lists every test with pass / fail / skip / N/A and an overall
/// count.
class CheckupSummaryPage extends StatelessWidget {
  final List<CheckupResult> results;

  const CheckupSummaryPage({super.key, required this.results});

  int get _passes => results.where((r) => r.status == CheckupStatus.pass).length;
  int get _fails => results.where((r) => r.status == CheckupStatus.fail).length;
  int get _skips => results.where((r) => r.status == CheckupStatus.skipped).length;
  int get _notAvailable => results.where((r) => r.status == CheckupStatus.notAvailable).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(AppSpacing.screenGutter,
                AppSpacing.lg, AppSpacing.screenGutter, AppSpacing.lg),
            child: AppScreenHeader(title: 'Checkup Results'),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              children: [
                _headlineCard(),
                const SizedBox(height: 16),
                for (final result in results) ...[
                  _resultTile(result),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _doneBar(context),
    );
  }

  Widget _headlineCard() {
    final allPassed = _fails == 0 && _skips == 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Icon(
            allPassed ? Icons.verified : Icons.rule,
            size: 46,
            color: allPassed ? AppColors.success : AppColors.textSecondary,
          ),
          const SizedBox(height: 8),
          Text(
            allPassed ? 'All tests passed' : '${results.length} tests reviewed',
            style: AppTextStyles.body.copyWith(
                fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _countChip(CheckupStatus.pass, _passes),
              _countChip(CheckupStatus.fail, _fails),
              _countChip(CheckupStatus.skipped, _skips),
              if (_notAvailable > 0) _countChip(CheckupStatus.notAvailable, _notAvailable),
            ],
          ),
        ],
      ),
    );
  }

  Widget _countChip(CheckupStatus status, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, color: status.color, size: 16),
          const SizedBox(width: 4),
          Text(
            '$count ${status.label.toLowerCase()}',
            style: AppTextStyles.body.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: status.color),
          ),
        ],
      ),
    );
  }

  Widget _resultTile(CheckupResult result) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Icon(result.status.icon, color: result.status.color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.title,
                  style: AppTextStyles.body.copyWith(
                      fontSize: 14.5, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                if ((result.detail ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    result.detail!,
                    style: AppTextStyles.body.copyWith(
                        fontSize: 12.5, height: 1.35,
                        color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          Text(
            result.status.label,
            style: AppTextStyles.body.copyWith(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: result.status.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _doneBar(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      child: SizedBox(
        height: 52,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            textStyle: AppTextStyles.body.copyWith(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          child: const Text('Done'),
        ),
      ),
    );
  }
}