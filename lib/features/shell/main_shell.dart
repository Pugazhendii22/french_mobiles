import 'package:flutter/material.dart';

import 'package:french_mobiles/features/home/data/home_repository.dart';
import 'package:french_mobiles/features/home/pages/home_page.dart';
import 'package:french_mobiles/features/home/widgets/home_bottom_nav.dart';
import 'package:french_mobiles/profile/orders_page.dart';
import 'package:french_mobiles/profile/profile_screen.dart';
import 'package:french_mobiles/profile/wishlist_page.dart';
import 'package:french_mobiles/screens/login_page.dart';
import 'package:french_mobiles/screens/sell_mobile_page.dart';
import 'package:french_mobiles/shared/motion/motion.dart';
import 'package:french_mobiles/shared/theme/app_colors.dart';
import 'package:french_mobiles/shared/theme/app_theme.dart';
import 'package:french_mobiles/shared/widgets/app_mascot.dart';

/// The app's root: the five main destinations, with the navigation bar under
/// all of them.
///
/// Before this, only Home carried the bar and every other destination was
/// pushed on top of it, so the bar vanished the moment you went anywhere. The
/// five now live side by side in one route; anything deeper — a brand, the
/// checkout, the checkup, the map picker — still pushes over the shell and
/// covers the bar, which is what a screen that owns the whole task should do.
class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    this.initialTab = HomeNavTab.home,
    this.pageBuilder,
    this.repository = const HomeRepository(),
    this.showMascot = true,
  });

  final HomeNavTab initialTab;

  /// Replaces the real page for a tab.
  ///
  /// Only for tests: every destination reads Firebase on its first frame, so
  /// the shell's own behaviour — which tab is shown, what is built, what
  /// survives a switch — cannot otherwise be exercised at all.
  @visibleForTesting
  final Widget Function(HomeNavTab tab)? pageBuilder;

  /// Only for tests: decides whether the Orders tab asks for sign-in.
  @visibleForTesting
  final HomeRepository repository;

  /// Only for tests: leaves the mascot out.
  ///
  /// It walks about under its own ticker and so never stops scheduling
  /// frames, which is the point of it and also means `pumpAndSettle` can
  /// never return while it is on screen. Tests about which tab is showing
  /// should not have to care, so they switch it off.
  @visibleForTesting
  final bool showMascot;

  /// A pending request to change tab, watched by the live shell.
  ///
  /// A notifier rather than an ancestor lookup because most callers are not
  /// inside the shell's subtree: a pushed route is a *sibling* of the shell
  /// under the Navigator, not a descendant, so walking up from the checkout
  /// finds nothing. Cleared by the shell once applied.
  @visibleForTesting
  static final ValueNotifier<HomeNavTab?> request =
      ValueNotifier<HomeNavTab?>(null);

  /// Switches the shell to [tab].
  ///
  /// Home's sell prompt, its "See all" link and its profile avatar are all
  /// requests to move to another destination, not to push a copy of it on
  /// top — pushing is what made the bar disappear in the first place.
  static void select(HomeNavTab tab) => request.value = tab;

  /// Switches the shell back to Home.
  ///
  /// Several screens finish by popping to the first route, which used to mean
  /// Home because Home *was* the first route. The shell is now, and it
  /// remembers its tab — so "Go to Home" would have landed on whichever tab
  /// the user started from. Call this alongside the pop.
  static void goHome() => select(HomeNavTab.home);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  HomeRepository get _repository => widget.repository;

  late HomeNavTab _current = widget.initialTab;

  /// Tabs that have been opened at least once.
  ///
  /// A plain IndexedStack builds every child immediately, which would open the
  /// Firestore streams behind Orders and Saved before the user has looked at
  /// either. Building on first visit and keeping it afterwards costs nothing
  /// for tabs that are never opened and still preserves scroll position for
  /// the ones that are.
  late final Set<HomeNavTab> _visited = {widget.initialTab};

  @override
  void initState() {
    super.initState();
    MainShell.request.addListener(_onRequest);
  }

  @override
  void dispose() {
    MainShell.request.removeListener(_onRequest);
    super.dispose();
  }

  /// Applies a programmatic tab change. Ungated: a screen asking to land on
  /// Home is not a tab press and must never raise a sign-in prompt.
  void _onRequest() {
    final tab = MainShell.request.value;
    if (tab == null) return;
    MainShell.request.value = null;
    _select(tab, gated: false);
  }

  Future<void> _onTap(HomeNavTab tab) => _select(tab, gated: true);

  Future<void> _select(HomeNavTab tab, {required bool gated}) async {
    if (!mounted) return;

    // Orders is the one destination with nothing to show a signed-out user,
    // so it asks for sign-in rather than opening on an empty list. The gate
    // is skipped for programmatic moves, which are never a tab press.
    if (gated && tab == HomeNavTab.orders && !_repository.isSignedIn) {
      await context.pushScreen(const LoginPage(),
          transition: AppTransition.rise);
      if (!mounted || !_repository.isSignedIn) return;
    }

    if (!mounted || tab == _current) return;

    // Same reasoning as pushScreen: the tab being left keeps its focus
    // otherwise, and returning to it re-opens the keyboard.
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _current = tab;
      _visited.add(tab);
    });
  }

  /// Home is the destination system back returns to, rather than leaving the
  /// app from a tab the user only glanced at.
  bool get _backExitsApp => _current == HomeNavTab.home;

  Widget _pageFor(HomeNavTab tab) {
    final override = widget.pageBuilder;
    if (override != null) return override(tab);

    switch (tab) {
      case HomeNavTab.home:
        return const HomePage();
      case HomeNavTab.sell:
        return const SellMobilePage();
      case HomeNavTab.orders:
        return const OrdersPage();
      case HomeNavTab.wishlist:
        return const WishlistPage();
      case HomeNavTab.profile:
        return const ProfilePage();
    }
  }

  @override
  Widget build(BuildContext context) {
    const tabs = HomeNavTab.values;

    return PopScope(
      canPop: _backExitsApp,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _select(HomeNavTab.home, gated: false);
      },
      child: Theme(
        data: AppTheme.light,
        child: Scaffold(
          backgroundColor: AppColors.background,
          // Cross-fades rather than cutting, while keeping every visited tab
          // in the tree — switching away and back must not reset a scroll
          // position or re-run a Firestore read.
          body: Stack(
            children: [
              AppTabSwitcher(
                index: tabs.indexOf(_current),
                children: [
                  for (final tab in tabs)
                    // An unvisited tab is an empty box rather than the real
                    // page, so nothing it would fetch happens until it is
                    // opened.
                    _visited.contains(tab)
                        ? _pageFor(tab)
                        : const SizedBox.shrink(),
                ],
              ),
              // Inside the shell, so it is covered the moment anything is
              // pushed over it. A mascot loose on top of the whole app would
              // sit over the checkup's own tests and be measured by them.
              if (widget.showMascot)
                const Positioned.fill(
                  child: SafeArea(child: AppMascot()),
                ),
            ],
          ),
          bottomNavigationBar: HomeBottomNav(
            current: _current,
            onTap: _onTap,
          ),
        ),
      ),
    );
  }
}
