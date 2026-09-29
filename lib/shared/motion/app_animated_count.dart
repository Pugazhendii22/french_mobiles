import 'package:flutter/material.dart';

import 'app_motion.dart';

/// Counts from the previous value to [value] whenever it changes.
///
/// Used for payouts and prices: watching the number move makes it obvious that
/// a selection changed the figure, which a silent swap does not.
class AppAnimatedCount extends StatelessWidget {
  const AppAnimatedCount({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.duration,
  });

  final int value;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduced(context)) {
      return Text('$prefix$value$suffix', style: style);
    }

    return TweenAnimationBuilder<double>(
      // begin only applies to the first build (counting up from zero). On
      // every later rebuild TweenAnimationBuilder animates from the current
      // value to the new end, which is what makes a changing figure move.
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: duration ?? AppMotion.slow,
      curve: AppMotion.standard,
      builder: (context, v, _) =>
          Text('$prefix${v.round()}$suffix', style: style),
    );
  }
}
