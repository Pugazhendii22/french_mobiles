import 'package:flutter/material.dart';

import '../shared/theme/app_colors.dart';
import '../shared/theme/app_text_styles.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/widgets.dart';

class SupportPage extends StatefulWidget {
  const SupportPage({super.key});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  static const List<Map<String, String>> _faqs = [
    {
      'q': 'How is the final trade-in price determined?',
      'a': 'Our price algorithm evaluates your phone model, screen condition, physical body wear, functional hardware checks, and device age.'
    },
    {
      'q': 'When do I get paid for selling my device?',
      'a': 'You receive payment instantly via UPI, IMPS bank transfer, or store gift card right after our field executive inspects your device at pickup.'
    },
    {
      'q': 'Do I need to carry original accessories & box?',
      'a': 'Original charger and box add extra trade-in value to your device, but they are not mandatory to complete the transaction.'
    },
    {
      'q': 'Is it safe to trade in my old phone?',
      'a': 'Yes, completely safe! We perform a factory data wipe verification at pickup to ensure your personal data is 100% secure.'
    },
  ];

  int? _expanded = 0;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenGutter,
              AppSpacing.lg,
              AppSpacing.screenGutter,
              AppSpacing.xxl,
            ),
            children: [
              const AppScreenHeader(title: 'Help & support'),
              const SizedBox(height: AppSpacing.xl),
              _buildContactCard(),
              const SizedBox(height: AppSpacing.xxl),
              Text('Frequently asked', style: AppTextStyles.h3),
              const SizedBox(height: AppSpacing.md),
              for (var i = 0; i < _faqs.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.sm),
                _FaqTile(
                  question: _faqs[i]['q']!,
                  answer: _faqs[i]['a']!,
                  expanded: _expanded == i,
                  onToggle: () =>
                      setState(() => _expanded = _expanded == i ? null : i),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: AppRadius.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.support_agent_rounded,
                  size: 20,
                  color: AppColors.onPrimarySoft,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Still need help?', style: AppTextStyles.h3),
                    const SizedBox(height: 2),
                    Text(
                      'Our team replies within a few hours.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.onPrimarySoft,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({
    required this.question,
    required this.answer,
    required this.expanded,
    required this.onToggle,
  });

  final String question;
  final String answer;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(
          color: expanded ? AppColors.primary : AppColors.border,
        ),
      ),
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: onToggle,
          borderRadius: AppRadius.card,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(question, style: AppTextStyles.bodyMedium),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox(width: double.infinity),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: Text(answer, style: AppTextStyles.bodySmall),
                  ),
                  crossFadeState: expanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 200),
                  sizeCurve: Curves.easeInOut,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
