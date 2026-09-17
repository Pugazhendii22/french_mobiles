import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/checkup_result.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/theme/app_theme.dart';
import 'checkup_test_shell.dart';

enum _ButtonStep { volumeDown, volumeUp, power }

/// Test 3 — Side buttons.
///
/// Three independent sub-steps: Volume Down, Volume Up (auto-detected via the
/// native key-event channel), then a manual Power self-report (Android reserves
/// the power key, so presses can't be observed by the app). Each sub-step records
/// its own pass / fail / skip and always advances to the next one. The combined
/// result is only popped once all three sub-steps have a result; the overall
/// status is fail if any sub-step failed.
class ButtonsTestPage extends StatefulWidget {
  const ButtonsTestPage({super.key});

  @override
  State<ButtonsTestPage> createState() => _ButtonsTestPageState();
}

class _ButtonsTestPageState extends State<ButtonsTestPage> {
  static const _channel = MethodChannel('french_mobiles/volume_keys');

  CheckupStatus? _volumeDownResult;
  CheckupStatus? _volumeUpResult;
  CheckupStatus? _powerResult;
  bool _volumeUpPressed = false;
  bool _volumeDownPressed = false;

  _ButtonStep get _step {
    if (_volumeDownResult == null) return _ButtonStep.volumeDown;
    if (_volumeUpResult == null) return _ButtonStep.volumeUp;
    return _ButtonStep.power;
  }

  @override
  void initState() {
    super.initState();
    _listenForVolumeKeys();
  }

