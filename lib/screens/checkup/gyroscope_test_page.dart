import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../models/checkup_result.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_text_styles.dart';
import 'checkup_test_shell.dart';

/// Test 9 — Gyroscope.
///
/// A ball the seller steers into a ring by turning the phone.
///
/// The previous version passed the moment it saw any rotation at all, which a
/// phone picked up off a table produces — so it confirmed almost nothing, and
/// a partly broken sensor sailed through. This cannot be passed by accident:
/// reaching the ring needs controlled movement on **both** axes, held steady,
/// which a sensor that is dead, stuck on one axis, or wildly noisy cannot
/// deliver.
///
/// The ball is driven by the gyroscope itself rather than by tilt. That
/// distinction matters: tilt comes from the accelerometer, so a tilt-driven
/// game would happily pass a handset whose gyroscope is broken. Here, no
/// gyroscope means no movement, and no movement means no pass.
class GyroscopeTestPage extends StatefulWidget {
  const GyroscopeTestPage({super.key});

  @override
  State<GyroscopeTestPage> createState() => _GyroscopeTestPageState();
}

class _GyroscopeTestPageState extends State<GyroscopeTestPage>
    with SingleTickerProviderStateMixin {
  /// How long the ball must stay inside the ring.
  ///
  /// Long enough that passing through by chance does not count, short enough
  /// not to be a test of patience while somebody stands in a shop.
  static const _holdFor = Duration(milliseconds: 1200);

  /// Radians of rotation to cross the play area, roughly a quarter turn.
  static const _travel = 1.6;

  /// Bleeds off integration drift.
  ///
  /// Integrating a rate always wanders, and a ball that creeps on its own is
  /// maddening to steer. This pulls it gently back so a still phone means a
  /// still ball, without fighting a seller who is actively moving it.
  static const _decay = 0.94;

  StreamSubscription<GyroscopeEvent>? _subscription;
  Ticker? _ticker;
  Duration _lastTick = Duration.zero;

  /// Current rotation rate, rad/s, straight from the sensor.
  double _rateX = 0;
  double _rateY = 0;

  /// Ball position, -1 to 1 on each axis, 0 being the centre.
  double _x = 0;
  double _y = 0;

  /// How long the ball has been inside the ring.
  Duration _inside = Duration.zero;

  bool _sawAnyReading = false;
  bool _sensorMissing = false;
  Timer? _silenceTimer;
  CheckupResult? _result;

  @override
  void initState() {
    super.initState();
    _listen();
    _ticker = Ticker(_onTick)..start();

    // A phone with no gyroscope produces no events and no error either — the
    // stream simply stays quiet. Without this the page would wait for ever
    // looking like it was working.
    _silenceTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || _sawAnyReading || _result != null) return;
      setState(() => _sensorMissing = true);
    });
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _ticker?.dispose();
    _subscription?.cancel();
    super.dispose();
  }

  void _listen() {
    try {
      _subscription = gyroscopeEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen(
        (event) {
          if (!mounted || _result != null) return;
          _sawAnyReading = true;
          // Turning the phone about its X axis moves the ball up and down;
          // about its Y axis, left and right. Signs chosen so the ball follows
          // the direction of the turn rather than opposing it.
          _rateX = event.y;
          _rateY = event.x;
        },
        onError: (Object e) {
          if (!mounted || _result != null) return;
          _finish(CheckupStatus.fail, 'The gyroscope reported an error: $e');
        },
        cancelOnError: true,
      );
    } catch (e) {
      _finish(CheckupStatus.fail, 'Could not open the gyroscope: $e');
    }
  }

  void _onTick(Duration elapsed) {
    if (_result != null) return;
    final dt = _lastTick == Duration.zero
        ? 1 / 60
        : (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    // A frame that arrives after the app was backgrounded carries a huge dt,
    // which would fling the ball off the board.
    if (dt <= 0 || dt > 0.1) return;

    setState(() {
      _x = ((_x + _rateY * dt / _travel) * _decay).clamp(-1.0, 1.0);
      _y = ((_y + _rateX * dt / _travel) * _decay).clamp(-1.0, 1.0);

      if (math.sqrt(_x * _x + _y * _y) < 0.18) {
        _inside += Duration(microseconds: (dt * 1e6).round());
        if (_inside >= _holdFor) {
          _finish(
            CheckupStatus.pass,
            'The ball was steered into the ring and held there, so rotation '
            'is being reported on both axes.',
          );
        }
      } else {
        _inside = Duration.zero;
      }
    });
  }

  void _finish(CheckupStatus status, String detail) {
    if (_result != null) return;
    _subscription?.cancel();
    _ticker?.stop();
    final result = CheckupResult(
      key: 'gyroscope',
      title: 'Gyroscope',
      status: status,
      detail: detail,
    );
    setState(() => _result = result);

    if (status == CheckupStatus.skipped) {
      Navigator.of(context).pop(result);
      return;
    }
    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) Navigator.of(context).pop(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    return CheckupTestShell(
      title: 'Gyroscope',
      child: _result != null ? _verdict() : _game(),
    );
  }

  Widget _game() {
    final progress =
        (_inside.inMilliseconds / _holdFor.inMilliseconds).clamp(0.0, 1.0);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            _sensorMissing
                ? 'This phone is not reporting any rotation.'
                : 'Turn the phone to roll the ball into the ring, and hold it '
                    'there.',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Square, so a turn of the phone moves the ball the same
                // distance whichever way it goes.
                final side = math.min(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                return Center(
                  child: SizedBox(
                    width: side,
                    height: side,
                    child: CustomPaint(
                      painter: _BoardPainter(
                        x: _x,
                        y: _y,
                        progress: progress,
                        dimmed: _sensorMissing,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            children: [
              if (_sensorMissing)
                Text(
                  'Nothing has come from the gyroscope for a few seconds. On '
                  'most phones that means it is missing or faulty.',
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => _finish(
                        CheckupStatus.skipped,
                        'Skipped by user',
                      ),
                      child: const Text('Skip this test'),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () => _finish(
                        CheckupStatus.fail,
                        'The ball could not be steered into the ring',
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                      child: const Text('Cannot do it'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _verdict() {
    final passed = _result!.status == CheckupStatus.pass;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            passed ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 64,
            color: passed ? AppColors.success : AppColors.error,
          ),
          const SizedBox(height: 16),
          Text(
            passed ? 'PASS' : 'FAIL',
            style: AppTextStyles.h2.copyWith(
              color: passed ? AppColors.success : AppColors.error,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _result!.detail ?? '',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// The play area: a target ring, and the ball being steered into it.
class _BoardPainter extends CustomPainter {
  const _BoardPainter({
    required this.x,
    required this.y,
    required this.progress,
    required this.dimmed,
  });

  /// Ball position, -1 to 1 on each axis.
  final double x;
  final double y;

  /// How much of the hold has been completed, 0 to 1.
  final double progress;

  /// True when no sensor readings are arriving.
  final bool dimmed;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final half = size.width / 2;
    final ringRadius = half * 0.22;
    final ballRadius = half * 0.09;
    // Kept inside the board however far the ball is pushed.
    final reach = half - ballRadius - 2;

    canvas.drawCircle(
      centre,
      half - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = AppColors.border,
    );

    final inside = math.sqrt(x * x + y * y) < 0.18;
    final ringColour = dimmed
        ? AppColors.textTertiary
        : inside
            ? AppColors.success
            : AppColors.primary;

    canvas.drawCircle(
      centre,
      ringRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = ringColour,
    );

    // The hold, drawn as an arc closing around the ring — the seller can see
    // how much longer to keep still rather than guessing.
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: ringRadius + 8),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = AppColors.success,
      );
    }

    final ball = centre + Offset(x * reach, y * reach);
    canvas.drawCircle(
      ball,
      ballRadius,
      Paint()
        ..color = dimmed ? AppColors.textTertiary : AppColors.textPrimary,
    );
  }

  @override
  bool shouldRepaint(_BoardPainter old) =>
      old.x != x ||
      old.y != y ||
      old.progress != progress ||
      old.dimmed != dimmed;
}
