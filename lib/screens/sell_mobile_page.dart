import 'package:flutter/material.dart';

import '../models/models.dart';
import '../widgets/widgets.dart';
import 'brand_detail_page.dart';
import 'device_evaluation_wizard.dart';

class SellMobilePage extends StatefulWidget {
  const SellMobilePage({super.key});

  @override
  State<SellMobilePage> createState() => _SellMobilePageState();
}

class _SellMobilePageState extends State<SellMobilePage> {
  final TextEditingController _searchController = TextEditingController();

  List<BrandModel> _filteredBrands = brandData;
  List<String> _filteredModels = [];
  bool _isSearching = false;

  final List<String> _allModels = [
    'iPhone 15 Pro Max',
    'iPhone 14',
    'iPhone 13',
    'Samsung Galaxy S24 Ultra',
    'Samsung Galaxy S23 Ultra',
    'Samsung Galaxy Z Flip 5',
    'Samsung Galaxy M34',
    'Motorola Edge 40',
    'Motorola G84',
    'Oppo Reno 10 Pro',
    'Oppo Find N3 Flip',
    'OnePlus 11 5G',
    'Xiaomi 13 Pro',
  ];

  final List<BrandModel> otherBrandData = [
    BrandModel(
      name: 'Apple',
      discountText: 'Up to 50% off',
      logoText: 'Apple',
      themeColor: const Color(0xFF111827),
    ),
    BrandModel(
      name: 'OnePlus',
      discountText: 'Up to 35% off',
      logoText: 'ONEPLUS',
      themeColor: const Color(0xFFDC2626),
    ),
    BrandModel(
      name: 'Xiaomi',
      discountText: 'Up to 45% off',
      logoText: 'Mi / Xiaomi',
      themeColor: const Color(0xFFEA580C),
    ),
    BrandModel(
      name: 'Vivo',
      discountText: 'Up to 40% off',
      logoText: 'vivo',
      themeColor: const Color(0xFF2563EB),
    ),
    BrandModel(
      name: 'Realme',
      discountText: 'Up to 30% off',
      logoText: 'realme',
      themeColor: const Color(0xFFCA8A04),
    ),
    BrandModel(
      name: 'Google',
      discountText: 'Up to 35% off',
      logoText: 'Google',
      themeColor: const Color(0xFF059669),
    ),
  ];

  void _onSearchChanged(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _isSearching = false;
        _filteredBrands = brandData;
        _filteredModels = [];
      } else {
        _isSearching = true;

        _filteredBrands = brandData
            .where((brand) =>
                brand.name.toLowerCase().contains(query.toLowerCase()) ||
                brand.logoText.toLowerCase().contains(query.toLowerCase()))
            .toList();

        _filteredModels = _allModels
            .where((model) => model.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
    FocusScope.of(context).unfocus();
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
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () {},
        ),
        title: const Text(
          'Sell Old Phone',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.black87),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Get Instant Cash for Your Old Phone',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Free doorstep pickup & instant payment',
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isSearching
                            ? const Color(0xFF00B69B)
                            : const Color(0xFFE2E8F0),
                        width: _isSearching ? 1.5 : 1.0,
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        icon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
                        hintText: 'Search your mobile model (e.g. iPhone 13)',
                        hintStyle: const TextStyle(
                            fontSize: 14, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        suffixIcon: _isSearching
                            ? IconButton(
                                icon: const Icon(Icons.clear,
                                    size: 18, color: Color(0xFF64748B)),
                                onPressed: _clearSearch,
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_isSearching && _filteredModels.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MATCHING MODELS',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredModels.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        itemBuilder: (context, index) {
                          final modelName = _filteredModels[index];
                          return ListTile(
                            leading: const Icon(Icons.phone_iphone,
                                color: Color(0xFF00B69B)),
                            title: Text(
                              modelName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios,
                                size: 14, color: Color(0xFF94A3B8)),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DeviceEvaluationWizard(
                                    brandName: '',
                                    modelDocId: '',
                                    modelName: modelName,
                                    imageUrl: null,
                                    basePrice: 50000,
                                    storage: 'Standard Variant',
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'TOP MOBILE BRANDS',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0E7FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          size: 14,
                          color: Color(0xFF00B69B),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CustomPaint(
                          painter: DashedLinePainter(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _filteredBrands.isEmpty
                      ? Container(
                          height: 120,
                          width: double.infinity,
                          alignment: Alignment.center,
                          child: const Text(
                            'No matching brands found.',
                            style: TextStyle(color: Color(0xFF94A3B8)),
                          ),
                        )
                      : SizedBox(
                          height: 170,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: _filteredBrands.length,
                            itemBuilder: (context, index) {
                              final brand = _filteredBrands[index];
                              return BrandCard(
                                brand: brand,
                                onTap: () => _navigateToBrandDetail(brand),
                              );
                            },
                          ),
                        ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'MORE BRANDS',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CustomPaint(
                          painter: DashedLinePainter(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.95,
                    ),
                    itemCount: otherBrandData.length,
                    itemBuilder: (context, index) {
                      final brand = otherBrandData[index];
                      return GridBrandCard(
                        brand: brand,
                        onTap: () => _navigateToBrandDetail(brand),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}
