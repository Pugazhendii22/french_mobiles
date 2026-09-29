import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../models/checkup_result.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_text_styles.dart';
import 'checkup_demo.dart';
import 'checkup_test_shell.dart';

/// Test 9 — Gyroscope.
///
/// A spirit level: tilt the phone flat and the ball settles into the ring.
///
/// This went through two worse designs. The first passed on any rotation at
/// all, which picking the phone up off a table produces. The second moved the
/// ball by *integrating* the gyroscope's rotation rate — technically the purest
/// way to prove that sensor works, and horrible to use: nobody's instinct for
/// "get the ball in the hole" is "rotate at a rate to accelerate it", and an
/// integrated value drifts, so the ball crept and fought the hand holding it.
///
/// So the ball follows **tilt**, which is the interaction everybody already
/// knows from every marble maze ever made, and the gyroscope is checked
/// alongside it rather than through it: a phone cannot be tilted without
/// rotating, so a gyroscope that stayed silent while the ball was being moved
/// is broken. See [_gyroSilentWhileMoving], which is what stops a dead
/// gyroscope being passed by a game it took no part in.

/// How close to the middle counts as in the ring, 0 to 1.
const double kGyroRingRadius = 0.2;

/// Tilt, in m/s² across an axis, that puts the ball at the rim.
///
/// About 40° — a natural reading angle — so simply holding the phone the way
/// people hold phones leaves the ball well outside the ring, and levelling it
/// is a deliberate act rather than something that happens by accident.
const double _tiltRange = 6.3;

class GyroscopeTestPage extends StatefulWidget {
  const GyroscopeTestPage({super.key});

  @override
  State<GyroscopeTestPage> createState() => _GyroscopeTestPageState();
}

class _GyroscopeTestPageState extends State<GyroscopeTestPage> {
  /// How long the ball has to stay in the ring.
  static const _holdFor = Duration(milliseconds: 900);

  /// How much of each new reading to take, 0 to 1.
  ///
  /// Accelerometers are noisy and an unsmoothed ball jitters too much to aim.
  /// Low enough to be steady, high enough not to lag behind the hand.
  static const _smoothing = 0.18;

  /// Rotation, rad/s, above which the gyroscope counts as reporting.
  static const _gyroFloor = 0.12;

  StreamSubscription<AccelerometerEvent>? _tilt;
  StreamSubscription<GyroscopeEvent>? _gyro;
  Timer? _clock;
  Timer? _silence;

  /// Ball position, -1 to 1 on each axis, 0 being the middle of the ring.
  double _x = 0;
  double _y = 0;
  double? _lastX;
  double? _lastY;

  Duration _inside = Duration.zero;

  bool _sawTilt = false;
  bool _sensorMissing = false;

  /// Whether the ball has been seen outside the ring.
  ///
  /// The guard that stops this test passing itself, twice over now. The ball
  /// begins at (0,0) because that is what a position starts as before any
  /// reading arrives — and (0,0) is the middle of the target. So a phone lying
  /// flat on a counter, or one with no sensors at all, sat in the ring from the
  /// first frame and passed 900ms later untouched.
  ///
  /// Requiring the ball to have been out first costs a real seller nothing:
  /// they are holding the phone at a reading angle, so it starts outside
  /// anyway. It costs a phone on a table the pass it had not earned.
  bool _hasBeenOutside = false;

  /// Readings taken while the phone was demonstrably being moved, and how many
  /// of those the gyroscope also noticed.
  int _movingSamples = 0;
  int _gyroActiveSamples = 0;

  CheckupResult? _result;

  @override
  void initState() {
    super.initState();
    _listen();

    // Neither stream errors on a handset that simply lacks the sensor — they
    // stay quiet — so silence needs a deadline of its own.
    _silence = Timer(const Duration(seconds: 4), () {
      if (!mounted || _sawTilt || _result != null) return;
      setState(() => _sensorMissing = true);
    });
  }

  @override
  void dispose() {
    _silence?.cancel();
    _clock?.cancel();
    _tilt?.cancel();
    _gyro?.cancel();
    super.dispose();
  }

