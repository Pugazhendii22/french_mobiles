import 'package:flutter/material.dart';

import '../models/models.dart';
import '../shared/theme/app_colors.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/widgets.dart';
import 'brand_detail_page.dart';

/// Full-screen, searchable list of every brand in the sell flow.
/// Reachable from the "View all brands" tile on the sell page.
class BrandListPage extends StatefulWidget {
  const BrandListPage({super.key});

  @override
  State<BrandListPage> createState() => _BrandListPageState();
}

class _BrandListPageState extends State<BrandListPage> {
  final TextEditingController _searchController = TextEditingController();
  late List<BrandModel> _filteredBrands;

  @override
  void initState() {
    super.initState();
    _filteredBrands = List.of(allBrandData);
  }

  void _onSearchChanged(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredBrands = List.of(allBrandData);
      } else {
        _filteredBrands = allBrandData
            .where((b) =>
                b.name.toLowerCase().contains(q) ||
                b.logoText.toLowerCase().contains(q))
            .toList();
      }
    });
  }

  void _navigateToBrandDetail(BrandModel brand) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BrandDetailPage(
          brandName: brand.name,
          themeColor: brand.themeColor,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusScope.of(context).unfocus(),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenGutter,
                    AppSpacing.lg,
                    AppSpacing.screenGutter,
                    AppSpacing.lg,
                  ),
                  child: AppScreenHeader(
                    title: 'All brands',
                    content: AppSearchField(
                      controller: _searchController,
                      hintText: 'Search brands',
                      onChanged: _onSearchChanged,
                    ),
                  ),
                ),
                Expanded(
                  child: _filteredBrands.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(AppSpacing.screenGutter),
                          child: AppEmptyState(
                            title: 'No brands found',
                            message: 'Try a different name.',
                            icon: Icons.search_off_rounded,
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.screenGutter,
                            0,
                            AppSpacing.screenGutter,
                            AppSpacing.xxl,
                          ),
                          itemCount: _filteredBrands.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: AppSpacing.md,
                            mainAxisSpacing: AppSpacing.md,
                            childAspectRatio: 0.88,
                          ),
                          itemBuilder: (context, index) {
                            final brand = _filteredBrands[index];
                            return AppBrandCard(
                              brand: brand,
                              onTap: () => _navigateToBrandDetail(brand),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
