import 'package:flutter/material.dart';

import 'app_motion.dart';

/// How a pushed screen should arrive.
enum AppTransition {
  /// Slides in from the trailing edge while the old screen eases back.
  /// The default for moving forward through a flow.
  sharedAxis,

  /// Cross-fades with a slight scale. For lateral moves where neither screen
  /// is "deeper" than the other.
  fadeThrough,

  /// Rises from the bottom. For detail views and anything sheet-like.
  rise,
}

/// A [PageRoute] with the app's transitions.
///
/// Prefer this over a bare [MaterialPageRoute] so a push reads as a direction
/// rather than a cut. Respects reduced-motion by falling back to no
/// transition at all.
class AppPageRoute<T> extends PageRouteBuilder<T> {
  AppPageRoute({
    required this.builder,
    this.transition = AppTransition.sharedAxis,
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: AppMotion.slow,
          reverseTransitionDuration: AppMotion.normal,
          transitionsBuilder: (context, animation, secondary, child) {
            if (AppMotion.reduced(context)) return child;

            switch (transition) {
              case AppTransition.sharedAxis:
                return _sharedAxis(animation, secondary, child);
              case AppTransition.fadeThrough:
                return _fadeThrough(animation, child);
              case AppTransition.rise:
                return _rise(animation, child);
            }
          },
        );

  final WidgetBuilder builder;
  final AppTransition transition;

  static Widget _sharedAxis(
    Animation<double> animation,
    Animation<double> secondary,
    Widget child,
  ) {
    final incoming = CurvedAnimation(parent: animation, curve: AppMotion.enter);
    // The outgoing screen drifts back a little so the two read as a stack
    // rather than a swap.
    final outgoing =
        CurvedAnimation(parent: secondary, curve: AppMotion.standard);

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.06, 0),
        end: Offset.zero,
      ).animate(incoming),
      child: FadeTransition(
        opacity: incoming,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset.zero,
            end: const Offset(-0.04, 0),
          ).animate(outgoing),
          child: child,
        ),
      ),
    );
  }

  static Widget _fadeThrough(Animation<double> animation, Widget child) {
    final curved = CurvedAnimation(parent: animation, curve: AppMotion.enter);
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
        child: child,
      ),
    );
  }

  static Widget _rise(Animation<double> animation, Widget child) {
    final curved = CurvedAnimation(parent: animation, curve: AppMotion.enter);
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.04),
        end: Offset.zero,
      ).animate(curved),
      child: FadeTransition(opacity: curved, child: child),
    );
  }
}

/// Convenience wrappers so call sites read as plain navigation.
extension AppNavigation on BuildContext {
  Future<T?> pushScreen<T>(
    Widget page, {
    AppTransition transition = AppTransition.sharedAxis,
  }) {
    // Leaving a screen dismisses its keyboard.
    //
    // A focused field keeps its focus while the page sits under a pushed
    // route, so coming back re-opens the keyboard over a page the user was
    // only returning to look at. Tapping search, opening a phone and pressing
    // back used to land on the list with the keyboard already up.
    //
    // Done here rather than at each call site because it is true of every
    // push, and a new one should not have to remember.
    FocusManager.instance.primaryFocus?.unfocus();

    return Navigator.of(this).push<T>(
      AppPageRoute<T>(builder: (_) => page, transition: transition),
    );
  }
}
