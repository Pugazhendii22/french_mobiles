import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:french_mobiles/features/home/data/home_models.dart';
import 'package:french_mobiles/features/home/data/home_repository.dart';
import 'package:french_mobiles/features/home/widgets/home_bottom_nav.dart';
import 'package:french_mobiles/features/shell/main_shell.dart';
import 'package:french_mobiles/features/home/widgets/home_category_grid.dart';
import 'package:french_mobiles/features/home/widgets/home_header.dart';
import 'package:french_mobiles/features/home/widgets/home_location_strip.dart';
import 'package:french_mobiles/features/home/widgets/home_product_grid.dart';
import 'package:french_mobiles/features/home/widgets/home_sell_cta.dart';
import 'package:french_mobiles/features/home/widgets/home_trust_row.dart';
import 'package:french_mobiles/firebase/wishlist_service.dart';
import 'package:french_mobiles/profile/account_pages.dart';
import 'package:french_mobiles/screens/checkup/checkup_entry_page.dart';
import 'package:french_mobiles/screens/inventory_detail_page.dart';
import 'package:french_mobiles/screens/login_page.dart';
import 'package:french_mobiles/shared/motion/motion.dart';
import 'package:french_mobiles/shared/theme/app_colors.dart';
import 'package:french_mobiles/shared/theme/app_text_styles.dart';
import 'package:french_mobiles/shared/theme/app_theme.dart';
import 'package:french_mobiles/shared/widgets/app_search_field.dart';
import 'package:french_mobiles/shared/widgets/app_section_header.dart';
import 'package:french_mobiles/shared/widgets/app_sticky_header.dart';