  @override
  void dispose() {
    _channel.invokeMethod('setVolumeListening', {'enabled': false});
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  Future<void> _listenForVolumeKeys() async {
    _channel.setMethodCallHandler(_onMethodCall);
    try {
      await _channel.invokeMethod('setVolumeListening', {'enabled': true});
    } catch (_) {
      if (!mounted) return;
      // The volume keys can't be auto-detected; skip both volume sub-steps and
      // let the power sub-step still run.
      setState(() {
        _volumeDownResult = CheckupStatus.skipped;
        _volumeUpResult = CheckupStatus.skipped;
      });
    }
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    if (call.method != 'volumeKey' || !mounted) {
      return;
    }
    final args = call.arguments;
    final key = args is Map ? args['key'] as String? : null;
    if (key == null) return;

    switch (_step) {
      case _ButtonStep.volumeDown:
        if (key == 'volume_down') {
          setState(() => _volumeDownPressed = true);
          await Future<void>.delayed(const Duration(milliseconds: 400));
          if (!mounted || _volumeDownResult != null) return;
          _recordStep(CheckupStatus.pass);
        }
        break;
      case _ButtonStep.volumeUp:
        if (key == 'volume_up') {
          setState(() => _volumeUpPressed = true);
          await Future<void>.delayed(const Duration(milliseconds: 400));
          if (!mounted || _volumeUpResult != null) return;
          _recordStep(CheckupStatus.pass);
        }
        break;
      case _ButtonStep.power:
        break;
    }
  }

  void _recordStep(CheckupStatus status) {
    if (_powerResult != null) return;
    if (_volumeDownResult == null) {
      setState(() => _volumeDownResult = status);
    } else if (_volumeUpResult == null) {
      setState(() => _volumeUpResult = status);
    } else {
      setState(() => _powerResult = status);
    }

    if (_volumeDownResult != null &&
        _volumeUpResult != null &&
        _powerResult != null) {
      _finish();
    }
  }

  CheckupStatus get _overallStatus {
    if (_volumeDownResult == CheckupStatus.fail ||
        _volumeUpResult == CheckupStatus.fail ||
        _powerResult == CheckupStatus.fail) {
      return CheckupStatus.fail;
    }
    if (_volumeDownResult != CheckupStatus.pass ||
        _volumeUpResult != CheckupStatus.pass ||
        _powerResult != CheckupStatus.pass) {
      return CheckupStatus.skipped;
    }
    return CheckupStatus.pass;
  }

  String get _combinedDetail {
    String label(CheckupStatus status) => switch (status) {
          CheckupStatus.pass => 'pass',
          CheckupStatus.fail => 'fail',
          _ => 'skipped',
        };
    return 'Volume down: ${label(_volumeDownResult!)}, '
        'Volume up: ${label(_volumeUpResult!)}, '
        'Power: ${label(_powerResult!)}';
  }

  void _finish() {
    if (!mounted) return;
    Navigator.of(context).pop(CheckupResult(
      key: 'buttons',
      title: 'Side buttons',
      status: _overallStatus,
      detail: _combinedDetail,
    ));
  }

  void _skipStep() {
    if (_powerResult != null) return;
    _recordStep(CheckupStatus.skipped);
  }

  String get _stepLabel => switch (_step) {
        _ButtonStep.volumeDown => 'Step 1 of 3 · Volume Down',
        _ButtonStep.volumeUp => 'Step 2 of 3 · Volume Up',
        _ButtonStep.power => 'Step 3 of 3 · Power button',
      };

  @override
  Widget build(BuildContext context) {
    return CheckupTestShell(
      title: 'Side buttons',
      child: _testView(),
    );
  }

  Widget _testView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _stepProgress(),
        const SizedBox(height: 16),
        CheckupInstruction(
          icon: _step == _ButtonStep.power
              ? Icons.power_settings_new_rounded
              : Icons.volume_up_outlined,
          text: _step == _ButtonStep.power
              ? 'Press the power button once — does the screen turn off / '
                  'show the lock screen normally?'
              : 'Press the physical Volume Down and Volume Up keys on the '
                  'side of the phone.',
        ),
        const SizedBox(height: 16),
        // The power step reports itself through its own Yes / No pair, so it
        // gets only a skip; the volume steps watch for a real key event and
        // need a way to say the key never arrived.
        if (_step == _ButtonStep.power) ...[
          _powerControls(),
          const SizedBox(height: AppSpacing.lg),
          CheckupSkipButton(onSkip: _skipStep, label: 'Skip this step'),
        ] else ...[
          _keyTile('Volume Down', Icons.remove_circle_outline, _volumeDownPressed),
          const SizedBox(height: 12),
          _keyTile('Volume Up', Icons.add_circle_outline, _volumeUpPressed),
          const SizedBox(height: AppSpacing.lg),
          CheckupActions(
            onIssue: () => _recordStep(CheckupStatus.fail),
            onSkip: _skipStep,
            skipLabel: 'Skip this step',
          ),
        ],
      ],
    );
  }

  Widget _stepProgress() {
    return Row(
      children: [
        _stepDot(0, _step == _ButtonStep.volumeDown),
        const SizedBox(width: 8),
        _stepDot(1, _step == _ButtonStep.volumeUp),
        const SizedBox(width: 8),
        _stepDot(2, _step == _ButtonStep.power),
        const SizedBox(width: 12),
        // Expanded, because the longest step label overflows the row on a
        // narrow screen and an overflow clips the label rather than wrapping.
        Expanded(
          child: Text(
            _stepLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _stepDot(int index, bool active) {
    final visited = index <= _step.index;
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: active
            ? AppColors.primary
            : visited
                ? AppColors.primary.withValues(alpha: 0.35)
                : AppColors.borderStrong,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _keyTile(String label, IconData icon, bool detected) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Icon(icon,
              color: detected
                  ? AppColors.primary
                  : AppColors.textTertiary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.body.copyWith(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
          ),
          Icon(
            detected ? Icons.check_circle : Icons.radio_button_unchecked,
            color: detected
                ? AppColors.success
                : AppColors.borderStrong,
            size: 22,
          ),
        ],
      ),
    );
  }

  Widget _powerControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _powerButton(
          'Yes',
          Icons.check_circle_outline,
          AppColors.primary,
          () => _recordStep(CheckupStatus.pass),
        ),
        const SizedBox(height: 12),
        _powerButton(
          'No',
          Icons.cancel_outlined,
          AppColors.error,
          () => _recordStep(CheckupStatus.fail),
        ),
      ],
    );
  }

  Widget _powerButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(label, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}