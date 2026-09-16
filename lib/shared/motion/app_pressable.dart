import 'package:flutter/material.dart';

import 'app_motion.dart';

/// Scales its child down slightly while held.
///
/// Gives cards and tiles the same tactile confirmation a button gets from its
/// ink ripple, which is easy to miss on a large surface.
class AppPressable extends StatefulWidget {
  const AppPressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  bool _held = false;

  void _set(bool held) {
    if (widget.onTap == null || AppMotion.reduced(context)) return;
    if (_held != held) setState(() => _held = held);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: _held ? widget.scale : 1,
        duration: AppMotion.duration(context, AppMotion.fast),
        curve: AppMotion.standard,
        child: widget.child,
      ),
    );
  }
}
