import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'brand_detail_page.dart';
import 'brand_list_page.dart';
import 'device_evaluation_wizard.dart';

class SellMobilePage extends StatefulWidget {
  const SellMobilePage({super.key});

  @override
  State<SellMobilePage> createState() => _SellMobilePageState();
}

class _SellMobilePageState extends State<SellMobilePage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

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

  final List<BrandModel> otherBrandData = moreBrandData;

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

  void _showHelpSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const _HelpSheetContent(),
    );
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
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SearchHeaderDelegate(_buildSearchBar(), topInset),
          ),
            if (_isSearching && _filteredModels.isNotEmpty)
              SliverToBoxAdapter(child: _buildSearchResults()),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Text(
                        'TOP MOBILE BRANDS',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: Color(0xFF54535A),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF32CD32), Color(0xFF1E9B1E)],
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome,
                                size: 12, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'AI PICKS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
                        height: 220,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          clipBehavior: Clip.none,
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                          itemCount: _filteredBrands.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final brand = _filteredBrands[index];
                            return BrandCard(
                              brand: brand,
                              onTap: () => _navigateToBrandDetail(brand),
                            );
                          },
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
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: Color(0xFF54535A),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(child: SizedBox()),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const BrandListPage(),
                            ),
                          );
                        },
                        child: const Text(
                          'View all',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E9B1E),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.9,
                    ),
                    itemCount: otherBrandData.length + 1,
                    itemBuilder: (context, index) {
                      if (index == otherBrandData.length) {
                        return _ViewAllBrandsTile(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const BrandListPage(),
                              ),
                            );
                          },
                        );
                      }
                      final brand = otherBrandData[index];
                      return GridBrandCard(
                        brand: brand,
                        onTap: () => _navigateToBrandDetail(brand),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search,
                            size: 14, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 6),
                        const Text(
                          "Don't see your brand? ",
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            FocusScope.of(context).requestFocus(
                                _searchFocusNode);
                          },
                          child: const Text(
                            'Search above',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E9B1E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return AppGradientHeader(
      title: 'Sell Old Phone',
      trailing: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: IconButton(
          tooltip: 'Sell help & FAQs',
          icon: const Icon(Icons.live_help_outlined,
              color: Color(0xFF1E9B1E)),
          onPressed: _showHelpSheet,
        ),
      ),
      content: const Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Get Instant Cash for Your Old Phone',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
              ),
            ),
            SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.verified_user,
                    size: 16, color: Color(0xFF1E9B1E)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Free doorstep pickup & instant payment',
                    style:
                        TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(child: _buildSearchField()),
      ],
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isSearching
              ? AppColors.primaryContainer
              : const Color(0xFFE2E8F0),
          width: _isSearching ? 1.5 : 1.0,
        ),
        boxShadow: _isSearching
            ? [
                BoxShadow(
                  color: AppColors.primaryContainer.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          icon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
          hintText: 'Search model (e.g. iPhone 13)',
          hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
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
    );
  }

  Widget _buildSearchResults() {
    return Padding(
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
                      color: AppColors.primaryContainer),
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
    );
  }
}

class _SearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _SearchHeaderDelegate(this.child, this.topInset);

  final Widget child;
  final double topInset;

  @override
  double get minExtent => topInset + 72;

  @override
  double get maxExtent => topInset + 72;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, topInset + 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: overlapsContent
            ? const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _SearchHeaderDelegate oldDelegate) =>
      oldDelegate.child != child;
}

class _HelpItem {
  const _HelpItem({
    required this.icon,
    required this.question,
    required this.answer,
  });

  final IconData icon;
  final String question;
  final String answer;
}

class _HelpSheetContent extends StatefulWidget {
  const _HelpSheetContent();

  @override
  State<_HelpSheetContent> createState() => _HelpSheetContentState();
}

class _HelpSheetContentState extends State<_HelpSheetContent> {
  static const List<_HelpItem> _items = [
    _HelpItem(
      icon: Icons.local_shipping_outlined,
      question: 'How does doorstep pickup work?',
      answer: 'Book a free pickup slot; our partner collects your phone, '
          'verifies it instantly, and hands over the payment on the spot.',
    ),
    _HelpItem(
      icon: Icons.currency_rupee,
      question: 'How is my price calculated?',
      answer: 'We check your model, condition and current market demand to '
          'generate an AI-recommended instant quote — no surprises.',
    ),
    _HelpItem(
      icon: Icons.schedule,
      question: 'When will I get paid?',
      answer: 'The moment we verify your device during pickup you receive '
          'payment immediately via UPI or bank transfer.',
    ),
    _HelpItem(
      icon: Icons.phone_android,
      question: 'Which phones are accepted?',
      answer: 'Any smartphone that powers on is eligible — even with cracks, '
          'scratches or a dead battery.',
    ),
  ];

  int _expandedIndex = -1;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                children: [
                  for (var i = 0; i < _items.length; i++) ...[
                    _AccordionItem(
                      item: _items[i],
                      expanded: _expandedIndex == i,
                      onToggle: () {
                        setState(() {
                          _expandedIndex = _expandedIndex == i ? -1 : i;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 8, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF32CD32), Color(0xFF1E9B1E)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.phone_iphone,
                              color: Colors.white, size: 26),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.currency_rupee,
                                size: 12, color: Color(0xFF1E9B1E)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Selling help',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Everything you need to know about selling your phone',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _AccordionItem extends StatelessWidget {
  const _AccordionItem({
    required this.item,
    required this.expanded,
    required this.onToggle,
  });

  final _HelpItem item;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: expanded ? const Color(0xFFF5FBF4) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF32CD32)
              .withValues(alpha: expanded ? 0.45 : 0.2),
          width: expanded ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF32CD32).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item.icon,
                        size: 18, color: const Color(0xFF1E9B1E)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.question,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child:
                        const Icon(Icons.expand_more, color: Color(0xFF1E9B1E)),
                  ),
                ],
              ),
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: expanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: Text(
                        item.answer,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewAllBrandsTile extends StatelessWidget {
  final VoidCallback? onTap;

  const _ViewAllBrandsTile({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF5FBF4),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF32CD32).withValues(alpha: 0.35)),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.apps, size: 24, color: Color(0xFF1E9B1E)),
            SizedBox(height: 8),
            Text(
              'View all brands',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E9B1E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
