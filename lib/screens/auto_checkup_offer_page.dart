import 'package:flutter/material.dart';

import '../models/checkup_result.dart';
import '../models/device_question.dart';
import '../shared/motion/motion.dart';
import '../shared/theme/app_colors.dart';
import '../shared/theme/app_text_styles.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/widgets.dart';
import 'checkup/checkup_entry_page.dart';
import 'device_evaluation_wizard.dart';

/// The automatic stage, between the questions and the physical checklist.
///
/// Running it is optional on purpose. It is eighteen tests including a
/// three-minute connection watch, and putting that between someone and their
/// price would lose more sellers than the data is worth — the quote is
/// provisional regardless, since an agent inspects the phone at pickup before
/// any money changes hands.
///
/// **The results never move the price.** The seller's own answers decide the
/// quote; a failed test is recorded and shown, and travels with the order so
/// the agent knows where to look, but it does not silently re-price the phone
/// underneath someone who already saw a number.
class AutoCheckupOfferPage extends StatefulWidget {
  const AutoCheckupOfferPage({
    super.key,
    required this.brandName,
    required this.modelDocId,
    required this.modelName,
    required this.storage,
    required this.basePrice,
    required this.answers,
    this.imageUrl,
  });

  final String brandName;
  final String modelDocId;
  final String modelName;
  final String storage;
  final int basePrice;
  final String? imageUrl;
  final List<DeviceAnswer> answers;

  @override
  State<AutoCheckupOfferPage> createState() => _AutoCheckupOfferPageState();
}

class _AutoCheckupOfferPageState extends State<AutoCheckupOfferPage> {
  /// Which question each hardware test speaks to.
  ///
  /// Several tests can bear on one question — the speaker, earpiece and
  /// microphone tests all say something about "do the speaker and microphone
  /// work". Matching on the fault label rather than a question index means a
  /// reworded question still lines up.
  static const Map<String, String> _testToFault = {
    'network': 'Network / SIM Issue',
    'internet': 'Network / SIM Issue',
    'internet_stability': 'Network / SIM Issue',
    'speaker': 'Speaker / Mic Issue',
    'earpiece': 'Speaker / Mic Issue',
    'microphone': 'Speaker / Mic Issue',
    'buttons': 'Buttons Not Working',
    'biometric': 'Fingerprint / Face ID',
    'camera': 'Camera (Front/Rear) Issue',
    'multitouch': 'Touch Screen Not Working',
    'display': 'Touch Screen Not Working',
  };

  List<CheckupResult>? _results;

  Future<void> _runCheckup() async {
    final results = await Navigator.of(context).push<List<CheckupResult>>(
      AppPageRoute<List<CheckupResult>>(
        builder: (_) => const CheckupEntryPage(collectResults: true),
        transition: AppTransition.rise,
      ),
    );
    if (!mounted || results == null) return;
    setState(() => _results = results);
  }

  void _continue() {
    context.pushScreen(DeviceEvaluationWizard(
      brandName: widget.brandName,
      modelDocId: widget.modelDocId,
      modelName: widget.modelName,
      imageUrl: widget.imageUrl,
      basePrice: widget.basePrice,
      storage: widget.storage,
      answers: widget.answers,
      checkupResults: _results ?? const [],
    ));
  }

  /// Tests that failed while the seller said that part of the phone is fine.
  ///
  /// Reported, never charged for. Their answer stands.
  List<({CheckupResult result, String fault})> get _disagreements {
    final results = _results;
    if (results == null) return const [];

    final saidFine = <String>{
      for (final answer in widget.answers)
        if (!answer.isFault) answer.question.label,
    };

    return [
      for (final result in results)
        if (result.status == CheckupStatus.fail &&
            _testToFault[result.key] != null &&
            saidFine.contains(_testToFault[result.key]))
          (result: result, fault: _testToFault[result.key]!),
    ];
  }

  int _count(CheckupStatus status) =>
      (_results ?? const []).where((r) => r.status == status).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(AppSpacing.screenGutter, AppSpacing.lg,
                AppSpacing.screenGutter, AppSpacing.lg),
            child: AppScreenHeader(title: 'Automatic check'),
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
                for (final (i, card)
                    in (_results == null ? _invitation() : _resultsView())
                        .indexed)
                  AppReveal(index: i, child: card),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _bottomBar(),
    );
  }

  List<Widget> _invitation() {
    return [
      AppSurface(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.fact_check_outlined,
                    color: AppColors.primary, size: 26),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text('Let the phone test itself',
                      style: AppTextStyles.h3),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'The phone checks its own speaker, microphone, buttons, '
              'fingerprint, cameras and network. It takes a few minutes, and '
              'what it finds is attached to your order so the pickup agent '
              'knows the phone has already been checked.',
              style:
                  AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      AppSurface(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                size: 18, color: AppColors.textTertiary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'This will not change your price. Your own answers decide the '
                'quote — the final amount is confirmed when the agent inspects '
                'the phone at pickup.',
                style: AppTextStyles.caption,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _resultsView() {
    final passes = _count(CheckupStatus.pass);
    final fails = _count(CheckupStatus.fail);
    final conflicts = _disagreements;

    return [
      AppSurface(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  fails > 0
                      ? Icons.error_outline_rounded
                      : Icons.verified_rounded,
                  color: fails > 0 ? AppColors.error : AppColors.success,
                  size: 26,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    fails > 0
                        ? '$fails issue${fails == 1 ? '' : 's'} found'
                        : 'Checkup complete',
                    style: AppTextStyles.h3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '$passes of ${_results!.length} tests passed. This is attached '
              'to your order for the pickup agent.',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
      if (conflicts.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.md),
        AppSurface(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.help_outline_rounded,
                      size: 20, color: AppColors.warning),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text('Worth a second look',
                        style: AppTextStyles.bodyMedium),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'You said these are working, but the test did not agree. Your '
                'answers still decide your quote — this is only so nothing is '
                'a surprise at pickup.',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: AppSpacing.md),
              for (final conflict in conflicts) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: Icon(Icons.cancel_rounded,
                          size: 15, color: AppColors.error),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${conflict.result.title} — ${conflict.fault}',
                              style: AppTextStyles.bodySmall),
                          if ((conflict.result.detail ?? '').isNotEmpty)
                            Text(conflict.result.detail!,
                                style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
        ),
      ],
    ];
  }

  Widget _bottomBar() {
    final done = _results != null;

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppPrimaryButton(
            label: done ? 'Continue' : 'Start checkup',
            onPressed: done ? _continue : _runCheckup,
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            onPressed: done ? _runCheckup : _continue,
            child: Text(
              done ? 'Run it again' : "Skip — I'll answer for it myself",
              style: AppTextStyles.body.copyWith(color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}
