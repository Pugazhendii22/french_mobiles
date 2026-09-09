import 'package:flutter/material.dart';

/// Shared AppBar back control — plain chevron, no circle border.
class AppBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color iconColor;

  const AppBackButton({
    super.key,
    this.onPressed,
    this.iconColor = const Color(0xFF1E293B),
  });

  /// White / light surfaces.
  const AppBackButton.light({
    super.key,
    this.onPressed,
  }) : iconColor = const Color(0xFF1E293B);

  /// Colored / dark app bars.
  const AppBackButton.dark({
    super.key,
    this.onPressed,
  }) : iconColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      tooltip: 'Back',
      onPressed: onPressed ??
          () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
      icon: CustomPaint(
        size: const Size(10, 16),
        painter: _BackChevronPainter(color: iconColor),
      ),
    );
  }
}

/// Chevron drawn from the center of its canvas for true visual centering.
class _BackChevronPainter extends CustomPainter {
  final Color color;

  _BackChevronPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(size.width * 0.72, size.height * 0.12)
      ..lineTo(size.width * 0.28, size.height * 0.5)
      ..lineTo(size.width * 0.72, size.height * 0.88);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BackChevronPainter oldDelegate) =>
      oldDelegate.color != color;
}
