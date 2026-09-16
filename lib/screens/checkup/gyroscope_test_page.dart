import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../models/checkup_result.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/widgets.dart';

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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(AppSpacing.screenGutter,
                AppSpacing.lg, AppSpacing.screenGutter, AppSpacing.lg),
            child: AppScreenHeader(title: 'Checkup · Gyroscope'),
          ),
          Expanded(
            child: _result != null ? _verdictView() : _testView(),
          ),
        ],
      ),
    );
  }

  Widget _testView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.card,
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              const Icon(Icons.threed_rotation, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Rotate the phone — flip or turn it while watching the axis indicators. The test records rotation in three dimensions.',
                  style: AppTextStyles.body.copyWith(
                      fontSize: 13.5, height: 1.45, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
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
                  style: AppTextStyles.body.copyWith(
                      fontSize: 13, height: 1.4, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _markIssue,
                child: Text('Issue found',
                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: null,
                child: Text('Waiting for rotation…',
                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _skipTest,
            child: Text('Skip this test',
                style: AppTextStyles.body.copyWith(color: AppColors.textTertiary)),
          ),
        ),
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
                Text(
                  label,
                  style: AppTextStyles.body.copyWith(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  plane,
                  style: AppTextStyles.body.copyWith(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            '${(value / (3.141592653589793 / 180)).toStringAsFixed(0)}°/s',
            style: AppTextStyles.body.copyWith(
                fontSize: 13, color: AppColors.textSecondary),
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
              style: AppTextStyles.body.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: active ? AppColors.onPrimarySoft : AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _verdictView() {
    final r = _result!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(r.status.icon, color: r.status.color, size: 64),
            const SizedBox(height: 14),
            Text(
              r.status.label,
              style: AppTextStyles.body.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: r.status.color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              r.detail ?? '',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}