import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// A search field that pins itself to the top of a scroll view.
///
/// Wrap in `SliverPersistentHeader(pinned: true, delegate: ...)`.
///
/// The child is pinned to an exact height rather than being left to size
/// itself, and this is the whole reason the class exists. A pinned header
/// takes its paintExtent from the child's real height but its layoutExtent
/// from [maxExtent], and Flutter asserts if the two disagree by even a pixel.
/// That assertion fires during the viewport's layout pass, which renders the
/// screen blank rather than red — it does not fail `flutter analyze`, it does
/// not fail `flutter build`, and it once shipped a white screen on the sell
/// page for exactly this reason.
class AppStickySearchHeader extends SliverPersistentHeaderDelegate {
  const AppStickySearchHeader({required this.child});

  final Widget child;

  /// The height the field is *forced* to, which is not the height it would
  /// choose: AppSearchField lays out at 47. The SizedBox below is what makes
  /// the two agree, and is the whole safety mechanism here — remove it and
  /// the header claims 76 while painting 75, which is the blank screen.
  static const double fieldHeight = 48;

  /// Identifies the header box so its rendered height can be measured
  /// against [maxExtent]. That equality is the invariant a pinned header
  /// asserts on, and nothing else in the toolchain checks it.
  @visibleForTesting
  static const Key boxKey = ValueKey('sticky-search-header');
  static const double _verticalPadding = AppSpacing.lg + AppSpacing.md;

  /// What the header occupies, pinned or not.
  static const double height = fieldHeight + _verticalPadding;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      key: boxKey,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.lg,
        AppSpacing.screenGutter,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        // The rule appears only once content has scrolled beneath, so the
        // header is a plain part of the page until it is actually floating
        // over something.
        border: Border(
          bottom: BorderSide(
            color: overlapsContent ? AppColors.border : AppColors.transparent,
          ),
        ),
      ),
      child: SizedBox(height: fieldHeight, child: child),
    );
  }

  @override
  bool shouldRebuild(covariant AppStickySearchHeader oldDelegate) =>
      oldDelegate.child != child;
}
