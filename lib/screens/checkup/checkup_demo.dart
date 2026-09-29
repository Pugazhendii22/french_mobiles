import 'dart:math';

import 'package:flutter/material.dart';

import '../../shared/theme/app_colors.dart';

/// What a test is asking the user to physically do.
///
/// Each one animates; none of them contains a word. The checkup is used by
/// people selling a phone, not by people who read the app's English — a box
/// with "tap five fingers" written under it tells them nothing, and a test
/// nobody understands is a test that gets skipped or failed for no reason.
enum CheckupDemoKind {
  volumeButtons,
  powerButton,
  fiveFingers,
  swipeScreen,
  colourSweep,
  torch,
  cameraFlip,
  speakerSound,
  earpieceToEar,
  microphone,
  proximityHand,
  vibration,
  wifiScan,
  bluetoothScan,
  fingerprint,
  signalBars,
  dataExchange,
  connectionGraph,
  gpsFix,
  rotatePhone,
  batteryHealth,
  cpuLoad,
}

/// A looping, wordless illustration of what to do.
class CheckupDemo extends StatefulWidget {
  const CheckupDemo({super.key, required this.kind, this.height = 132});

  final CheckupDemoKind kind;
  final double height;

  @override
  State<CheckupDemo> createState() => _CheckupDemoState();
}

class _CheckupDemoState extends State<CheckupDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    // Slow enough to follow without watching closely, short enough that the
    // loop repeats while someone is still working out what it means.
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Honour the system's "remove animations" setting. Beyond being the right
    // thing for someone who gets motion sick, this is the only way a caller
    // can make a page holding one of these settle — an indefinitely repeating
    // controller never finishes, so pumpAndSettle would wait forever.
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _controller.stop();
      // Mid-loop rather than the start: most of these illustrations are at
      // their most explanatory half way through, with the finger down or the
      // waves out, and a still frame has to carry the whole meaning.
      _controller.value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _DemoPainter(kind: widget.kind, t: _controller.value),
        ),
      ),
    );
  }
}

class _DemoPainter extends CustomPainter {
  _DemoPainter({required this.kind, required this.t});

  final CheckupDemoKind kind;

  /// 0..1, looping.
  final double t;

  static const Color _outline = AppColors.textSecondary;
  static const Color _accent = AppColors.primary;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final phone = Rect.fromCenter(
      center: centre,
      width: size.height * 0.52,
      height: size.height * 0.88,
    );

