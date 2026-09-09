import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../widgets/widgets.dart';
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        leading: const AppBackButton.light(),
        title: const Text(
          'All Brands',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: const InputDecoration(
                  hintText: 'Search brands',
                  hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: Color(0xFF94A3B8)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          Expanded(
            child: _filteredBrands.isEmpty
                ? const Center(
                    child: Text(
                      'No brands found.',
                      style: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: _filteredBrands.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.9,
                    ),
                    itemBuilder: (context, index) {
                      final brand = _filteredBrands[index];
                      return GridBrandCard(
                        brand: brand,
                        onTap: () => _navigateToBrandDetail(brand),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
