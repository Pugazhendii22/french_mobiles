import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../models/checkup_result.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

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
          const AppGradientHeader(title: 'Checkup · Gyroscope'),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: AppShadows.card,
          ),
          child: const Row(
            children: [
              Icon(Icons.threed_rotation, color: Color(0xFF32CD32)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Rotate the phone — flip or turn it while watching the axis indicators. The test records rotation in three dimensions.',
                  style: TextStyle(
                      fontSize: 13.5, height: 1.45, color: Color(0xFF475569)),
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
            color: _noData ? const Color(0xFFFEF3C7) : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              Icon(
                _noData
                    ? Icons.error_outline
                    : Icons.sensors_off_outlined,
                color: _noData
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _noData
                      ? 'No rotation detected yet — keep rotating the phone.'
                      : 'Hold still to see readings settle near zero.',
                  style: const TextStyle(
                      fontSize: 13, height: 1.4, color: Color(0xFF475569)),
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
                  foregroundColor: const Color(0xFFDC2626),
                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _markIssue,
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
                child: const Text('Waiting for rotation…',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _skipTest,
            child: const Text('Skip this test',
                style: TextStyle(color: Color(0xFF94A3B8))),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
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
                  style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 2),
                Text(
                  plane,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Text(
            '${(value / (3.141592653589793 / 180)).toStringAsFixed(0)}°/s',
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF475569)),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: active
                  ? const Color(0xFF32CD32).withValues(alpha: 0.15)
                  : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              active ? 'Rotating' : 'Still',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: active ? const Color(0xFF15803D) : const Color(0xFF94A3B8),
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
              style: TextStyle(
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
              style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
            ),
          ],
        ),
      ),
    );
  }
}