  void _listen() {
    try {
      _tilt = accelerometerEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen(_onTilt, onError: (Object e) {
        _finish(CheckupStatus.fail, 'The motion sensor reported an error: $e');
      });

      _gyro = gyroscopeEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen((event) {
        if (math.max(event.x.abs(), event.y.abs()) > _gyroFloor) {
          _gyroActiveSamples++;
        }
      }, onError: (Object _) {
        // Deliberately not surfaced here. A gyroscope that errors and one that
        // says nothing are the same outcome, and the verdict below explains it
        // in words a seller can act on.
      });

      // The hold runs on its own clock rather than being counted inside sensor
      // callbacks, whose rate varies by handset — otherwise a phone reporting
      // twice as often would need half as long.
      _clock = Timer.periodic(const Duration(milliseconds: 50), _onTick);
    } catch (e) {
      _finish(CheckupStatus.fail, 'Could not open the motion sensors: $e');
    }
  }

  void _onTilt(AccelerometerEvent event) {
    if (!mounted || _result != null) return;
    _sawTilt = true;

    // Gravity across the screen's axes. Held flat both are near zero and the
    // ball rests in the middle; tilt either way and it rolls, exactly like a
    // marble on a tray.
    final targetX = (-event.x / _tiltRange).clamp(-1.0, 1.0);
    final targetY = (event.y / _tiltRange).clamp(-1.0, 1.0);

    final moved = math.max(
      (targetX - (_lastX ?? targetX)).abs(),
      (targetY - (_lastY ?? targetY)).abs(),
    );
    if (moved > 0.004) _movingSamples++;
    _lastX = targetX;
    _lastY = targetY;

    setState(() {
      _x += (targetX - _x) * _smoothing;
      _y += (targetY - _y) * _smoothing;
    });
  }

  void _onTick(Timer _) {
    if (!mounted || _result != null) return;

    final inside = math.sqrt(_x * _x + _y * _y) < kGyroRingRadius;

    if (!inside) {
      if (!_hasBeenOutside) _hasBeenOutside = true;
      if (_inside != Duration.zero) setState(() => _inside = Duration.zero);
      return;
    }

    // Nothing counts until the sensor has actually reported and the ball has
    // been steered in from outside.
    if (!_sawTilt || !_hasBeenOutside) return;

    setState(() => _inside += const Duration(milliseconds: 50));
    if (_inside >= _holdFor) _judge();
  }

  /// Whether the phone moved plenty while the gyroscope said nothing.
  ///
  /// The distinction the whole test rests on. Tilt comes from the
  /// accelerometer, so the ball reaching the ring proves only that *a* motion
  /// sensor works. A phone cannot be tilted without rotating, so a gyroscope
  /// silent throughout is broken.
  bool get _gyroSilentWhileMoving =>
      _movingSamples > 25 && _gyroActiveSamples < _movingSamples ~/ 8;

  void _judge() {
    if (_gyroSilentWhileMoving) {
      _finish(
        CheckupStatus.fail,
        'The ball could be steered, but the gyroscope reported no rotation '
        'while the phone was moving. The tilt sensor works; the gyroscope '
        'does not.',
      );
      return;
    }
    _finish(
      CheckupStatus.pass,
      'The ball was steered into the ring and held there, and the gyroscope '
      'reported rotation throughout.',
    );
  }

