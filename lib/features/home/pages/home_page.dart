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

  String _selectedCategoryId = 'mobile';
  String _searchQuery = '';
  late Future<List<HomeProduct>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _productsFuture = _repository.loadProducts(_selectedCategoryId);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
