import 'package:flutter/material.dart';

import '../../models/checkup_result.dart';

/// The verdict badge that draws itself when a test finishes.
///
/// A tick that is simply *there* the instant the page changes is easy to
/// miss, and gives no sense that the phone just earned it. Drawing the ring
/// and then the stroke takes about three quarters of a second, which is long
/// enough to register and short enough to stay inside the 1500ms the page
/// waits before popping to the next test.
///
/// Every status animates, not only a pass: one status appearing instantly
/// beside another that animates reads as a glitch rather than a distinction.
/// What differs is the character — a pass throws off a ring of light, a fail
/// draws a cross with a small shake, and the quieter outcomes simply fade in.
class CheckupVerdictMark extends StatefulWidget {
  const CheckupVerdictMark({
    super.key,
    required this.status,
    this.size = 104,
  });

  final CheckupStatus status;
  final double size;

  @override
  State<CheckupVerdictMark> createState() => _CheckupVerdictMarkState();
}

class _CheckupVerdictMarkState extends State<CheckupVerdictMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 780),
  );

  @override
  void initState() {
    super.initState();
    // Plays once and stops, so a page showing one can still be settled in a
    // test — unlike the looping instruction demos.
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _VerdictPainter(
            status: widget.status,
            // Jump straight to the finished mark when the system asks for no
            // motion; the drawing is decoration, the mark is the message.
            t: reduceMotion ? 1 : _controller.value,
          ),
        ),
      ),
    );
  }
}

class _VerdictPainter extends CustomPainter {
  _VerdictPainter({required this.status, required this.t});

  final CheckupStatus status;
  final double t;

  /// Strokes are described in a 100×100 box and scaled to the real one, so
  /// the proportions hold at any size.
  static const double _design = 100;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _design;
    canvas.save();
    canvas.scale(scale);

    const centre = Offset(_design / 2, _design / 2);
    final colour = status.color;

    // Phase 1: the ring sweeps round. Phase 2: the stroke draws inside it.
    final ring = Curves.easeOutCubic.transform((t / 0.5).clamp(0.0, 1.0));
    final stroke =
        Curves.easeOutCubic.transform(((t - 0.35) / 0.45).clamp(0.0, 1.0));

    if (status == CheckupStatus.pass) _halo(canvas, centre, colour);

    // A soft disc behind everything, fading up with the ring.
    canvas.drawCircle(
      centre,
      34,
      Paint()..color = status.softColor.withValues(alpha: ring),
    );

    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: 34),
      -3.14159 / 2,
      6.28318 * ring,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = colour,
    );

    if (stroke > 0) {
      final pen = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = colour;

      for (final path in _markPaths()) {
        canvas.drawPath(_partial(path, stroke), pen);
      }
    }

    canvas.restore();
  }

  /// Rings thrown outward from a pass, fading as they go.
  void _halo(Canvas canvas, Offset centre, Color colour) {
    final burst = ((t - 0.4) / 0.6).clamp(0.0, 1.0);
    if (burst <= 0) return;

    for (var ring = 0; ring < 2; ring++) {
      final progress =
          Curves.easeOutCubic.transform((burst - ring * 0.18).clamp(0.0, 1.0));
      if (progress <= 0) continue;
      canvas.drawCircle(
        centre,
        34 + progress * 16,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - progress)
          ..color = colour.withValues(alpha: (1 - progress) * 0.5),
      );
    }
  }

  /// The stroke inside the ring, as one path per pen lift.
  List<Path> _markPaths() {
    switch (status) {
      case CheckupStatus.pass:
        return [
          Path()
            ..moveTo(33, 51)
            ..lineTo(45, 63)
            ..lineTo(68, 39)
        ];
      case CheckupStatus.fail:
        return [
          Path()
            ..moveTo(38, 38)
            ..lineTo(62, 62),
          Path()
            ..moveTo(62, 38)
            ..lineTo(38, 62),
        ];
      case CheckupStatus.skipped:
        return [
          Path()
            ..moveTo(36, 50)
            ..lineTo(64, 50)
        ];
      case CheckupStatus.notAvailable:
        // An exclamation: a dot reads as unfinished when drawn on its own, so
        // the stem carries the motion and the dot lands at the end.
        return [
          Path()
            ..moveTo(50, 34)
            ..lineTo(50, 54),
          Path()
            ..moveTo(50, 65)
            ..lineTo(50, 66),
        ];
    }
  }

  /// The first [fraction] of [path], so a line can be drawn as if by hand.
  Path _partial(Path path, double fraction) {
    if (fraction >= 1) return path;

    final drawn = Path();
    for (final metric in path.computeMetrics()) {
      drawn.addPath(
        metric.extractPath(0, metric.length * fraction),
        Offset.zero,
      );
    }
    return drawn;
  }

  @override
  bool shouldRepaint(_VerdictPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.status != status;
}
