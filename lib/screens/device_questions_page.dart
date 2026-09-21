import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../models/device_question.dart';
import '../shared/motion/motion.dart';
import '../shared/theme/app_colors.dart';
import '../shared/theme/app_text_styles.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/widgets.dart';
import 'auto_checkup_offer_page.dart';

/// The questions asked before anything is inspected.
///
/// The sell flow used to go straight from picking a variant into the physical
/// condition checklist, which opens by asking someone to grade their own
/// screen — a judgement call, made cold. These are the opposite: nine facts
/// the owner already knows without looking, answered yes or no, with the
/// quote moving as they go so the grading that follows arrives in context.
///
/// Everything here is a *functional* fault. The wizard after it deals only
/// with what has to be looked at — marks, dents, what is in the box — which
/// is the split between an automatic check and a physical one.
class DeviceQuestionsPage extends StatefulWidget {
  const DeviceQuestionsPage({
    super.key,
    required this.brandName,
    required this.modelDocId,
    required this.modelName,
    required this.storage,
    required this.basePrice,
    this.imageUrl,
  });

  final String brandName;
  final String modelDocId;
  final String modelName;
  final String storage;
  final int basePrice;
  final String? imageUrl;

  @override
  State<DeviceQuestionsPage> createState() => _DeviceQuestionsPageState();
}

class _DeviceQuestionsPageState extends State<DeviceQuestionsPage> {
  FirebaseFirestore get _catalogFirestore =>
      FirebaseFirestore.instanceFor(app: Firebase.app('catalogApp'));

  List<DeviceQuestion> _questions = [];
  final Map<int, bool> _answers = {};
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final doc = await _catalogFirestore
          .collection('deduction_rules')
          .doc('device_questions')
          .get();

      final raw = doc.data()?['options'];
      final questions = <DeviceQuestion>[];
      if (raw is List) {
        for (final entry in raw) {
          if (entry is Map) {
            final parsed =
                DeviceQuestion.fromMap(Map<String, dynamic>.from(entry));
            if (parsed != null) questions.add(parsed);
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _questions = questions;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = '$e';
      });
    }
  }

  bool get _allAnswered =>
      _questions.isNotEmpty && _answers.length == _questions.length;

  int get _remaining => _questions.length - _answers.length;

  List<DeviceAnswer> get _collected => [
        for (var i = 0; i < _questions.length; i++)
          if (_answers[i] != null)
            DeviceAnswer(question: _questions[i], answeredYes: _answers[i]!),
      ];

  /// What the answers so far have taken off, in rupees.
  int get _deducted {
    var fraction = 0.0;
    for (final answer in _collected) {
      if (answer.isFault) fraction += answer.question.fraction;
    }
    return (widget.basePrice * fraction).round();
  }

  /// Never below zero — the floor the real quote applies is decided later, and
  /// showing a negative running total here would be nonsense.
  int get _running => (widget.basePrice - _deducted).clamp(0, widget.basePrice);

  void _continue() {
    context.pushScreen(AutoCheckupOfferPage(
      brandName: widget.brandName,
      modelDocId: widget.modelDocId,
      modelName: widget.modelName,
      storage: widget.storage,
      basePrice: widget.basePrice,
      imageUrl: widget.imageUrl,
      answers: _collected,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(AppSpacing.screenGutter, AppSpacing.lg,
                AppSpacing.screenGutter, AppSpacing.lg),
            child: AppScreenHeader(title: 'Tell us about your device'),
          ),
          Expanded(child: _body()),
        ],
      ),
      bottomNavigationBar: _loading || _questions.isEmpty ? null : _bottomBar(),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_questions.isEmpty) {
      // No questions is not a dead end: the physical checklist still works,
      // so the flow carries on rather than trapping someone mid-sale.
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppEmptyState(
            icon: Icons.help_outline_rounded,
            title: 'No questions to answer',
            message: _loadError == null
                ? 'Continue to the condition checklist.'
                : 'These could not be loaded: $_loadError',
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter),
            child: AppPrimaryButton(label: 'Continue', onPressed: _continue),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        0,
        AppSpacing.screenGutter,
        AppSpacing.xxxl,
      ),
      children: [
        Text(
          'Please answer a few questions about your device.',
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (var i = 0; i < _questions.length; i++)
          AppReveal(
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _questionCard(i, _questions[i]),
            ),
          ),
      ],
    );
  }

  Widget _questionCard(int index, DeviceQuestion question) {
    final answer = _answers[index];

    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(question.question, style: AppTextStyles.bodyMedium),
          if (question.help.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(question.help, style: AppTextStyles.caption),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _choice(
                  label: 'Yes',
                  selected: answer == true,
                  costly: question.deductOnYes,
                  onTap: () => setState(() => _answers[index] = true),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _choice(
                  label: 'No',
                  selected: answer == false,
                  costly: !question.deductOnYes,
                  onTap: () => setState(() => _answers[index] = false),
                ),
              ),
            ],
          ),
          // Shown only once the costly answer is actually chosen. Printing the
          // penalty next to the button beforehand would tell someone which
          // answer to give rather than asking them what is true.
          if (answer != null && question.isFaultFor(answer)) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(Icons.remove_circle_outline_rounded,
                    size: 15, color: AppColors.error),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    '${question.label} · −₹${(widget.basePrice * question.fraction).round()}',
                    style:
                        AppTextStyles.caption.copyWith(color: AppColors.error),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _choice({
    required String label,
    required bool selected,
    required bool costly,
    required VoidCallback onTap,
  }) {
    // A selected answer that costs money is tinted red, one that does not is
    // tinted green — the colour is feedback about the phone, never a nudge:
    // an unselected button looks the same either way.
    final tone = costly ? AppColors.error : AppColors.success;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.field,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? tone.withValues(alpha: 0.10) : AppColors.surface,
          borderRadius: AppRadius.field,
          border: Border.all(
            color: selected ? tone : AppColors.borderStrong,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.button.copyWith(
            color: selected ? tone : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _bottomBar() {
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
          Row(
            children: [
              Expanded(
                child: Text(
                  _allAnswered
                      ? 'Estimated so far'
                      : '$_remaining question${_remaining == 1 ? '' : 's'} left',
                  style: AppTextStyles.caption,
                ),
              ),
              Text(
                '₹$_running',
                style: AppTextStyles.h3.copyWith(
                  color: _deducted > 0
                      ? AppColors.textPrimary
                      : AppColors.onPrimarySoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppPrimaryButton(
            label: 'Continue',
            onPressed: _allAnswered ? _continue : null,
          ),
        ],
      ),
    );
  }
}
