import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:proximity_sensor/proximity_sensor.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/theme/app_theme.dart';
import 'checkup_test_shell.dart';

/// Proximity sensor.
///
/// Genuinely sensor-verified: the pass requires observing a real near → far
/// transition from the sensor callback, not a timer. Covering the sensor alone
/// is not enough — a stuck-near sensor would pass that — so the test waits for
/// the value to come back as well.
///
/// While the test runs it also takes a PROXIMITY_SCREEN_OFF_WAKE_LOCK, so the
/// screen blanks on approach and lights again on withdrawal exactly as it does
/// during a call. That is the sensor's actual job on a phone, and a seller who
/// has just been told their proximity sensor works will judge it by whether
/// the screen goes dark on a call — so the test should show that, not merely
/// report a reading. The OS drives the screen straight from the sensor; Dart
/// only asks for the lock and gives it back.
class ProximityTestPage extends StatefulWidget {
  const ProximityTestPage({super.key});

  @override
  State<ProximityTestPage> createState() => _ProximityTestPageState();
}

class _ProximityTestPageState extends State<ProximityTestPage>
    with CheckupTestFlow<ProximityTestPage> {
  static const Duration _timeout = Duration(seconds: 20);

  /// Android only. Elsewhere the sensor readings still drive the test, but
  /// the screen stays lit.
  static const _screenChannel =
      MethodChannel('french_mobiles/proximity_screen');

  @override
  String get testKey => 'proximity';
  @override
  String get testTitle => 'Proximity sensor';

  StreamSubscription<int>? _subscription;
  Timer? _timeoutTimer;

  bool _sawNear = false;
  bool _isNear = false;
  bool _timedOut = false;
  bool _screenBlanking = false;
  int _attempt = 1;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    disposeHardware();
    super.dispose();
  }

  @override
  void disposeHardware() {
    _subscription?.cancel();
    _subscription = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _releaseScreenLock();
  }

  /// Hands the screen back. Safe to call when no lock was ever taken.
  void _releaseScreenLock() {
    if (!_screenBlanking) return;
    _screenBlanking = false;
    _screenChannel.invokeMethod<bool>('disable').catchError((_) => null);
  }

  /// Asks the OS to blank the screen while the sensor reads near.
  ///
  /// Failure is not worth reporting: without it the test still works, the
  /// screen simply stays on.
  Future<void> _takeScreenLock() async {
    try {
      final engaged = await _screenChannel.invokeMethod<bool>('enable');
      if (!mounted) {
        // Released immediately rather than left held by a dead page.
        _screenChannel.invokeMethod<bool>('disable').catchError((_) => null);
        return;
      }
      setState(() => _screenBlanking = engaged ?? false);
    } catch (_) {
      if (mounted) setState(() => _screenBlanking = false);
    }
  }

  void _start() {
    disposeHardware();
    setState(() {
      _sawNear = false;
      _isNear = false;
      _timedOut = false;
    });

    _takeScreenLock();

    try {
      _subscription = ProximitySensor.events.listen(
        _onReading,
        onError: (Object e) {
          if (!mounted || result != null) return;
          markNotAvailable('Proximity sensor unavailable: $e');
        },
      );
    } catch (e) {
      markNotAvailable('Could not open the proximity sensor: $e');
      return;
    }

    _timeoutTimer = Timer(_timeout, () {
      if (!mounted || result != null) return;
      setState(() => _timedOut = true);
    });
  }

  /// The plugin reports a positive value when something is near the sensor.
  void _onReading(int value) {
    if (!mounted || result != null) return;

    final near = value > 0;
    if (near == _isNear) return;

    setState(() {
      _isNear = near;
      if (near) _sawNear = true;
    });

    // near -> far is the full cycle: the sensor both detected an object and
    // recovered when it was removed.
    if (!near && _sawNear) {
      markPass(_screenBlanking
          ? 'Detected the phone approaching and moving away, and the screen '
              'blanked as it does on a call'
          : 'Detected the phone approaching and moving away');
    }
  }

  void _retry() {
    setState(() => _attempt++);
    _start();
  }

  @override
  Widget build(BuildContext context) {
    return CheckupTestShell(
      title: 'Proximity',
      child: result != null
          ? CheckupVerdict(result: result!)
          : _testView(),
    );
  }

  Widget _testView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CheckupInstruction(
          icon: Icons.phonelink_ring_outlined,
          text: _screenBlanking
              ? 'Hold the phone to your ear as if taking a call, then move it '
                  'away again. The screen will go dark while it is covered, '
                  'just as it does on a call, and come back when you move it '
                  'away.'
              : 'Hold the phone to your ear as if taking a call, then move it '
                  'away again. The sensor sits near the earpiece at the top '
                  'of the screen.',
        ),
        const SizedBox(height: 16),
        _stateTile(),
        const SizedBox(height: 16),
        if (_timedOut)
          const CheckupInstruction(
            icon: Icons.timer_off_outlined,
            tone: AppColors.warning,
            text: 'No proximity change detected yet. Make sure nothing is '
                'covering the top of the screen, then try again.',
          ),
        if (_timedOut) const SizedBox(height: 16),
        CheckupActions(
          attempt: _attempt,
          onRetry: _sawNear || _timedOut ? _retry : null,
          onIssue: () => markFail(
            'No near/far transition detected by the proximity sensor',
          ),
          onSkip: skipTest,
        ),
      ],
    );
  }

  Widget _stateTile() {
    final label = _isNear
        ? 'NEAR — now move the phone away'
        : _sawNear
            ? 'Detected near. Move the phone away to finish.'
            : 'FAR — bring the phone to your ear';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isNear ? AppColors.primarySoft : AppColors.surface,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Icon(
            _isNear ? Icons.volume_mute_rounded : Icons.hearing_rounded,
            size: 44,
            color: _isNear ? AppColors.onPrimarySoft : AppColors.textTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: _isNear ? AppColors.onPrimarySoft : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _step('Near', _sawNear),
              const SizedBox(width: 24),
              _step('Far again', _sawNear && !_isNear),
            ],
          ),
        ],
      ),
    );
  }

  Widget _step(String label, bool done) {
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
}
