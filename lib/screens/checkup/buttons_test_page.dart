import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/checkup_result.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const AppGradientHeader(title: 'Checkup · Side buttons'),
          Expanded(child: _testView()),
        ],
      ),
    );
  }

  Widget _testView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _stepProgress(),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: AppShadows.card,
          ),
          child: Text(
            _step == _ButtonStep.power
                ? 'Press the power button once — does the screen turn off / show the lock screen normally?'
                : 'Press the physical Volume Down and Volume Up keys on the side of the phone.',
            style: const TextStyle(
                fontSize: 13.5, height: 1.45, color: Color(0xFF475569)),
          ),
        ),
        const SizedBox(height: 16),
        if (_step == _ButtonStep.power)
          _powerControls()
        else ...[
          _keyTile('Volume Down', Icons.remove_circle_outline, _volumeDownPressed),
          const SizedBox(height: 12),
          _keyTile('Volume Up', Icons.add_circle_outline, _volumeUpPressed),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => _recordStep(CheckupStatus.fail),
                  child: const Text('Issue found',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF32CD32),
                    foregroundColor: Colors.black,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: null,
                  child: Text(
                    _step == _ButtonStep.volumeDown
                        ? 'Press Volume Down…'
                        : 'Press Volume Up…',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _skipStep,
            child: const Text('Skip this step',
                style: TextStyle(color: Color(0xFF94A3B8))),
          ),
        ),
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
        Text(
          _stepLabel,
          style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569)),
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
            ? const Color(0xFF32CD32)
            : visited
                ? const Color(0xFF32CD32).withValues(alpha: 0.35)
                : const Color(0xFFCBD5E1),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _keyTile(String label, IconData icon, bool detected) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Icon(icon,
              color: detected
                  ? const Color(0xFF32CD32)
                  : const Color(0xFF94A3B8)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A)),
            ),
          ),
          Icon(
            detected ? Icons.check_circle : Icons.radio_button_unchecked,
            color: detected
                ? const Color(0xFF16A34A)
                : const Color(0xFFCBD5E1),
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
          const Color(0xFF32CD32),
          () => _recordStep(CheckupStatus.pass),
        ),
        const SizedBox(height: 12),
        _powerButton(
          'No',
          Icons.cancel_outlined,
          const Color(0xFFDC2626),
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
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}