  void _finish(CheckupStatus status, String detail) {
    if (_result != null) return;
    _clock?.cancel();
    _silence?.cancel();
    _tilt?.cancel();
    _gyro?.cancel();

    final result = CheckupResult(
      key: 'gyroscope',
      title: 'Gyroscope',
      status: status,
      detail: detail,
    );
    if (!mounted) return;
    setState(() => _result = result);

    if (status == CheckupStatus.skipped) {
      Navigator.of(context).pop(result);
      return;
    }
    Timer(const Duration(milliseconds: 1600), () {
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
    final distance = math.sqrt(_x * _x + _y * _y);
    final inside = distance < kGyroRingRadius;
    final progress =
        (_inside.inMilliseconds / _holdFor.inMilliseconds).clamp(0.0, 1.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        children: [
          // The picture, not the sentence, is what reaches a seller who does
          // not read English. Every other test in the flow leads with one.
          const CheckupDemo(kind: CheckupDemoKind.rotatePhone, height: 96),
          const SizedBox(height: 8),
          Text(
            'Hold the phone flat',
            style: AppTextStyles.h3,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Tilt it until the ball rolls into the circle, then keep it still.',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Center(
            child: SizedBox(
              width: 280,
              height: 280,
              child: CustomPaint(
                painter: _LevelPainter(
                  x: _x,
                  y: _y,
                  progress: progress,
                  inside: inside,
                  dimmed: _sensorMissing,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // One short line that changes as they get closer, so the screen is
          // answering them rather than just sitting there.
          Text(
            _sensorMissing
                ? 'This phone is not reporting any movement.'
                : inside && !_hasBeenOutside
                    ? 'Tilt the phone, then bring the ball back'
                    : inside
                        ? 'Hold it there…'
                        : distance > 0.6
                            ? 'Keep going — level the phone out'
                            : 'Almost — a little flatter',
            style: AppTextStyles.bodyMedium.copyWith(
              color: inside ? AppColors.success : AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () =>
                      _finish(CheckupStatus.skipped, 'Skipped by user'),
                  child: const Text('Skip this test'),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () => _finish(
                    CheckupStatus.fail,
                    'The ball could not be steered into the ring',
                  ),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  child: const Text('Cannot do it'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _verdict() {
    final passed = _result!.status == CheckupStatus.pass;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
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
            Text(
              _result!.detail ?? '',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// The tray, the target, and the ball resting on it.
class _LevelPainter extends CustomPainter {
  const _LevelPainter({
    required this.x,
    required this.y,
    required this.progress,
    required this.inside,
    required this.dimmed,
  });

  final double x;
  final double y;
  final double progress;
  final bool inside;
  final bool dimmed;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final half = size.width / 2;
    final ring = half * kGyroRingRadius * 1.9;
    final ball = half * 0.11;
    final reach = half - ball - 3;

    canvas.drawCircle(
        centre, half - 2, Paint()..color = AppColors.surfaceMuted);
    canvas.drawCircle(
      centre,
      half - 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = AppColors.border,
    );

    // Crosshairs, so "level" reads as a place rather than a guess.
    final guide = Paint()
      ..strokeWidth = 1
      ..color = AppColors.border;
    canvas.drawLine(
      Offset(centre.dx - ring * 1.6, centre.dy),
      Offset(centre.dx + ring * 1.6, centre.dy),
      guide,
    );
    canvas.drawLine(
      Offset(centre.dx, centre.dy - ring * 1.6),
      Offset(centre.dx, centre.dy + ring * 1.6),
      guide,
    );

    final accent = dimmed
        ? AppColors.textTertiary
        : (inside ? AppColors.success : AppColors.primary);

    // The target fills in as it is held, which reads at a glance where a
    // number counting down does not.
    if (progress > 0) {
      canvas.drawCircle(
        centre,
        ring,
        Paint()
          ..color = AppColors.success.withValues(
            alpha: 0.12 + progress * 0.25,
          ),
      );
    }
    canvas.drawCircle(
      centre,
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = inside ? 4 : 2.5
        ..color = accent,
    );

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: ring + 10),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = AppColors.success,
      );
    }

    // A shadow, so the ball reads as resting on the tray rather than drawn on
    // top of it.
    final at = centre + Offset(x * reach, y * reach);
    canvas.drawCircle(
      at + const Offset(0, 2),
      ball,
      Paint()..color = Colors.black.withValues(alpha: 0.12),
    );
    canvas.drawCircle(
      at,
      ball,
      Paint()
        ..color = dimmed
            ? AppColors.textTertiary
            : (inside ? AppColors.success : AppColors.textPrimary),
    );
  }

  @override
  bool shouldRepaint(_LevelPainter old) =>
      old.x != x ||
      old.y != y ||
      old.progress != progress ||
      old.inside != inside ||
      old.dimmed != dimmed;
}
