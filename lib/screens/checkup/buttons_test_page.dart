import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/checkup_result.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/theme/app_theme.dart';
import 'checkup_demo.dart';
import 'checkup_test_shell.dart';

enum _ButtonStep { volumeDown, volumeUp, power }

/// Test 3 — Side buttons.
///
/// Three independent sub-steps: Volume Down, Volume Up and Power, each
/// auto-detected. Each records its own pass / fail / skip and always advances
/// to the next; the combined result pops once all three have one, failing if
/// any sub-step failed.
///
/// The power key cannot be observed directly — Android reserves KEYCODE_POWER
/// and never delivers it to an app — so the test watches its *effect*
/// instead: the screen turning off, and then coming back on. Seeing both is
/// the button working. The self-report is kept only as a fallback for when
/// nothing is detected, because some OEM builds suppress those broadcasts.
class ButtonsTestPage extends StatefulWidget {
  const ButtonsTestPage({super.key});

  @override
  State<ButtonsTestPage> createState() => _ButtonsTestPageState();
}

class _ButtonsTestPageState extends State<ButtonsTestPage> {
  static const _channel = MethodChannel('french_mobiles/volume_keys');
  static const _powerChannel = MethodChannel('french_mobiles/power_button');

  /// Long enough for someone to find the button and unlock, short enough that
  /// a device which never reports the screen going off is not a dead end.
  static const Duration _powerWindow = Duration(seconds: 45);

  CheckupStatus? _volumeDownResult;
  CheckupStatus? _volumeUpResult;
  CheckupStatus? _powerResult;
  bool _volumeUpPressed = false;
  bool _volumeDownPressed = false;

  bool _watchingScreen = false;
  bool _sawScreenOff = false;
  bool _powerTimedOut = false;
  Timer? _powerTimer;

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
    // catchError, because a device without the channel throws here and an
    // unawaited failure in dispose surfaces as an unhandled async error with
    // no owner.
    _channel.invokeMethod(
        'setVolumeListening', {'enabled': false}).catchError((_) => null);
    _channel.setMethodCallHandler(null);
    _stopWatchingScreen();
    _powerTimer?.cancel();
    super.dispose();
  }

  /// Starts watching once the power step is the one on screen.
  ///
  /// A broadcast receiver that outlives the step would report a screen-off
  /// from somewhere else entirely as a power-button press.
  Future<void> _syncScreenWatching() async {
    if (_step != _ButtonStep.power || _watchingScreen || _powerResult != null) {
      return;
    }
    _watchingScreen = true;
    _powerChannel.setMethodCallHandler(_onPowerCall);

    try {
      await _powerChannel.invokeMethod<bool>('startWatching');
    } catch (_) {
      // Not Android, or the receiver could not be registered. The self-report
      // below is the fallback.
      if (!mounted) return;
      setState(() => _powerTimedOut = true);
      return;
    }

    _powerTimer?.cancel();
    _powerTimer = Timer(_powerWindow, () {
      if (mounted && _powerResult == null) {
        setState(() => _powerTimedOut = true);
      }
    });
  }

  void _stopWatchingScreen() {
    if (!_watchingScreen) return;
    _watchingScreen = false;
    _powerChannel.invokeMethod('stopWatching').catchError((_) => null);
    _powerChannel.setMethodCallHandler(null);
  }

  Future<dynamic> _onPowerCall(MethodCall call) async {
    if (call.method != 'screenEvent' || !mounted) return;
    if (_step != _ButtonStep.power || _powerResult != null) return;

    final args = call.arguments;
    final event = args is Map ? args['event'] as String? : null;
    if (event == null) return;

    if (event == 'screen_off') {
      setState(() => _sawScreenOff = true);
      return;
    }

    // Coming back on only counts once the screen was seen to go off: the
    // button has to have done both halves of its job.
    if (_sawScreenOff && (event == 'screen_on' || event == 'user_present')) {
      _powerTimer?.cancel();
      _stopWatchingScreen();
      _recordStep(CheckupStatus.pass);
    }
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
      // Both volume steps skipped lands straight on power.
      _syncScreenWatching();
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
      _stopWatchingScreen();
      _finish();
      return;
    }

    _syncScreenWatching();
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
          demo: _step == _ButtonStep.power
              ? CheckupDemoKind.powerButton
              : CheckupDemoKind.volumeButtons,
          icon: _step == _ButtonStep.power
              ? Icons.power_settings_new_rounded
              : Icons.volume_up_outlined,
          text: _step == _ButtonStep.power
              ? (_sawScreenOff
                  ? 'Screen-off detected. Now press the power button again '
                      'and unlock to finish the test.'
                  : 'Press the power button to turn the screen off, then '
                      'press it again and unlock. We watch for the screen '
                      'going off and coming back.')
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
          _keyTile(
              'Volume Down', Icons.remove_circle_outline, _volumeDownPressed),
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
            style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
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
              color: detected ? AppColors.primary : AppColors.textTertiary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodyMedium,
            ),
          ),
          Icon(
            detected ? Icons.check_circle : Icons.radio_button_unchecked,
            color: detected ? AppColors.success : AppColors.borderStrong,
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
        _powerProgress(),
        if (_powerTimedOut) ...[
          const SizedBox(height: AppSpacing.lg),
          // Only offered once watching has failed to see anything. Some OEM
          // builds do not broadcast screen state to a paused app, and a
          // seller should not be stuck because of that — but asking first
          // would throw away a real check for a guess.
          const CheckupInstruction(
            icon: Icons.help_outline_rounded,
            tone: AppColors.warning,
            text: 'We could not detect the screen turning off on this phone. '
                'Did the power button work when you pressed it?',
          ),
          const SizedBox(height: AppSpacing.md),
          _powerButton(
            'Yes, it worked',
            Icons.check_circle_outline,
            AppColors.primary,
            () => _recordStep(CheckupStatus.pass),
          ),
          const SizedBox(height: 12),
          _powerButton(
            'No, it did not',
            Icons.cancel_outlined,
            AppColors.error,
            () => _recordStep(CheckupStatus.fail),
          ),
        ],
      ],
    );
  }

  /// What the test has seen so far: screen off, then screen back on.
  Widget _powerProgress() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: _sawScreenOff ? AppColors.primarySoft : AppColors.surface,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Icon(
            _sawScreenOff
                ? Icons.lock_open_rounded
                : Icons.power_settings_new_rounded,
            size: 44,
            color: _sawScreenOff
                ? AppColors.onPrimarySoft
                : AppColors.textTertiary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            _sawScreenOff
                ? 'Now wake it up'
                : 'Waiting for the screen to go off',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: _sawScreenOff
                  ? AppColors.onPrimarySoft
                  : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Wrap rather than Row: the two milestones together overflow a
          // padded card at 400px, and stack instead of clipping at 320.
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: [
              _powerMilestone('Screen off', _sawScreenOff),
              _powerMilestone('Screen back on', false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _powerMilestone(String label, bool done) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          done ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 16,
          color: done ? AppColors.success : AppColors.textTertiary,
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }

  Widget _powerButton(
      String label, IconData icon, Color color, VoidCallback onPressed) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.field),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(label,
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
