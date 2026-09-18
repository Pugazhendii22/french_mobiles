import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// A shimmering placeholder block for loading states.
///
/// Preferred over a bare spinner for content that has a known shape: showing
/// the skeleton of the card that is about to appear makes the wait read as
/// shorter and stops the layout jumping when data lands.
class AppShimmer extends StatefulWidget {
  const AppShimmer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  final double width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // Sweep a soft highlight from left to right across the block.
        final t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? AppRadius.card,
            gradient: LinearGradient(
              begin: Alignment(-1 - 2 * (1 - t), 0),
              end: Alignment(1 - 2 * (1 - t), 0),
              colors: const [
                AppColors.surfaceMuted,
                AppColors.border,
                AppColors.surfaceMuted,
              ],
              stops: const [0.1, 0.5, 0.9],
            ),
          ),
        );
      },
    );
  }
}

/// Swaps a skeleton for real content, holding the skeleton on screen for a
/// minimum time once it has been shown.
///
/// The minimum cannot live inside [AppShimmer] itself: a shimmer block is a
/// leaf and has no idea when loading finished. This is the piece that knows,
/// so this is where the floor belongs.
///
/// Why a floor at all: on a fast connection a cached Firestore read lands in
/// well under a tenth of a second, and a skeleton that appears and vanishes
/// inside 80ms reads as a glitch rather than a load. Holding it briefly makes
/// the same wait look deliberate. The floor only ever applies once the
/// skeleton has actually been shown, so content that was never loading is
/// never delayed.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    required this.loading,
    required this.skeleton,
    required this.child,
    this.minimum = defaultMinimum,
  });

  /// Long enough to register as a load, short enough not to feel held back.
  static const Duration defaultMinimum = Duration(milliseconds: 300);

  final bool loading;
  final Widget skeleton;
  final Widget child;
  final Duration minimum;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton> {
  late bool _showSkeleton = widget.loading;

  /// Whether the skeleton has been up long enough to swap.
  ///
  /// Tracked with a timer rather than by comparing wall-clock times: a timer
  /// obeys whatever clock is driving the app, which is what makes the floor
  /// behave predictably — and testable — instead of depending on how long
  /// real seconds happened to take.
  late bool _floorPassed = !widget.loading;
  bool _swapWhenFloorPasses = false;
  Timer? _floorTimer;

  @override
  void initState() {
    super.initState();
    if (widget.loading) _startFloor();
  }

  void _startFloor() {
    _floorPassed = false;
    _swapWhenFloorPasses = false;
    _floorTimer?.cancel();
    _floorTimer = Timer(widget.minimum, () {
      _floorPassed = true;
      if (_swapWhenFloorPasses && mounted) {
        setState(() => _showSkeleton = false);
      }
    });
  }

  @override
  void didUpdateWidget(AppSkeleton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loading == oldWidget.loading) return;

    if (widget.loading) {
      setState(() => _showSkeleton = true);
      _startFloor();
      return;
    }

    if (_floorPassed) {
      setState(() => _showSkeleton = false);
    } else {
      // Finished too quickly to be seen; the timer performs the swap.
      _swapWhenFloorPasses = true;
    }
  }

  @override
  void dispose() {
    _floorTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _showSkeleton ? widget.skeleton : widget.child;
}