/// The home screen.
///
/// Wraps itself in [AppTheme.light] rather than relying on `MaterialApp`, so
/// the new design system applies here while screens outside `features/home/`
/// keep the app's original inline theme. Once the other features adopt the
/// shared theme this wrapper can be deleted and the theme set on
/// `MaterialApp` instead.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final HomeRepository _repository = const HomeRepository();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  /// Marks the start of the product list, so focusing search can bring it
  /// into view without anyone hardcoding how tall the sections above are.
  final GlobalKey _productsKey = GlobalKey();

  String _selectedCategoryId = 'mobile';
  String _searchQuery = '';
  late Future<List<HomeProduct>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _productsFuture = _repository.loadProducts(_selectedCategoryId);
    _searchFocusNode.addListener(_onSearchFocusChanged);
  }

  @override
  void dispose() {
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Brings the product list up to meet the search field when it is tapped.
  ///
  /// Search filters that list and nothing else on the page, so typing while
  /// the categories and the sell prompt fill the screen means watching
  /// results you cannot see change. Scrolling puts the thing being filtered
  /// where the filtering happens.
  void _onSearchFocusChanged() {
    if (!_searchFocusNode.hasFocus) return;

    // After the frame, because the keyboard is still opening and the
    // viewport it leaves behind is the one to measure against.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToProducts());
  }

  /// Walks the list until the product section exists, then reveals it.
  ///
  /// The section starts below the fold, and a sliver below the fold has no
  /// render object at all — so asking for its position on the first frame
  /// gets nothing and the scroll silently does not happen. Each step builds
  /// the slivers it passes, so the key resolves within a couple of hops.
  Future<void> _scrollToProducts({int attempt = 0}) async {
    if (!mounted || !_scrollController.hasClients) return;

    // Bounded, so a layout that never realises the key cannot spin forever.
    if (attempt > 4) return;

    final position = _scrollController.position;
    final target = _productsKey.currentContext?.findRenderObject();

    if (target is! RenderBox) {
      final next = (position.pixels + position.viewportDimension * 0.9)
          .clamp(position.minScrollExtent, position.maxScrollExtent);
      // Already at the bottom and still not built: there is nothing to reach.
      if (next == position.pixels) return;

      await _scrollController.animateTo(
        next,
        duration: AppMotion.duration(context, AppMotion.fast),
        curve: AppMotion.enter,
      );
      return _scrollToProducts(attempt: attempt + 1);
    }

    await _scrollController.animateTo(
      AppStickySearchHeader.offsetToRevealBelow(target).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
      duration: AppMotion.duration(context, AppMotion.slow),
      curve: AppMotion.enter,
    );
  }

  void _reloadProducts() {
    setState(() {
      _productsFuture = _repository.loadProducts(_selectedCategoryId);
    });
  }

  void _onCategorySelected(String id) {
    if (id == _selectedCategoryId) return;
    setState(() {
      _selectedCategoryId = id;
      _productsFuture = _repository.loadProducts(id);
    });
  }

  Future<void> _onRefresh() async {
    final future = _repository.loadProducts(_selectedCategoryId);
    setState(() => _productsFuture = future);
    await future.catchError((_) => <HomeProduct>[]);
  }

  // --- Navigation --------------------------------------------------------

  Future<void> _openLogin() {
    return context.pushScreen(const LoginPage(),
        transition: AppTransition.rise);
  }

  Future<void> _openAddressPicker() async {
    final user = _repository.currentUser;
    if (user == null) {
      await _openLogin();
      return;
    }

    final result = await context.pushScreen<Map<String, dynamic>>(
      const SavedAddressesPage(selectMode: true),
      transition: AppTransition.rise,
    );

    if (result == null || !mounted) return;
    final docId = result['id'] as String?;
    if (docId == null) return;

    try {
      await _repository.setDefaultAddress(uid: user.uid, docId: docId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to set address: $e')),
      );
    }
  }

  void _openProduct(HomeProduct product) {
    if (product.documentId == null && product.firestoreData == null) return;

    context.pushScreen(
      InventoryDetailPlaceholder(
        documentId: product.documentId,
        data: product.firestoreData ??
            {
              'id': product.documentId,
              'brand': product.brand,
              'model': product.title,
              'salePrice': product.price,
            },
      ),
    );
  }

  Future<void> _toggleWishlist(HomeProduct product) async {
    if (_repository.currentUser == null) {
      await _openLogin();
      return;
    }

    try {
      await WishlistService.toggle(
        WishlistItem(
          productId: product.documentId ?? product.id,
          brand: product.brand,
          title: product.title,
          imageUrl: product.imageUrl,
          price: product.price,
          categoryId: product.categoryId,
          snapshot: product.firestoreData,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update wishlist')),
      );
    }
  }

  // --- Build -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.light,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: AppColors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: AppColors.surface,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            bottom: false,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusScope.of(context).unfocus(),
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                color: AppColors.primary,
                backgroundColor: AppColors.surface,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenGutter,
                        AppSpacing.lg,
                        AppSpacing.screenGutter,
                        0,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          AppReveal(
                            index: 0,
                            child: HomeHeader(
                            repository: _repository,
                              onProfileTap: () =>
                                  MainShell.select(HomeNavTab.profile),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppReveal(
                            index: 1,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: HomeLocationStrip(
                                repository: _repository,
                                uid: _repository.currentUser?.uid,
                                onTap: _openAddressPicker,
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ),
                    // Pinned, so search stays reachable once the greeting and
                    // the address strip have scrolled away. Its own padding
                    // replaces the gap that used to sit above it, which is
                    // why the list above ends here.
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: AppStickySearchHeader(
                        child: AppSearchField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          hintText: 'Search phones, brands…',
                          onChanged: (value) =>
                              setState(() => _searchQuery = value),
                          trailing: _searchQuery.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenGutter,
                        0,
                        AppSpacing.screenGutter,
                        0,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          AppReveal(
                            index: 3,
                            child:
                                Text('Browse by category', style: AppTextStyles.h3),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppReveal(
                            index: 4,
                            child: HomeCategoryGrid(
                              categories: homeCategories,
                              selectedId: _selectedCategoryId,
                              onSelected: _onCategorySelected,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          AppReveal(
                            index: 5,
                            child: HomeSellCta(
                            onSellTap: () => MainShell.select(HomeNavTab.sell),
                            onCheckupTap: () =>
                                  context.pushScreen(const CheckupEntryPage()),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          const AppReveal(index: 6, child: HomeTrustRow()),
                          const SizedBox(height: AppSpacing.xxl),
                        ]),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenGutter,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: AppSectionHeader(
                          key: _productsKey,
                          title: 'Available now',
                          subtitle: 'Certified pre-owned devices',
                          actionLabel: 'See all',
                          onActionTap: () => MainShell.select(HomeNavTab.sell),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.md),
                    ),
                    HomeProductGrid(
                        future: _productsFuture,
                        repository: _repository,
                        searchQuery: _searchQuery,
                        onProductTap: _openProduct,
                        onWishlistTap: _toggleWishlist,
                        wishlistStream: (id) =>
                            WishlistService.watchIsSaved(id),
                        onRetry: _reloadProducts,
                      emptyTitle: _emptyTitleForCategory,
                      emptyMessage: _emptyMessageForCategory,
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.xxl),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _emptyTitleForCategory {
    return _selectedCategoryId == 'mobile'
        ? 'No devices available'
        : 'Coming soon';
  }

  String? get _emptyMessageForCategory {
    return _selectedCategoryId == 'mobile'
        ? 'Check back shortly — new listings go up every day.'
        : 'We are not buying or selling this category yet.';
  }
}
