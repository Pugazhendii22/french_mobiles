import 'package:flutter/material.dart';

/// Motion tokens: the single source of truth for how long things take and how
/// they ease.
///
/// Durations are deliberately short. This is a transactional app — someone is
/// selling a phone, not watching a showreel — so motion is there to explain
/// where things came from, never to make them wait.
class AppMotion {
  AppMotion._();

  /// Micro-interactions: press, toggle, ripple.
  static const Duration fast = Duration(milliseconds: 150);

  /// The default for entrances, expansions and state changes.
  static const Duration normal = Duration(milliseconds: 260);

  /// Page transitions and larger reveals.
  static const Duration slow = Duration(milliseconds: 360);

  /// Gap between items in a staggered sequence.
  static const Duration stagger = Duration(milliseconds: 45);

  /// How far a revealing element travels before settling.
  static const double revealOffset = 14;

  /// Decelerating: things entering the screen.
  static const Curve enter = Curves.easeOutCubic;

  /// Accelerating: things leaving.
  static const Curve exit = Curves.easeInCubic;

  /// Symmetric: things already on screen changing.
  static const Curve standard = Curves.easeInOut;

  /// A small overshoot for confirmations. Used sparingly.
  static const Curve emphasis = Curves.easeOutBack;

  /// True when the platform asks for reduced motion, or when running under a
  /// test that disables animations.
  ///
  /// Every animated widget in `shared/` checks this and renders its settled
  /// state instead. Honouring it is an accessibility requirement — vestibular
  /// disorders make large motion genuinely unpleasant — and it keeps widget
  /// tests deterministic.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [duration], or zero when motion is reduced.
  static Duration duration(BuildContext context, Duration d) =>
      reduced(context) ? Duration.zero : d;
}
