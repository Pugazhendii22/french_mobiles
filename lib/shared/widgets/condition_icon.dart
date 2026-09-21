import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Which checklist step an option belongs to.
///
/// Passed in rather than guessed, because the wording alone is ambiguous:
/// "Visible Scratches/Scuffs" appears under both the screen and the body, and
/// they want quite different pictures.
enum ConditionCategory { screen, body, battery, accessories, lock }

/// The drawing to use for one option.
enum ConditionArt {
  screenPristine,
  screenLightScratches,
  screenScratches,
  screenCracked,
  screenCrackedDead,
  screenDiscoloured,
  bodyPristine,
  bodyMicroScratches,
  bodyScratches,
  bodyDents,
  bodyBent,
  batteryFull,
  batteryGood,
  batteryFair,
  batteryPoor,
  batteryDead,
  boxAndCharger,
  noBox,
  noCharger,
  noBoxNoCharger,
  unlocked,
  carrierLocked,
  accountLocked,
  unknown;

  /// Picks the drawing for [label] within [category].
  ///
  /// Matched on keywords rather than exact strings: these labels live in
  /// Firestore and are meant to be editable, so "Cracked (Touch Working)"
  /// becoming "Screen cracked" should not silently drop back to a generic
  /// phone. Anything unrecognised falls through to [unknown], which draws a
  /// plain handset — wrong-looking is worse than neutral.
  static ConditionArt resolve(ConditionCategory category, String label) {
    final text = label.toLowerCase();
    bool has(String word) => text.contains(word);

    // Checked before anything else, because the best options are worded as
    // the *absence* of a fault and so contain the fault's own keywords:
    // "Perfect / No Visible Marks" matched "mark" and drew a scratched
    // screen, which is the one thing it is telling you it does not have.
    final pristine = has('perfect') ||
        has('flawless') ||
        has('like new') ||
        has('no visible') ||
        has('no marks') ||
        has('no mark');

    switch (category) {
      case ConditionCategory.screen:
        if (pristine) return screenPristine;
        if (has('crack') && (has('dead') || has('pixel'))) {
          return screenCrackedDead;
        }
        if (has('crack') || has('broken')) return screenCracked;
        if (has('discolor') || has('discolour') || has('tint')) {
          return screenDiscoloured;
        }
        if (has('light') || has('micro') || has('minor')) {
          return screenLightScratches;
        }
        if (has('scratch') || has('mark') || has('scuff')) {
          return screenScratches;
        }
        return screenPristine;

      case ConditionCategory.body:
        if (pristine) return bodyPristine;
        if (has('bent') || has('chassis')) return bodyBent;
        if (has('dent')) return bodyDents;
        if (has('micro') || has('minor')) return bodyMicroScratches;
        if (has('scratch') || has('scuff')) return bodyScratches;
        return bodyPristine;

      case ConditionCategory.battery:
        if (has('swollen') || has('not charging') || has('dead')) {
          return batteryDead;
        }
        // The labels lead with a range — "70-79% Battery Health" — so the
        // first number in the string is the level being described.
        final first = RegExp(r'\d+').firstMatch(text);
        final level = first == null ? null : int.tryParse(first.group(0)!);
        if (has('below') || (level != null && level < 70)) return batteryPoor;
        if (level == null) return batteryGood;
        if (level >= 95) return batteryFull;
        if (level >= 90) return batteryGood;
        if (level >= 70) return batteryFair;
        return batteryPoor;

      case ConditionCategory.accessories:
        final missingBox = has('box') && (has('missing') || has('no '));
        final missingCharger =
            (has('charger') || has('cable')) && (has('missing') || has('no '));
        if (missingBox && missingCharger) return noBoxNoCharger;
        if (missingCharger) return noCharger;
        if (missingBox) return noBox;
        return boxAndCharger;

      case ConditionCategory.lock:
        if (has('icloud') || has('frp') || has('google')) return accountLocked;
        if (has('carrier') || has('network lock')) return carrierLocked;
        return unlocked;
    }
  }
}

/// A drawn illustration of a condition option.
///
/// Drawn rather than fetched. Every option in `deduction_rules` carries an
/// `icon_url`, and every one of them is empty — so all twenty-odd choices
/// rendered the same grey handset, which told a seller nothing about the
/// difference between "light scratches" and "cracked". These are built from
/// the same primitives as the checkup animations: no assets, no network, and
/// they cannot 404 half way through a sale.
class ConditionIcon extends StatelessWidget {
  const ConditionIcon({
    super.key,
    required this.category,
    required this.label,
    this.selected = false,
    this.size = 46,
  });

