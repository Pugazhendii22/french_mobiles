import 'package:flutter/material.dart';

import 'app_motion.dart';

/// Fades and lifts a child into place, optionally staggered by [index].
///
/// The stagger is an [Interval] on one tween rather than a delayed start, so
/// no timer is created per item and nothing is left pending if the screen is
/// popped mid-animation.
class AppReveal extends StatelessWidget {
  const AppReveal({
    super.key,
    required this.child,
    this.index = 0,
    this.slots = 8,
    this.offset = AppMotion.revealOffset,
    this.direction = Axis.vertical,
  });

  final Widget child;

  /// Position in the sequence. Wraps at [slots] so a long list does not end up
  /// with items waiting seconds to appear.
  final int index;
  final int slots;
  final double offset;
  final Axis direction;

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduced(context)) return child;

    final slot = index % slots;
    final stepMs = AppMotion.stagger.inMilliseconds;
    final revealMs = AppMotion.normal.inMilliseconds;
    final totalMs = revealMs + stepMs * (slots - 1);

    final begin = (slot * stepMs) / totalMs;
    final end = (slot * stepMs + revealMs) / totalMs;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: totalMs),
      curve: Interval(begin, end, curve: AppMotion.enter),
      child: child,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: direction == Axis.vertical
                ? Offset(0, (1 - value) * offset)
                : Offset((1 - value) * offset, 0),
            child: child,
          ),
        );
      },
    );
  }
}
