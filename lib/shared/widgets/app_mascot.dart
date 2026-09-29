import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import 'mascot_remarks.dart';

/// What the mascot is doing right now.
enum MascotState { idle, walking, falling, dragged }

/// The little helper that lives on top of the app.
///
/// A phone with a face. It walks along the top of the navigation bar, watches
/// wherever you touch, and can be picked up and thrown — it falls, bounces off
/// the walls, lands, and goes back to pottering about.
///
/// Deliberately mounted inside the shell rather than over the whole app, so it
/// is present while browsing and gone the moment a real task opens: a mascot
/// wandering across the display test would be caught by the very test looking
/// for dead pixels, and one sitting over the multi-touch panel would eat the
/// touches it is counting.
class AppMascot extends StatefulWidget {
  const AppMascot({super.key, this.now});

  /// Overrides the clock, so a test can be a Sunday at 2am.
  @visibleForTesting
  final DateTime Function()? now;

  @override
  State<AppMascot> createState() => _AppMascotState();
}

class _AppMascotState extends State<AppMascot>
    with SingleTickerProviderStateMixin {
  static const Size _size = Size(52, 64);

  // --- the physical world, in logical pixels and seconds -------------------
  static const double _gravity = 2200;
  static const double _walkSpeed = 34;
  static const double _airDrag = 0.6;
  static const double _wallBounce = -0.5;
  static const double _floorBounce = -0.38;

  /// Below this, a bounce is not worth drawing — it becomes a landing.
  static const double _restingSpeed = 70;

  /// How far a pupil can travel from the centre of its eye.
  static const double _pupilReach = 2.6;

  /// Hitting a wall faster than this knocks it silly. Slow enough that a
  /// gentle nudge into the edge is just a bump, fast enough that walking
  /// into the wall on its own two feet never is.
  static const double _dazeSpeed = 260;
  static const double _dazeSeconds = 1.6;

  late final Ticker _ticker = createTicker(_onFrame);

  Offset _position = Offset.zero;
  Offset _velocity = Offset.zero;
  MascotState _state = MascotState.idle;

  /// -1 left, 1 right. Which way it faces, and walks.
  int _facing = -1;

  Size _area = Size.zero;
  bool _placed = false;
  Duration _lastFrame = Duration.zero;

  /// Seconds left in the current behaviour before it picks another.
  double _untilNextChoice = 1.5;

  /// Drives the walk cycle and the blink.
  double _clock = 0;

  /// Squash on landing, decaying back to 1.
  double _impact = 0;

  /// 1 right after a hard knock, decaying to 0. Drives the head shake, the
  /// spinning eyes and the stars.
  double _dazed = 0;

  /// Where it is looking, in this box's coordinates. Null means straight out.
  Offset? _lookAt;

  bool _speaking = false;

  /// What it last said, so it does not repeat itself immediately.
  String? _saying;

  /// When this one started walking, and how roughly it has been handled.
  final DateTime _startedAt = DateTime.now();
  int _thrown = 0;
  int _bumps = 0;

  final Random _random = Random();

  DateTime get _now => (widget.now ?? DateTime.now)();

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // No ticker at all under reduced motion: it stands still, which also
    // means a screen holding one can still be settled.
    if (_reduceMotion) {
      if (_ticker.isActive) _ticker.stop();
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  double get _floor => _area.height - _size.height;

  void _onFrame(Duration elapsed) {
    final dt = (elapsed - _lastFrame).inMicroseconds / 1e6;
    _lastFrame = elapsed;
    // A first frame, or a return from the background, would otherwise apply a
    // huge dt and fling it off screen.
    if (dt <= 0 || dt > 0.1 || !_placed) return;

    _clock += dt;
    if (_impact > 0) _impact = max(0, _impact - dt * 4);
    if (_dazed > 0) _dazed = max(0, _dazed - dt / _dazeSeconds);

    switch (_state) {
      case MascotState.dragged:
        break;
      case MascotState.falling:
        _fall(dt);
      case MascotState.idle:
      case MascotState.walking:
        _potter(dt);
    }

    setState(() {});
  }

  void _fall(double dt) {
    _velocity = Offset(
      _velocity.dx * (1 - _airDrag * dt),
      _velocity.dy + _gravity * dt,
    );
    var next = _position + _velocity * dt;

    final maxX = _area.width - _size.width;
    if (next.dx <= 0 || next.dx >= maxX) {
      // Measured before the bounce: the speed it arrived at is what hurt.
      if (_velocity.dx.abs() > _dazeSpeed) {
        _dazed = 1;
        _bumps++;
      }
      next = Offset(next.dx.clamp(0.0, maxX), next.dy);
      _velocity = Offset(_velocity.dx * _wallBounce, _velocity.dy);
      _facing = _velocity.dx < 0 ? -1 : 1;
    }

    // The ceiling is a wall too — thrown hard upward it should not vanish.
    if (next.dy < 0) {
      next = Offset(next.dx, 0);
      _velocity = Offset(_velocity.dx, _velocity.dy.abs() * 0.4);
    }

    if (next.dy >= _floor) {
      next = Offset(next.dx, _floor);
      if (_velocity.dy.abs() > _restingSpeed) {
        if (_velocity.dy.abs() > _dazeSpeed * 2.5) _dazed = 1;
        _velocity = Offset(_velocity.dx * 0.6, _velocity.dy * _floorBounce);
        _impact = 1;
      } else {
        _land();
      }
    }

    _position = next;
  }

  void _land() {
    _velocity = Offset.zero;
    _state = MascotState.idle;
    _impact = 1;
    _untilNextChoice = 0.6 + _random.nextDouble();
  }

  /// Walking and standing about on the floor.
  void _potter(double dt) {
    // Too dizzy to go anywhere. Standing still is the point of being dazed.
    if (_dazed > 0) {
      _state = MascotState.idle;
      _untilNextChoice = 0.4;
      return;
    }

    _untilNextChoice -= dt;

    if (_untilNextChoice <= 0) {
      // Mostly walk, sometimes stop and look around — always moving reads as
      // restless, never moving reads as a sticker.
      if (_random.nextDouble() < 0.65) {
        _state = MascotState.walking;
        _facing = _random.nextBool() ? -1 : 1;
        _untilNextChoice = 1.2 + _random.nextDouble() * 2.4;
      } else {
        _state = MascotState.idle;
        _untilNextChoice = 1.0 + _random.nextDouble() * 2.0;
      }
    }

    if (_state != MascotState.walking) return;

    final maxX = _area.width - _size.width;
    var x = _position.dx + _facing * _walkSpeed * dt;
    if (x <= 0 || x >= maxX) {
      // Turn round at the edge rather than pressing into it.
      x = x.clamp(0.0, maxX);
      _facing = -_facing;
    }
    _position = Offset(x, _floor);
  }

  void _layout(Size area) {
    final changed = area != _area;
    _area = area;
    if (!_placed) {
      _placed = true;
      _position = Offset(area.width - _size.width - 12, _floor);
    } else if (changed) {
      // A rotation or a keyboard must not leave it stranded off screen.
      _position = Offset(
        _position.dx.clamp(0.0, max(0.0, area.width - _size.width)),
        _position.dy.clamp(0.0, max(0.0, _floor)),
      );
    }
  }

  void _tapped() {
    setState(() {
      _speaking = !_speaking;
      if (_speaking) {
        _saying = MascotRemarks.pick(
          now: _now,
          walked: _now.difference(_startedAt),
          thrown: _thrown,
          bumps: _bumps,
          random: _random,
          previous: _saying,
        );
      }
      _impact = 1;
    });
  }

  void _pickUp() {
    setState(() {
      _state = MascotState.dragged;
      _speaking = false;
      _velocity = Offset.zero;
      _dazed = 0;
    });
  }

  void _drag(Offset delta) {
    setState(() {
      _position = Offset(
        (_position.dx + delta.dx)
            .clamp(0.0, max(0.0, _area.width - _size.width)),
        (_position.dy + delta.dy).clamp(0.0, max(0.0, _floor)),
      );
      _facing = delta.dx < 0 ? -1 : (delta.dx > 0 ? 1 : _facing);
    });
  }

  void _release(Velocity velocity) {
    setState(() {
      if (_reduceMotion) {
        _position = Offset(_position.dx, _floor);
        _state = MascotState.idle;
        return;
      }
      // Thrown: it keeps the speed it was let go at, halved so a flick across
      // the screen does not become a rocket.
      _velocity = velocity.pixelsPerSecond * 0.5;
      _state = MascotState.falling;
      if (_velocity.distance > 200) _thrown++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _layout(Size(constraints.maxWidth, constraints.maxHeight));
        final onLeftHalf = _position.dx < _area.width / 2;

        return Listener(
          // Watches where fingers go without taking the touches: everything
          // underneath still receives them, which is the whole point of an
          // overlay that is only ever decoration.
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) => setState(() => _lookAt = e.localPosition),
          onPointerMove: (e) => setState(() => _lookAt = e.localPosition),
          child: Stack(
            children: [
              Positioned(
                left: _position.dx,
                top: _position.dy,
                child: GestureDetector(
                  onTap: _tapped,
                  onPanStart: (_) => _pickUp(),
                  onPanUpdate: (d) => _drag(d.delta),
                  onPanEnd: (d) => _release(d.velocity),
                  child: RepaintBoundary(child: _character()),
                ),
              ),
              if (_speaking)
                Positioned(
                  left: onLeftHalf ? _position.dx + _size.width + 6 : null,
                  right: onLeftHalf ? null : _area.width - _position.dx + 6,
                  top: (_position.dy - 8)
                      .clamp(0.0, max(0.0, _area.height - 90)),
                  child: _bubble(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _character() {
    final walking = _state == MascotState.walking;
    // Legs swing from one phase; the body bobs at twice the rate, because it
    // rises on each step rather than each stride.
    final stride = walking ? sin(_clock * 9) : 0.0;
    final bob = walking ? (cos(_clock * 18) + 1) * 0.9 : 0.0;

    // Squashed on impact, stretched while falling — the two readings that
    // make weight legible.
    final squash = 1 + 0.22 * Curves.easeOut.transform(_impact);
    final stretch = _state == MascotState.falling
        ? (1 + (_velocity.dy.abs() / 2600)).clamp(1.0, 1.18)
        : 1.0;

    // A fast wobble that dies away with the daze — the head shake.
    final wobble = _dazed > 0 ? sin(_clock * 38) * 0.13 * _dazed : 0.0;

    return Transform.translate(
      offset: Offset(0, -bob),
      child: Transform.rotate(
        alignment: Alignment.bottomCenter,
        angle: wobble,
        child: Transform(
          alignment: Alignment.bottomCenter,
          transform: Matrix4.identity()
            ..scaleByDouble(squash / stretch, stretch / squash, 1.0, 1.0),
          child: SizedBox(
            width: _size.width,
            height: _size.height,
            child: CustomPaint(
              painter: _MascotPainter(
                facing: _facing,
                stride: stride,
                blinking: _blinking,
                excited: _speaking || _state == MascotState.dragged,
                pupil: _pupilOffset(),
                dazed: _dazed,
                clock: _clock,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A blink is a brief event, not a fade — eyes that ease shut look sleepy.
  bool get _blinking {
    final phase = _clock % 4.2;
    return phase > 4.0 && phase < 4.1;
  }

  /// How far the pupils slide towards whatever was last touched.
  Offset _pupilOffset() {
    final look = _lookAt;
    if (look == null) return Offset.zero;

    final eyes = _position + Offset(_size.width / 2, _size.height * 0.34);
    final toward = look - eyes;
    final distance = toward.distance;
    if (distance < 1) return Offset.zero;

    // Full deflection once the finger is a little way off; nearer than that
    // and the eyes would snap about distractingly.
    final reach = (distance / 90).clamp(0.0, 1.0) * _pupilReach;
    return toward / distance * reach;
  }

  Widget _bubble() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Text(
        _saying ?? '',
        style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary),
      ),
    );
  }
}

class _MascotPainter extends CustomPainter {
  _MascotPainter({
    required this.facing,
    required this.stride,
    required this.blinking,
    required this.excited,
    required this.pupil,
    required this.dazed,
    required this.clock,
  });

  final int facing;

  /// -1..1, the swing of the legs through a step.
  final double stride;

  final bool blinking;
  final bool excited;
  final Offset pupil;

  /// 1 just after a knock, fading to 0.
  final double dazed;

  /// Seconds since the mascot woke up, for spinning things.
  final double clock;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Legs, behind the body, swinging out of phase with each other.
    final legPaint = Paint()..color = AppColors.primaryDark;
    for (final (i, dx) in [0.34, 0.66].indexed) {
      final swing = stride * (i == 0 ? 1 : -1) * w * 0.10;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(w * dx + swing, h * 0.90),
            width: w * 0.2,
            height: h * 0.13,
          ),
          Radius.circular(w * 0.07),
        ),
        legPaint,
      );
    }

    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.08, h * 0.05, w * 0.84, h * 0.80),
      Radius.circular(w * 0.26),
    );

    canvas.drawRRect(
      body.shift(const Offset(0, 3)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawRRect(body, Paint()..color = AppColors.primary);

    // The screen it wears as a face, shifted the way it is facing so the
    // whole head reads as turned rather than the eyes alone.
    final turn = facing * w * 0.03;
    final face = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.17 + turn, h * 0.14, w * 0.66, h * 0.50),
      Radius.circular(w * 0.16),
    );
    canvas.drawRRect(face, Paint()..color = Colors.white);

    final eyeY = h * 0.34;
    final eyeR = w * 0.085;

    if (blinking) {
      final lid = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.055
        ..strokeCap = StrokeCap.round
        ..color = AppColors.textPrimary;
      for (final dx in [0.36, 0.64]) {
        final cx = w * dx + turn;
        canvas.drawLine(Offset(cx - eyeR, eyeY), Offset(cx + eyeR, eyeY), lid);
      }
      return;
    }

    for (final (i, dx) in [0.36, 0.64].indexed) {
      final centre = Offset(w * dx + turn, eyeY);
      canvas.drawCircle(centre, eyeR, Paint()..color = const Color(0xFFE8EAEA));

      if (dazed > 0) {
        // Each eye spins the opposite way, which reads as dizzy rather than
        // as two eyes politely rotating in step.
        _spiral(
          canvas,
          centre,
          eyeR * 0.95,
          clock * (i == 0 ? 7 : -7),
          eyeR * 0.3,
        );
        continue;
      }

      // The white of the eye stays put; only the pupil tracks, which is what
      // makes it read as looking rather than as the face sliding about.
      canvas.drawCircle(
        centre + pupil,
        eyeR * 0.62,
        Paint()..color = AppColors.textPrimary,
      );
      canvas.drawCircle(
        centre + pupil + Offset(eyeR * 0.2, -eyeR * 0.2),
        eyeR * 0.2,
        Paint()..color = Colors.white,
      );
    }

    if (dazed > 0) {
      _wavyMouth(canvas, Offset(w * 0.5 + turn, h * 0.48), w * 0.24);
      _stars(canvas, size);
      return;
    }

    final mouth = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.05
      ..strokeCap = StrokeCap.round
      ..color = AppColors.textPrimary;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w * 0.5 + turn, h * 0.47),
        width: excited ? w * 0.24 : w * 0.16,
        height: excited ? h * 0.15 : h * 0.09,
      ),
      0.15 * pi,
      0.7 * pi,
      false,
      mouth,
    );

    if (excited) {
      final blush = Paint()..color = AppColors.error.withValues(alpha: 0.22);
      for (final dx in [0.25, 0.75]) {
        canvas.drawCircle(Offset(w * dx + turn, h * 0.44), w * 0.06, blush);
      }
    }
  }

  /// A wobbling line where the smile goes, for a face that cannot hold one.
  void _wavyMouth(Canvas canvas, Offset centre, double width) {
    const steps = 12;
    final path = Path();
    for (var i = 0; i <= steps; i++) {
      final along = i / steps;
      final x = centre.dx - width / 2 + width * along;
      final y = centre.dy + sin(along * 3 * pi) * width * 0.11;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 0.19
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.textPrimary,
    );
  }

  /// A spiral, for an eye that has stopped focusing on anything.
  void _spiral(
    Canvas canvas,
    Offset centre,
    double radius,
    double phase,
    double width,
  ) {
    const turns = 2.1;
    const steps = 24;
    final path = Path();
    for (var i = 0; i <= steps; i++) {
      final along = i / steps;
      final angle = phase + along * turns * 2 * pi;
      final r = radius * along;
      final point = centre + Offset(cos(angle) * r, sin(angle) * r);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..color = AppColors.textPrimary,
    );
  }

  /// Stars going round the head, fading out as it comes to its senses.
  ///
  /// The orbit is an ellipse rather than a circle, and they pass in front of
  /// the face on the near side — a ring drawn only above the head reads as a
  /// halo, which is a different joke entirely.
  void _stars(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fade = Curves.easeOut.transform(dazed.clamp(0.0, 1.0));

    for (var i = 0; i < 3; i++) {
      final angle = clock * 3.4 + i * 2 * pi / 3;
      final centre = Offset(
        w * 0.5 + cos(angle) * w * 0.46,
        h * 0.16 + sin(angle) * h * 0.085,
      );
      // Smaller on the far side of the orbit, so it has some depth.
      final depth = 0.7 + 0.3 * ((sin(angle) + 1) / 2);
      _star(
        canvas,
        centre,
        w * 0.085 * depth * fade,
        angle * 1.7,
        AppColors.warning.withValues(alpha: fade),
      );
    }
  }

  void _star(Canvas canvas, Offset centre, double radius, double rotation,
      Color colour) {
    if (radius <= 0.2) return;
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? radius : radius * 0.45;
      final angle = rotation + i * pi / 5 - pi / 2;
      final point = centre + Offset(cos(angle) * r, sin(angle) * r);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = colour);
  }

  @override
  bool shouldRepaint(_MascotPainter old) =>
      old.dazed != dazed ||
      old.clock != clock ||
      old.facing != facing ||
      old.stride != stride ||
      old.blinking != blinking ||
      old.excited != excited ||
      old.pupil != pupil;
}
