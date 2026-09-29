import 'package:flutter/material.dart';

import '../motion/motion.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// How enclosed a piece of content is.
///
/// The app's surface rule, in one place: **a box has to be earned.** Before
/// this existed nearly every element was the same white card with a border and
/// a shadow, so a tappable product, a passive readout and a settings group all
/// looked identical and nothing had rank.
///
/// Pick the lowest level that still reads correctly.
enum AppSurfaceLevel {
  /// No enclosure at all — content sits directly on the page.
  ///
  /// The default, and by far the most common. Headings, body copy, summary
  /// rows and icon strips all belong here; spacing and type separate them.
  page,

  /// One bordered container holding related rows, with hairlines between them.
  ///
  /// For a *set* of things that belong together — a settings group, a payout
  /// breakdown, a spec table. One box around the group, never one per row.
  group,

  /// White, shadowed, no border.
  ///
  /// Reserved for discrete tappable items in a collection: a product card, a
  /// brand tile, an order. The lift is what signals "this is a thing you can
  /// pick", so using it on passive content spends the signal for nothing.
  raised,

  /// Tinted panel in the brand colour.
  ///
  /// At most one per screen. The primary action or the single most important
  /// message — a sell CTA, an order confirmation.
  accent,
}

/// A themed surface at a given [AppSurfaceLevel].
class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.level = AppSurfaceLevel.page,
    this.padding,
    this.onTap,
    this.borderRadius,
  });

  final Widget child;
  final AppSurfaceLevel level;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppRadius.card;

    Widget content = Padding(
      padding: padding ?? _defaultPadding,
      child: child,
    );

    if (level != AppSurfaceLevel.page) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          color: _background,
          borderRadius: radius,
          border: _border,
          boxShadow: _shadow,
        ),
        child: content,
      );
    }

    if (onTap == null) return content;
    return AppPressable(onTap: onTap, child: content);
  }

  EdgeInsetsGeometry get _defaultPadding {
    switch (level) {
      case AppSurfaceLevel.page:
        return EdgeInsets.zero;
      case AppSurfaceLevel.group:
      case AppSurfaceLevel.raised:
      case AppSurfaceLevel.accent:
        return const EdgeInsets.all(AppSpacing.lg);
    }
  }

  Color get _background {
    switch (level) {
      case AppSurfaceLevel.page:
        return AppColors.transparent;
      case AppSurfaceLevel.group:
      case AppSurfaceLevel.raised:
        return AppColors.surface;
      case AppSurfaceLevel.accent:
        return AppColors.primarySoft;
    }
  }

  BoxBorder? get _border {
    switch (level) {
      case AppSurfaceLevel.group:
        return Border.all(color: AppColors.border);
      // raised is separated by its shadow; adding a border as well is what
      // made everything read as the same flat box.
      case AppSurfaceLevel.page:
      case AppSurfaceLevel.raised:
      case AppSurfaceLevel.accent:
        return null;
    }
  }

  List<BoxShadow>? get _shadow {
    switch (level) {
      case AppSurfaceLevel.raised:
        return AppShadows.card;
      case AppSurfaceLevel.page:
      case AppSurfaceLevel.group:
      case AppSurfaceLevel.accent:
        return null;
    }
  }
}

/// A set of related rows under one enclosure, separated by hairlines.
///
/// Replaces the "one card per row" pattern. Set [bare] to drop the enclosure
/// entirely and keep only the rules — the right choice for a summary that sits
/// under its own heading and needs no box at all.
class AppGroup extends StatelessWidget {
  const AppGroup({
    super.key,
    required this.children,
    this.bare = false,
    this.inset = true,
  });

  final List<Widget> children;
  final bool bare;

  /// Whether the dividers are indented to clear a leading icon.
  final bool inset;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(Divider(
          height: 1,
          thickness: 1,
          indent: inset && !bare ? AppSpacing.lg : 0,
          endIndent: inset && !bare ? AppSpacing.lg : 0,
          color: AppColors.border,
        ));
      }
      rows.add(children[i]);
    }

    final column = Column(mainAxisSize: MainAxisSize.min, children: rows);

    if (bare) return column;

    return AppSurface(
      level: AppSurfaceLevel.group,
      padding: EdgeInsets.zero,
      child: column,
    );
  }
}
