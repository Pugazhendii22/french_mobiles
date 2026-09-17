import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../models/checkup_result.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/theme/app_theme.dart';
import 'checkup_test_shell.dart';

/// Test 9 — Gyroscope.
///
/// Streams gyroscope readings while the user physically rotates the phone.
/// Passes as soon as rotation is detected. Auto-advances verdict.
class GyroscopeTestPage extends StatefulWidget {
  const GyroscopeTestPage({super.key});

  @override
  State<GyroscopeTestPage> createState() => _GyroscopeTestPageState();
}

class _GyroscopeTestPageState extends State<GyroscopeTestPage> {
  static const _threshold = 0.5;

  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  double _x = 0;
  double _y = 0;
  double _z = 0;
  bool _noData = true;
  CheckupResult? _result;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void dispose() {
    _gyroSubscription?.cancel();
    super.dispose();
  }

  Future<void> _listen() async {
    try {
      _gyroSubscription = gyroscopeEventStream(
        samplingPeriod: SensorInterval.uiInterval,
      ).listen(
        _onReading,
        onError: (Object e) {
          if (!mounted || _result != null) return;
          _markFailed('Gyroscope stream failed: $e');
        },
      );
    } catch (e) {
      if (!mounted) return;
      _markFailed('Could not open the gyroscope: $e');
    }
  }

  void _onReading(GyroscopeEvent event) {
    if (!mounted || _result != null) return;

    _x = event.x;
    _y = event.y;
    _z = event.z;

    var activeAxes = 0;
    if (_x.abs() > _threshold) activeAxes++;
    if (_y.abs() > _threshold) activeAxes++;
    if (_z.abs() > _threshold) activeAxes++;

    if (activeAxes >= 2) {
      // Stop the stream right away so the sensor doesn't keep firing rebuilds
      // after the test has already concluded.
      _gyroSubscription?.cancel();
      _gyroSubscription = null;
      _markPass(
        'Rotation detected on $activeAxes axes '
        '(x: ${_x.toStringAsFixed(1)}, y: ${_y.toStringAsFixed(1)}, z: ${_z.toStringAsFixed(1)} rad/s)',
      );
      return;
    }

    // Raw readings stream in dozens of times per second; only rebuild when a
    // piece of visible state actually transitions (first sample received).
    if (_noData) {
      setState(() => _noData = false);
    }
  }

  void _setResult(CheckupResult result) {
    _gyroSubscription?.cancel();
    if (!mounted) return;
    setState(() => _result = result);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.of(context).pop(_result);
      }
    });
  }

  void _markPass(String detail) {
    _setResult(CheckupResult(
      key: 'gyroscope',
      title: 'Gyroscope',
      status: CheckupStatus.pass,
      detail: detail,
    ));
  }

  void _markFailed(String detail) {
    _setResult(CheckupResult(
      key: 'gyroscope',
      title: 'Gyroscope',
      status: CheckupStatus.fail,
      detail: detail,
    ));
  }

  void _markIssue() {
    _setResult(const CheckupResult(
      key: 'gyroscope',
      title: 'Gyroscope',
      status: CheckupStatus.fail,
      detail: 'No rotation was detected while the phone was rotated',
    ));
  }

  void _skipTest() {
    _gyroSubscription?.cancel();
    Navigator.of(context).pop(
      const CheckupResult(
        key: 'gyroscope',
        title: 'Gyroscope',
        status: CheckupStatus.skipped,
        detail: 'Skipped by user',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CheckupTestShell(
      title: 'Gyroscope',
      child: _result != null ? _verdictView() : _testView(),
    );
  }

  Widget _testView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const CheckupInstruction(
          icon: Icons.threed_rotation,
          text:
            'Rotate the phone — flip or turn it while watching the axis '
            'indicators. The test records rotation in three dimensions.',
        ),
        const SizedBox(height: 16),
        _axisTile('X axis', 'pitch', _x),
        const SizedBox(height: 12),
        _axisTile('Y axis', 'yaw', _y),
        const SizedBox(height: 12),
        _axisTile('Z axis', 'roll', _z),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _noData ? AppColors.warningSoft : Colors.white,
            borderRadius: AppRadius.card,
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              Icon(
                _noData
                    ? Icons.error_outline
                    : Icons.sensors_off_outlined,
                color: _noData
                    ? AppColors.warning
                    : AppColors.textTertiary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _noData
                      ? 'No rotation detected yet — keep rotating the phone.'
                      : 'Hold still to see readings settle near zero.',
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CheckupActions(onIssue: _markIssue, onSkip: _skipTest),
      ],
    );
  }

  Widget _axisTile(String label, String plane, double value) {
    final active = value.abs() > _threshold;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.bodyMedium),
                const SizedBox(height: 2),
                Text(plane, style: AppTextStyles.caption),
              ],
            ),
          ),
          Text(
            '${(value / (3.141592653589793 / 180)).toStringAsFixed(0)}°/s',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : AppColors.border,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              active ? 'Rotating' : 'Still',
              style: AppTextStyles.overline.copyWith(
                color: active ? AppColors.onPrimarySoft : AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _verdictView() => CheckupVerdict(result: _result!);
}