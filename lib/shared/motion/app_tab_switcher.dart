import 'package:flutter/material.dart';

import 'app_motion.dart';

/// Cross-fades between tabs without rebuilding them.
///
/// Switching destinations used to be a cut: an IndexedStack changes which
/// child it paints and the new page is simply there, with nothing to say it
/// replaced the old one. That reads as a redraw rather than a movement.
///
/// Deliberately not an AnimatedSwitcher, which is the obvious reach: it
/// animates by building the new child and disposing the old, so every tab
/// would lose its scroll position and re-run its Firestore reads on the way
/// back. Here every visited tab stays in the tree and only what is painted
/// changes.
///
/// The shape is Material's fade-through — the outgoing tab fades out over the
/// first third while the incoming one fades in and grows the last fraction of
/// its size. Nothing slides, because a bottom bar's destinations are peers
/// with no left or right relationship to imply.
class AppTabSwitcher extends StatefulWidget {
  const AppTabSwitcher({
    super.key,
    required this.index,
    required this.children,
    this.duration = AppMotion.normal,
  });

  /// Which child is active.
  final int index;

  /// One per destination. Order is fixed; entries may be placeholders for
  /// tabs that have not been opened yet.
  final List<Widget> children;

  final Duration duration;

  @override
  State<AppTabSwitcher> createState() => _AppTabSwitcherState();
}

class _AppTabSwitcherState extends State<AppTabSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1,
  );

  /// The tab being faded out, or null when nothing is in flight.
  int? _outgoing;

  @override
  void didUpdateWidget(AppTabSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index == oldWidget.index) return;

    _outgoing = oldWidget.index;
    _controller
      ..duration = AppMotion.duration(context, widget.duration)
      ..forward(from: 0);
  }

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
        final settled = _controller.isCompleted;
        final outgoing = settled ? null : _outgoing;

        return Stack(
          children: [
            for (var i = 0; i < widget.children.length; i++)
              _slot(
                index: i,
                child: widget.children[i],
                isCurrent: i == widget.index,
                isOutgoing: i == outgoing,
              ),
          ],
        );
      },
    );
  }

  Widget _slot({
    required int index,
    required Widget child,
    required bool isCurrent,
    required bool isOutgoing,
  }) {
    final t = _controller.value;
    final painting = isCurrent || isOutgoing;

    // Outgoing clears the way early, so the two are not both at full
    // strength in the middle of the swap.
    final opacity = isCurrent
        ? Curves.easeOut.transform((t.clamp(0.3, 1.0) - 0.3) / 0.7)
        : 1 - Curves.easeIn.transform(t.clamp(0.0, 0.3) / 0.3);

    // A small grow, so the tab reads as arriving rather than appearing.
    final scale = isCurrent && t < 1 ? 0.96 + 0.04 * t : 1.0;

    // Every branch builds the same chain of widget types, varying only their
    // parameters. Swapping the *shape* of the tree — an Offstage in one state
    // and an IgnorePointer in another — makes Flutter treat the subtree as a
    // different widget and rebuild it, which throws away the tab's state and
    // re-runs its reads. That is the whole thing this widget exists to avoid,
    // and it is easy to reintroduce here without noticing.
    return Offstage(
      offstage: !painting,
      child: TickerMode(
        enabled: isCurrent,
        child: IgnorePointer(
          ignoring: !isCurrent,
          child: Opacity(
            opacity: painting ? opacity.clamp(0.0, 1.0) : 1,
            child: Transform.scale(scale: scale, child: child),
          ),
        ),
      ),
    );
  }
}