  final ConditionCategory category;
  final String label;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ConditionPainter(
          art: ConditionArt.resolve(category, label),
          selected: selected,
        ),
      ),
    );
  }
}

class _ConditionPainter extends CustomPainter {
  _ConditionPainter({required this.art, required this.selected});

  final ConditionArt art;
  final bool selected;

  /// Everything is laid out in a 100×100 box and scaled, so proportions hold
  /// at any size.
  static const double _design = 100;

  late final Color _ink =
      selected ? AppColors.onPrimarySoft : AppColors.textSecondary;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _design);

    switch (art) {
      case ConditionArt.screenPristine:
        _phone(canvas, screen: AppColors.primarySoft);
        _sparkle(canvas, const Offset(64, 34));
      case ConditionArt.screenLightScratches:
        _phone(canvas);
        _scratches(canvas, 2, faint: true);
      case ConditionArt.screenScratches:
        _phone(canvas);
        _scratches(canvas, 4);
      case ConditionArt.screenCracked:
        _phone(canvas);
        _crack(canvas);
      case ConditionArt.screenCrackedDead:
        _phone(canvas);
        _deadPixels(canvas);
        _crack(canvas);
      case ConditionArt.screenDiscoloured:
        _phone(canvas);
        _discolouration(canvas);

      case ConditionArt.bodyPristine:
        _phone(canvas, back: true);
        _sparkle(canvas, const Offset(64, 34));
      case ConditionArt.bodyMicroScratches:
        _phone(canvas, back: true);
        _scratches(canvas, 3, faint: true, short: true);
      case ConditionArt.bodyScratches:
        _phone(canvas, back: true);
        _scratches(canvas, 4);
      case ConditionArt.bodyDents:
        _phone(canvas, back: true);
        _dents(canvas);
      case ConditionArt.bodyBent:
        _bentPhone(canvas);

      case ConditionArt.batteryFull:
        _battery(canvas, 1.0, AppColors.success);
      case ConditionArt.batteryGood:
        _battery(canvas, 0.75, AppColors.success);
      case ConditionArt.batteryFair:
        _battery(canvas, 0.45, AppColors.warning);
      case ConditionArt.batteryPoor:
        _battery(canvas, 0.18, AppColors.error);
      case ConditionArt.batteryDead:
        _swollenBattery(canvas);

      case ConditionArt.boxAndCharger:
        _box(canvas, const Offset(36, 52), present: true);
        _cable(canvas, present: true);
      case ConditionArt.noBox:
        _box(canvas, const Offset(36, 52), present: false);
        _cable(canvas, present: true);
      case ConditionArt.noCharger:
        _box(canvas, const Offset(36, 52), present: true);
        _cable(canvas, present: false);
      case ConditionArt.noBoxNoCharger:
        _box(canvas, const Offset(36, 52), present: false);
        _cable(canvas, present: false);

      case ConditionArt.unlocked:
        _lock(canvas, open: true, tone: AppColors.success);
      case ConditionArt.carrierLocked:
        _lock(canvas, open: false, tone: AppColors.warning);
        _signalBars(canvas);
      case ConditionArt.accountLocked:
        _lock(canvas, open: false, tone: AppColors.error);
        _cloud(canvas);

      case ConditionArt.unknown:
        _phone(canvas);
    }

    canvas.restore();
  }

  // --- primitives ----------------------------------------------------------

  Paint get _line => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = _ink;

  static const Rect _bodyRect = Rect.fromLTWH(30, 12, 40, 76);

  void _phone(Canvas canvas, {Color? screen, bool back = false}) {
    final body = RRect.fromRectAndRadius(_bodyRect, const Radius.circular(9));
    if (screen != null) canvas.drawRRect(body, Paint()..color = screen);
    canvas.drawRRect(body, _line);

    if (back) {
      // A camera bump, so the back of the phone is not the front of it.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(37, 19, 17, 17),
          const Radius.circular(5),
        ),
        _line..strokeWidth = 3,
      );
      _line.strokeWidth = 4;
    }
  }

  void _bentPhone(Canvas canvas) {
    // Bowed, not merely tilted. A skewed rectangle just reads as a phone at
    // an angle; curving both long edges the same way is the only version
    // that says the chassis itself is deformed.
    final path = Path()
      ..moveTo(38, 14)
      ..lineTo(66, 18)
      ..cubicTo(56, 40, 56, 62, 62, 86)
      ..lineTo(34, 82)
      ..cubicTo(28, 58, 28, 36, 38, 14)
      ..close();
    canvas.drawPath(path, _line);

    // A crease at the point of the bend.
    canvas.drawLine(
      const Offset(31, 50),
      const Offset(59, 50),
      Paint()
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = _ink.withValues(alpha: 0.45),
    );
  }

  void _scratches(Canvas canvas, int count,
      {bool faint = false, bool short = false}) {
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = faint ? 1.6 : 2.4
      ..strokeCap = StrokeCap.round
      ..color = _ink.withValues(alpha: faint ? 0.45 : 0.85);

    final random = Random(count * 7);
    for (var i = 0; i < count; i++) {
      final y = 26.0 + i * (52 / max(count - 1, 1));
      final x = 37.0 + random.nextInt(8);
      final length = short ? 10.0 : 18.0 + random.nextInt(8);
      canvas.drawLine(Offset(x, y), Offset(x + length, y - 5), pen);
    }
  }

  void _crack(Canvas canvas) {
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = _ink;

    // An impact point with splinters running off it, which is what a dropped
    // screen actually looks like.
    const origin = Offset(52, 44);
    for (final end in const [
      Offset(34, 26),
      Offset(68, 30),
      Offset(36, 62),
      Offset(66, 70),
      Offset(52, 84),
    ]) {
      final mid = Offset(
        (origin.dx + end.dx) / 2 + 4,
        (origin.dy + end.dy) / 2 - 3,
      );
      canvas.drawPath(
        Path()
          ..moveTo(origin.dx, origin.dy)
          ..lineTo(mid.dx, mid.dy)
          ..lineTo(end.dx, end.dy),
        pen,
      );
    }
  }

  void _deadPixels(Canvas canvas) {
    final ink = Paint()..color = _ink.withValues(alpha: 0.55);
    for (final spot in const [
      Rect.fromLTWH(35, 20, 13, 16),
      Rect.fromLTWH(54, 58, 12, 20),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(spot, const Radius.circular(3)),
        ink,
      );
    }
  }

  void _discolouration(Canvas canvas) {
    // A stain creeping in from the edge, fading inward.
    canvas.drawRect(
      const Rect.fromLTWH(31, 13, 38, 74),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x66F59E0B), Color(0x00F59E0B)],
        ).createShader(const Rect.fromLTWH(31, 13, 24, 74)),
    );
  }

  void _dents(Canvas canvas) {
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = _ink;
    // Bites taken out of the edge.
    canvas.drawArc(
        const Rect.fromLTWH(24, 30, 14, 14), -pi / 2, pi, false, pen);
    canvas.drawArc(const Rect.fromLTWH(62, 56, 14, 14), pi / 2, pi, false, pen);
  }

  /// A four-point shine, for the options that mean "nothing wrong with it".
  ///
  /// Drawn with concave sides rather than as a cross — a plain plus sign in
  /// the corner of a phone reads as "add", which is the wrong verb entirely.
  void _sparkle(Canvas canvas, Offset at) {
    const long = 11.0;
    const waist = 3.0;
    final path = Path()
      ..moveTo(at.dx, at.dy - long)
      ..quadraticBezierTo(at.dx + waist, at.dy - waist, at.dx + long, at.dy)
      ..quadraticBezierTo(at.dx + waist, at.dy + waist, at.dx, at.dy + long)
      ..quadraticBezierTo(at.dx - waist, at.dy + waist, at.dx - long, at.dy)
      ..quadraticBezierTo(at.dx - waist, at.dy - waist, at.dx, at.dy - long)
      ..close();
    canvas.drawPath(path, Paint()..color = AppColors.success);
  }

  void _battery(Canvas canvas, double level, Color tone) {
    const shell = Rect.fromLTWH(22, 32, 52, 36);
    canvas.drawRRect(
      RRect.fromRectAndRadius(shell, const Radius.circular(7)),
      _line,
    );
    // The terminal.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(74, 43, 6, 14),
        const Radius.circular(2),
      ),
      Paint()..color = _ink,
    );

    final fillWidth = (shell.width - 10) * level.clamp(0.06, 1.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
            shell.left + 5, shell.top + 5, fillWidth, shell.height - 10),
        const Radius.circular(3),
      ),
      Paint()..color = tone,
    );
  }

  void _swollenBattery(Canvas canvas) {
    // The same battery as the healthy ones, but with its long sides bowed
    // out. Keeping the terminal and the proportions is what makes it read as
    // a *battery* that has gone wrong, rather than as an unrelated red blob.
    final path = Path()
      ..moveTo(26, 34)
      ..lineTo(66, 34)
      ..quadraticBezierTo(76, 50, 66, 66)
      ..lineTo(26, 66)
      ..quadraticBezierTo(14, 50, 26, 34)
      ..close();

    canvas.drawPath(
        path, Paint()..color = AppColors.error.withValues(alpha: 0.16));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.error,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(72, 43, 6, 14),
        const Radius.circular(2),
      ),
      Paint()..color = AppColors.error,
    );

    // A bolt through it: not charging, as well as swollen.
    canvas.drawPath(
      Path()
        ..moveTo(48, 39)
        ..lineTo(38, 52)
        ..lineTo(46, 52)
        ..lineTo(42, 62)
        ..lineTo(54, 48)
        ..lineTo(46, 48)
        ..close(),
      Paint()..color = AppColors.error,
    );
  }

  void _box(Canvas canvas, Offset centre, {required bool present}) {
    final rect = Rect.fromCenter(center: centre, width: 40, height: 32);
    final pen = present
        ? _line
        : (Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = _ink.withValues(alpha: 0.3));

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      pen,
    );
    // The lid seam, so it reads as a box and not a card.
    canvas.drawLine(
      Offset(rect.left, rect.top + 10),
      Offset(rect.right, rect.top + 10),
      pen,
    );
    if (!present) _strikeThrough(canvas, rect);
  }

  void _cable(Canvas canvas, {required bool present}) {
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = present ? 3.5 : 3
      ..strokeCap = StrokeCap.round
      ..color = present ? _ink : _ink.withValues(alpha: 0.3);

    final path = Path()
      ..moveTo(60, 84)
      ..cubicTo(80, 80, 62, 62, 78, 56);
    canvas.drawPath(path, pen);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(54, 78, 12, 9),
        const Radius.circular(2),
      ),
      pen..style = PaintingStyle.fill,
    );

    if (!present) {
      _strikeThrough(canvas, const Rect.fromLTWH(52, 54, 32, 34));
    }
  }

  void _strikeThrough(Canvas canvas, Rect rect) {
    canvas.drawLine(
      rect.topLeft.translate(-3, -3),
      rect.bottomRight.translate(3, 3),
      Paint()
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..color = AppColors.error,
    );
  }

  void _lock(Canvas canvas, {required bool open, required Color tone}) {
    const bodyRect = Rect.fromLTWH(34, 46, 32, 28);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, const Radius.circular(5)),
      Paint()..color = tone,
    );

    final shackle = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..color = tone;

    if (open) {
      // Hinged back and to the side, the way an opened padlock hangs.
      canvas.drawArc(
          const Rect.fromLTWH(44, 28, 24, 24), pi, pi * 1.1, false, shackle);
    } else {
      canvas.drawArc(
          const Rect.fromLTWH(38, 30, 24, 24), pi, pi, false, shackle);
      canvas.drawLine(const Offset(38, 42), const Offset(38, 48), shackle);
      canvas.drawLine(const Offset(62, 42), const Offset(62, 48), shackle);
    }
  }

  void _signalBars(Canvas canvas) {
    for (var i = 0; i < 3; i++) {
      final height = 7.0 + i * 6;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(66 + i * 9.0, 34 - height, 6, height),
          const Radius.circular(2),
        ),
        Paint()..color = _ink.withValues(alpha: 0.75),
      );
    }
  }

  void _cloud(Canvas canvas) {
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = _ink.withValues(alpha: 0.75);

    final path = Path()
      ..moveTo(36, 34)
      ..quadraticBezierTo(30, 34, 30, 28)
      ..quadraticBezierTo(30, 21, 38, 22)
      ..quadraticBezierTo(41, 14, 50, 17)
      ..quadraticBezierTo(58, 15, 60, 23)
      ..quadraticBezierTo(68, 23, 67, 30)
      ..quadraticBezierTo(67, 34, 61, 34)
      ..close();
    canvas.drawPath(path, pen);
  }

  @override
  bool shouldRepaint(_ConditionPainter oldDelegate) =>
      oldDelegate.art != art || oldDelegate.selected != selected;
}