    switch (kind) {
      case CheckupDemoKind.volumeButtons:
        _volumeButtons(canvas, phone);
      case CheckupDemoKind.powerButton:
        _powerButton(canvas, phone);
      case CheckupDemoKind.fiveFingers:
        _fiveFingers(canvas, phone);
      case CheckupDemoKind.swipeScreen:
        _swipeScreen(canvas, phone);
      case CheckupDemoKind.colourSweep:
        _colourSweep(canvas, phone);
      case CheckupDemoKind.torch:
        _torch(canvas, phone);
      case CheckupDemoKind.cameraFlip:
        _cameraFlip(canvas, phone);
      case CheckupDemoKind.speakerSound:
        _speakerSound(canvas, phone);
      case CheckupDemoKind.earpieceToEar:
        _earpieceToEar(canvas, phone, size);
      case CheckupDemoKind.microphone:
        _microphone(canvas, phone);
      case CheckupDemoKind.proximityHand:
        _proximityHand(canvas, phone);
      case CheckupDemoKind.vibration:
        _vibration(canvas, phone);
      case CheckupDemoKind.wifiScan:
        _waves(canvas, centre, Icons.wifi_rounded);
      case CheckupDemoKind.bluetoothScan:
        _waves(canvas, centre, Icons.bluetooth_rounded);
      case CheckupDemoKind.fingerprint:
        _fingerprint(canvas, phone);
      case CheckupDemoKind.signalBars:
        _signalBars(canvas, phone);
      case CheckupDemoKind.dataExchange:
        _dataExchange(canvas, phone);
      case CheckupDemoKind.connectionGraph:
        _connectionGraph(canvas, size);
      case CheckupDemoKind.gpsFix:
        _gpsFix(canvas, centre);
      case CheckupDemoKind.rotatePhone:
        _rotatePhone(canvas, phone, centre);
      case CheckupDemoKind.batteryHealth:
        _batteryHealth(canvas, size);
      case CheckupDemoKind.cpuLoad:
        _cpuLoad(canvas, size);
    }
  }

  // --- shared pieces -------------------------------------------------------

  Paint get _stroke => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.4
    ..strokeCap = StrokeCap.round
    ..color = _outline;

  void _phoneBody(Canvas canvas, Rect r, {Color? screen}) {
    final body = RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.16));
    if (screen != null) {
      canvas.drawRRect(body, Paint()..color = screen);
    }
    canvas.drawRRect(body, _stroke);
  }

  /// The pressing finger: a filled circle with a soft halo, so it reads as a
  /// fingertip rather than as a dot that belongs to the phone.
  void _finger(Canvas canvas, Offset at, double press) {
    canvas.drawCircle(
      at,
      9 + 7 * press,
      Paint()..color = _accent.withValues(alpha: 0.18 * press),
    );
    canvas.drawCircle(at, 8, Paint()..color = _accent);
  }

  /// 0..1..0 over the loop, eased — one press per cycle.
  double get _pulse {
    final wave = sin(t * 2 * pi);
    return wave < 0 ? 0 : Curves.easeInOut.transform(wave);
  }

  /// Splits the loop into [count] equal phases, returning (index, progress).
  (int, double) _phase(int count) {
    final scaled = t * count;
    return (scaled.floor().clamp(0, count - 1), scaled - scaled.floor());
  }

  void _glyph(
      Canvas canvas, IconData icon, Offset at, double size, Color colour) {
    final builder = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: colour,
        ),
      ),
    )..layout();
    builder.paint(canvas, at - Offset(builder.width / 2, builder.height / 2));
  }

  // --- the demos -----------------------------------------------------------

  void _volumeButtons(Canvas canvas, Rect phone) {
    _phoneBody(canvas, phone);

    final buttonX = phone.right;
    final upper = Offset(buttonX, phone.top + phone.height * 0.26);
    final lower = Offset(buttonX, phone.top + phone.height * 0.42);

    // Two presses per loop: the upper button, then the lower one, which is
    // what the test asks for in that order.
    final (index, progress) = _phase(2);
    final press = Curves.easeInOut.transform(sin(progress * pi).clamp(0, 1));

    for (final (i, button) in [upper, lower].indexed) {
      final active = i == index;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: button, width: 5, height: 16),
          const Radius.circular(3),
        ),
        Paint()..color = active ? _accent : _outline,
      );
      if (active) _finger(canvas, button + Offset(16 - 6 * press, 0), press);
    }
  }

  void _powerButton(Canvas canvas, Rect phone) {
    _phoneBody(canvas, phone);
    final button = Offset(phone.right, phone.center.dy);
    final press = _pulse;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: button, width: 5, height: 22),
        const Radius.circular(3),
      ),
      Paint()..color = press > 0.15 ? _accent : _outline,
    );
    _finger(canvas, button + Offset(16 - 6 * press, 0), press);
  }

  void _fiveFingers(Canvas canvas, Rect phone) {
    _phoneBody(canvas, phone, screen: AppColors.primarySoft);

    // Fingertips land one after another, then all five hold together — the
    // test needs five at once, and showing them arrive makes that readable.
    const count = 5;
    final positions = [
      Offset(phone.left + phone.width * 0.22, phone.top + phone.height * 0.34),
      Offset(phone.left + phone.width * 0.50, phone.top + phone.height * 0.24),
      Offset(phone.left + phone.width * 0.78, phone.top + phone.height * 0.34),
      Offset(phone.left + phone.width * 0.32, phone.top + phone.height * 0.62),
      Offset(phone.left + phone.width * 0.68, phone.top + phone.height * 0.62),
    ];

    for (var i = 0; i < count; i++) {
      final appearAt = i / (count * 1.6);
      if (t < appearAt) continue;
      final age = ((t - appearAt) * 6).clamp(0.0, 1.0);
      _finger(canvas, positions[i], age);
    }
  }

  void _swipeScreen(Canvas canvas, Rect phone) {
    _phoneBody(canvas, phone, screen: AppColors.primarySoft);

    final travel = Curves.easeInOut.transform(t);
    final y = phone.top + phone.height * (0.25 + 0.5 * travel);
    final from = Offset(phone.center.dx, phone.top + phone.height * 0.25);
    final to = Offset(phone.center.dx, y);

    canvas.drawLine(
      from,
      to,
      _stroke
        ..color = _accent.withValues(alpha: 0.45)
        ..strokeWidth = 4,
    );
    _finger(canvas, to, 1);
  }

  void _colourSweep(Canvas canvas, Rect phone) {
    const colours = [
      Color(0xFFEF4444),
      Color(0xFF22C55E),
      Color(0xFF3B82F6),
      Color(0xFFFFFFFF),
    ];
    final (index, _) = _phase(colours.length);
    _phoneBody(canvas, phone, screen: colours[index]);
  }

  void _torch(Canvas canvas, Rect phone) {
    _phoneBody(canvas, phone);
    final led = Offset(phone.center.dx, phone.top + phone.height * 0.18);
    final on = _pulse;

    for (var ring = 1; ring <= 3; ring++) {
      canvas.drawCircle(
        led,
        6.0 + ring * 9 * on,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.warning.withValues(alpha: 0.5 * on / ring),
      );
    }
    canvas.drawCircle(
      led,
      6,
      Paint()..color = Color.lerp(_outline, AppColors.warning, on)!,
    );
  }

  void _cameraFlip(Canvas canvas, Rect phone) {
    // Turning the phone over: the body squashes horizontally, passes through
    // edge-on, and comes back — the same motion as flipping it in the hand.
    final turn = sin(t * 2 * pi);
    final squash = turn.abs().clamp(0.12, 1.0);

    canvas.save();
    canvas.translate(phone.center.dx, phone.center.dy);
    canvas.scale(squash, 1);
    canvas.translate(-phone.center.dx, -phone.center.dy);
    _phoneBody(canvas, phone);
    _glyph(
      canvas,
      Icons.photo_camera_rounded,
      phone.center,
      phone.width * 0.42,
      turn >= 0 ? _accent : _outline,
    );
    canvas.restore();
  }

  void _speakerSound(Canvas canvas, Rect phone) {
    _phoneBody(canvas, phone);
    _arcs(canvas, Offset(phone.right, phone.bottom - phone.height * 0.1),
        fromAngle: -pi * 0.75);
  }

  void _earpieceToEar(Canvas canvas, Rect phone, Size size) {
    // The phone leans towards an ear, which is the instruction: hold it up
    // as if on a call.
    final lean = Curves.easeInOut.transform(_pulse) * 0.22;
    final shifted = phone.translate(-size.width * 0.08, 0);

    canvas.save();
    canvas.translate(shifted.center.dx, shifted.center.dy);
    canvas.rotate(lean);
    canvas.translate(-shifted.center.dx, -shifted.center.dy);
    _phoneBody(canvas, shifted);
    canvas.restore();

    _glyph(
      canvas,
      Icons.hearing_rounded,
      Offset(size.width * 0.72, shifted.center.dy),
      30,
      _outline,
    );
    _arcs(canvas, Offset(shifted.right, shifted.top + shifted.height * 0.18),
        fromAngle: -pi * 0.35, spread: pi * 0.5);
  }

  /// Expanding sound arcs, used by both speaker and earpiece.
  void _arcs(Canvas canvas, Offset from,
      {double fromAngle = -pi / 2, double spread = pi * 0.9}) {
    for (var ring = 1; ring <= 3; ring++) {
      final progress = ((t * 3) + ring / 3) % 1;
      canvas.drawArc(
        Rect.fromCircle(center: from, radius: 8 + progress * 26),
        fromAngle,
        spread,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..color = _accent.withValues(alpha: (1 - progress) * 0.9),
      );
    }
  }

  void _microphone(Canvas canvas, Rect phone) {
    _glyph(
        canvas, Icons.mic_rounded, phone.center.translate(0, -12), 46, _accent);

    // A level meter that moves: silence would look identical to a broken mic.
    const bars = 7;
    final baseY = phone.bottom - 6;
    for (var i = 0; i < bars; i++) {
      final wave = sin((t * 2 * pi * 2) + i * 0.8).abs();
      final height = 5 + wave * 20;
      final x = phone.center.dx + (i - bars ~/ 2) * 10;
      canvas.drawLine(
        Offset(x, baseY),
        Offset(x, baseY - height),
        Paint()
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = _accent.withValues(alpha: 0.35 + wave * 0.65),
      );
    }
  }

  void _proximityHand(Canvas canvas, Rect phone) {
    _phoneBody(canvas, phone);

    final sensor = Offset(phone.center.dx, phone.top + phone.height * 0.08);
    final approach = _pulse;
    canvas.drawCircle(
      sensor,
      4,
      Paint()..color = Color.lerp(_outline, _accent, approach)!,
    );

    // A palm coming down over the top of the phone and away again.
    final handY = phone.top - 26 + approach * 26;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(phone.center.dx, handY),
          width: phone.width * 1.25,
          height: 22,
        ),
        const Radius.circular(11),
      ),
      Paint()..color = _accent.withValues(alpha: 0.25 + approach * 0.5),
    );
  }

  void _vibration(Canvas canvas, Rect phone) {
    final shake = sin(t * 2 * pi * 6) * 5;
    canvas.save();
    canvas.translate(shake, 0);
    _phoneBody(canvas, phone);
    canvas.restore();

    for (final side in [-1, 1]) {
      for (var i = 1; i <= 2; i++) {
        final x = phone.center.dx + side * (phone.width / 2 + 8 + i * 8);
        canvas.drawLine(
          Offset(x, phone.center.dy - 12),
          Offset(x, phone.center.dy + 12),
          Paint()
            ..strokeWidth = 2.4
            ..strokeCap = StrokeCap.round
            ..color = _accent.withValues(alpha: 0.65 / i),
        );
      }
    }
  }

  void _waves(Canvas canvas, Offset centre, IconData icon) {
    for (var ring = 1; ring <= 3; ring++) {
      final progress = ((t * 2) + ring / 3) % 1;
      canvas.drawCircle(
        centre,
        22 + progress * 30,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = _accent.withValues(alpha: (1 - progress) * 0.7),
      );
    }
    _glyph(canvas, icon, centre, 40, _accent);
  }

  void _fingerprint(Canvas canvas, Rect phone) {
    final centre = phone.center;
    final press = _pulse;

    for (var ring = 0; ring < 4; ring++) {
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: 9.0 + ring * 7),
        -pi * 0.85,
        pi * 1.7,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..color = Color.lerp(_outline, _accent, press)!
              .withValues(alpha: 0.4 + 0.6 * press),
      );
    }
    canvas.drawCircle(
      centre,
      30 + press * 10,
      Paint()..color = _accent.withValues(alpha: 0.12 * press),
    );
  }

  void _signalBars(Canvas canvas, Rect phone) {
    const bars = 4;
    final filled = (t * (bars + 1)).floor().clamp(0, bars);
    final baseY = phone.bottom - phone.height * 0.2;

    for (var i = 0; i < bars; i++) {
      final height = 10.0 + i * 11;
      final x = phone.center.dx + (i - 1.5) * 16;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 5, baseY - height, 10, height),
          const Radius.circular(3),
        ),
        Paint()..color = i < filled ? _accent : AppColors.border,
      );
    }
  }

  void _dataExchange(Canvas canvas, Rect phone) {
    _phoneBody(canvas, phone);
    _glyph(canvas, Icons.cloud_rounded, Offset(phone.center.dx, phone.top - 18),
        30, _outline);

    // A packet travelling up and back, so it reads as two-way traffic rather
    // than a static cloud picture.
    final up = t < 0.5;
    final leg = (up ? t : t - 0.5) * 2;
    final from = up ? phone.top + 6 : phone.top - 12;
    final to = up ? phone.top - 12 : phone.top + 6;
    final y = from + (to - from) * Curves.easeInOut.transform(leg);

    canvas.drawCircle(
      Offset(phone.center.dx, y),
      5,
      Paint()..color = up ? _accent : AppColors.success,
    );
  }

  void _connectionGraph(Canvas canvas, Size size) {
    final left = size.width * 0.18;
    final right = size.width * 0.82;
    final baseY = size.height * 0.72;
    final topY = size.height * 0.28;

    canvas.drawLine(
      Offset(left, baseY),
      Offset(right, baseY),
      Paint()
        ..strokeWidth = 1.5
        ..color = AppColors.border,
    );

    // A trace that runs high, drops out, and recovers — the exact fault the
    // stability test exists to find.
    const samples = 18;
    final drawn = (t * samples).ceil().clamp(1, samples);
    for (var i = 0; i < drawn; i++) {
      final fraction = i / (samples - 1);
      final x = left + (right - left) * fraction;
      final failing = i >= 7 && i <= 10;
      final height =
          failing ? 0.0 : (baseY - topY) * (0.6 + 0.4 * sin(i * 1.1));
      canvas.drawLine(
        Offset(x, baseY),
        Offset(x, baseY - (failing ? 6 : height)),
        Paint()
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = failing ? AppColors.error : AppColors.success,
      );
    }
  }

  void _gpsFix(Canvas canvas, Offset centre) {
    for (var ring = 1; ring <= 3; ring++) {
      final progress = ((t * 1.6) + ring / 3) % 1;
      canvas.drawCircle(
        centre.translate(0, 8),
        14 + progress * 34,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = _accent.withValues(alpha: (1 - progress) * 0.7),
      );
    }

    // The pin drops in and settles, rather than simply being there.
    final drop = Curves.bounceOut.transform((t * 1.6).clamp(0.0, 1.0));
    _glyph(canvas, Icons.location_on_rounded,
        centre.translate(0, -26 + 26 * drop), 40, _accent);
  }

  void _rotatePhone(Canvas canvas, Rect phone, Offset centre) {
    final angle = sin(t * 2 * pi) * 0.5;
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(angle);
    canvas.translate(-centre.dx, -centre.dy);
    _phoneBody(canvas, phone, screen: AppColors.primarySoft);
    canvas.restore();

    // A curved arrow showing which way to turn it.
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: phone.width * 0.92),
      -pi * 0.9,
      pi * 0.8,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = _accent.withValues(alpha: 0.75),
    );
  }

  /// A battery being read: the fill sweeps up and settles, with a pulse
  /// running across it like a meter taking a measurement.
  void _batteryHealth(Canvas canvas, Size size) {
    final shell = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.height * 0.92,
      height: size.height * 0.52,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(shell, const Radius.circular(9)),
      _stroke,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(shell.right + 2, shell.center.dy - 9, 6, 18),
        const Radius.circular(2),
      ),
      Paint()..color = _outline,
    );

    // Fills, holds, then reads out — the shape of taking a measurement
    // rather than of a battery charging.
    final settle = Curves.easeOutCubic.transform((t * 1.8).clamp(0.0, 1.0));
    final level = 0.12 + settle * 0.68;
    final tone = Color.lerp(AppColors.warning, AppColors.success, level)!;

    final inner = shell.deflate(5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(inner.left, inner.top, inner.width * level, inner.height),
        const Radius.circular(5),
      ),
      Paint()..color = tone,
    );

    // The scanning line.
    final sweep = inner.left + inner.width * ((t * 1.6) % 1);
    canvas.drawLine(
      Offset(sweep, inner.top - 3),
      Offset(sweep, inner.bottom + 3),
      Paint()
        ..strokeWidth = 2
        ..color = _accent.withValues(alpha: 0.55),
    );
  }

  /// Cores under load: four bars climbing, then sagging as it gets hot.
  void _cpuLoad(Canvas canvas, Size size) {
    final chip = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.height * 0.62,
      height: size.height * 0.62,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(chip, const Radius.circular(8)),
      _stroke,
    );

    // Pins down each side.
    for (var i = 0; i < 4; i++) {
      final y = chip.top + chip.height * (0.22 + i * 0.19);
      for (final x in [chip.left - 7, chip.right + 7]) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x < chip.left ? chip.left : chip.right, y),
          _stroke..strokeWidth = 2,
        );
      }
    }
    _stroke.strokeWidth = 2.4;

    // Four cores, each climbing then throttling back at its own moment.
    final inner = chip.deflate(9);
    for (var core = 0; core < 4; core++) {
      final phase = (t * 1.4 + core * 0.13) % 1;
      final climb = Curves.easeOut.transform((phase * 2.4).clamp(0.0, 1.0));
      final droop = Curves.easeInOut.transform(
        ((phase - 0.45) / 0.55).clamp(0.0, 1.0),
      );
      final height = inner.height * (0.18 + climb * 0.8 - droop * 0.45);

      final x = inner.left + inner.width * (0.16 + core * 0.23);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, inner.bottom - height, inner.width * 0.13, height),
          const Radius.circular(2),
        ),
        Paint()..color = Color.lerp(AppColors.success, AppColors.error, droop)!,
      );
    }
  }

  @override
  bool shouldRepaint(_DemoPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.kind != kind;
}
