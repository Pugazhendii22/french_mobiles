import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase/catalog_firebase.dart';
import 'profile/account_pages.dart';
import 'profile_page.dart';
import 'screens/sell_mobile_page.dart';

// ==========================================
// GLOBAL COLOR CONFIGURATION
// ==========================================
class AppColors {
  static const Color primaryTheme = Color(0xFF8B0000);
  static const Color bodyBackground = Colors.white;
  static const Color primaryText = Colors.white;
  static const Color secondaryText = Color(0xFFFFCDD2);

  // Search Bar Styling
  static const Color searchBarBackground = Colors.white;
  static const Color searchBarIcon = Color(0xFF666666);
  static const Color searchBarHint = Color(0xFF757575);

  // Category Bar & Product Styling
  static const Color categoryBarBackground = Colors.white;
  static const Color activeTabIndicator = Colors.black;
  static const Color activeTabText = Colors.black;
  static const Color inactiveTabText = Color(0xFF757575);
  static const Color profileIconColor = Colors.white;
  static const Color pinkBorder = Color(0xFFE91E63);
  static const Color darkTickerBg = Color(0xFF2C353F);
}

class HomeScreen extends StatefulWidget {
  final String customerName;

  const HomeScreen({Key? key, required this.customerName}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedCategoryId = 'mobile';

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: AppColors.primaryTheme,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));

    final currentUser = catalogAuth.currentUser;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryTheme,
        elevation: 4,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SellMobilePage()),
          );
        },
        icon: const Icon(Icons.currency_rupee, color: Colors.white),
        label: const Text('Sell Phone',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        onPanDown: (_) => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                color: AppColors.primaryTheme,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hello, ${widget.customerName}',
                                  style: const TextStyle(
                                      color: AppColors.primaryText,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              const SavedAddressesPage()),
                                    );
                                  },
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: currentUser == null
                                            ? const Text(
                                                'Select delivery address',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                    color:
                                                        AppColors.secondaryText,
                                                    fontSize: 12),
                                              )
                                            : StreamBuilder<
                                                QuerySnapshot<
                                                    Map<String, dynamic>>>(
                                                stream: catalogFirestore
                                                    .collection('users')
                                                    .doc(currentUser.uid)
                                                    .collection('addresses')
                                                    .where('isDefault',
                                                        isEqualTo: true)
                                                    .limit(1)
                                                    .snapshots(),
                                                builder: (context, snapshot) {
                                                  String displayText =
                                                      'Add delivery address';
                                                  if (snapshot.hasData &&
                                                      snapshot.data!.docs
                                                          .isNotEmpty) {
                                                    final addressData = snapshot
                                                        .data!.docs.first
                                                        .data();
                                                    final label =
                                                        (addressData['label']
                                                                    as String?)
                                                                ?.trim() ??
                                                            '';
                                                    final fullAddress =
                                                        (addressData['fullAddress']
                                                                    as String?)
                                                                ?.trim() ??
                                                            '';
                                                    if (label.isNotEmpty &&
                                                        fullAddress
                                                            .isNotEmpty) {
                                                      displayText =
                                                          '$label - $fullAddress';
                                                    } else if (fullAddress
                                                        .isNotEmpty) {
                                                      displayText = fullAddress;
                                                    }
                                                  }
                                                  return Text(
                                                    displayText,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        color: AppColors
                                                            .secondaryText,
                                                        fontSize: 12),
                                                  );
                                                },
                                              ),
                                      ),
                                      const Icon(Icons.keyboard_arrow_down,
                                          color: AppColors.secondaryText,
                                          size: 16),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.account_circle,
                                color: AppColors.profileIconColor, size: 32),
                            onPressed: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const ProfilePage()));
                            },
                          ),
                        ],
                      ),
                    ),
                    const AnimatedSearchBar(),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  color: AppColors.bodyBackground,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).padding.bottom + 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        const PromoBannerSlider(),
                        const SizedBox(height: 16),
                        const ScrollingTickerBar(),
                        const SizedBox(height: 16),
                        TopCategoryBar(
                          categories: sampleCategories,
                          selectedCategoryId: selectedCategoryId,
                          onCategorySelect: (id) {
                            setState(() {
                              selectedCategoryId = id;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        ProductHorizontalList(categoryId: selectedCategoryId),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// DATA MODELS & CATEGORY-SPECIFIC PRODUCTS
// ==========================================
class CategoryModel {
  final String id;
  final String title;
  final String iconUrl;

  CategoryModel({
    required this.id,
    required this.title,
    required this.iconUrl,
  });
}

class ProductModel {
  final String id;
  final String categoryId;
  final String brand;
  final String title;
  final String imageUrl;
  final String featureTag;
  final String discount;
  final String price;
  final String originalPrice;
  final String couponPrice;
  final String rating;
  final String reviewsCount;
  final String? documentId;
  final Map<String, dynamic>? firestoreData;

  ProductModel({
    required this.id,
    required this.categoryId,
    required this.brand,
    required this.title,
    required this.imageUrl,
    required this.featureTag,
    required this.discount,
    required this.price,
    required this.originalPrice,
    required this.couponPrice,
    required this.rating,
    required this.reviewsCount,
    this.documentId,
    this.firestoreData,
  });
}

final List<CategoryModel> sampleCategories = [
  CategoryModel(
    id: 'mobile',
    title: 'Mobile',
    iconUrl:
        'https://res.cloudinary.com/dvsnmkgwx/image/upload/v1788426580/images-removebg-preview_gzons0.png',
  ),
  CategoryModel(
    id: 'laptops',
    title: 'Laptops',
    iconUrl:
        'https://res.cloudinary.com/dvsnmkgwx/image/upload/v1788430704/mbp-14-digitalmat-gallery-6-202410-removebg-preview_xmqnvh.png',
  ),
  CategoryModel(
    id: 'earparts',
    title: 'Earparts',
    iconUrl:
        'https://res.cloudinary.com/dvsnmkgwx/image/upload/v1788430875/airpods-pro-3-hero-select-202509_FMT_WHH-removebg-preview_lnjjup.png',
  ),
];

// ==========================================
// TICKER WIDGET
// ==========================================
class ScrollingTickerBar extends StatefulWidget {
  const ScrollingTickerBar({Key? key}) : super(key: key);

  @override
  State<ScrollingTickerBar> createState() => _ScrollingTickerBarState();
}

class _ScrollingTickerBarState extends State<ScrollingTickerBar> {
  late ScrollController _scrollController;
  Timer? _tickerTimer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startContinuousScroll();
    });
  }

  void _startContinuousScroll() {
    _tickerTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (_scrollController.hasClients) {
        double maxScroll = _scrollController.position.maxScrollExtent;
        double currentScroll = _scrollController.offset;

        if (currentScroll >= maxScroll) {
          _scrollController.jumpTo(0);
        } else {
          _scrollController.jumpTo(currentScroll + 1.2);
        }
      }
    });
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildTickerItem(IconData icon, String title, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      width: double.infinity,
      color: AppColors.darkTickerBg,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          return Row(
            children: [
              _buildTickerItem(Icons.verified_user_outlined,
                  'Doorstep Verification', Colors.lightGreenAccent),
              _buildTickerItem(Icons.sync, 'Easy Replacement', Colors.white),
              _buildTickerItem(Icons.calendar_today_outlined,
                  'No Cost EMI available', Colors.lightGreenAccent),
            ],
          );
        },
      ),
    );
  }
}

// ==========================================
// CATEGORY BAR
// ==========================================
class TopCategoryBar extends StatefulWidget {
  final List<CategoryModel> categories;
  final String selectedCategoryId;
  final Function(String) onCategorySelect;

  const TopCategoryBar({
    Key? key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelect,
  }) : super(key: key);

  @override
  State<TopCategoryBar> createState() => _TopCategoryBarState();
}

class _TopCategoryBarState extends State<TopCategoryBar> {
  final ScrollController _scrollController = ScrollController();

  double _iconScaleFor(String id) {
    // Fine-tune these multipliers when assets differ in visible padding.
    const mapping = {
      'laptops': 1.5,
      'earparts': 1.08,
      'mobile': 1.0,
    };
    return mapping[id] ?? 1.0;
  }

  void _onCategorySelected(int index, String id) {
    widget.onCategorySelect(id);

    double itemWidth = 100.0; // Increased to match larger item width
    double screenWidth = MediaQuery.of(context).size.width;
    double targetOffset =
        (index * itemWidth) - (screenWidth / 2) + (itemWidth / 2);

    double maxScroll = _scrollController.position.maxScrollExtent;
    double minScroll = _scrollController.position.minScrollExtent;
    double clampedOffset = targetOffset.clamp(minScroll, maxScroll);

    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 120, // Increased height to prevent overflow with larger icons
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: widget.categories.length,
            itemBuilder: (context, index) {
              final item = widget.categories[index];
              final isSelected = item.id == widget.selectedCategoryId;

              return InkWell(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                onTap: () => _onCategorySelected(index, item.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 95, // Increased width per category item
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(height: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutBack,
                        transform: Matrix4.translationValues(
                            0, isSelected ? -6.0 : 0.0, 0),
                        child: Builder(builder: (context) {
                          final iconScaleFactor = _iconScaleFor(item.id);
                          final baseScale = isSelected ? 1.12 : 1.0;
                          return AnimatedScale(
                            scale: baseScale * iconScaleFactor,
                            duration: const Duration(milliseconds: 250),
                            child: Image.network(
                              item.iconUrl,
                              height: 56, // Increased from 38 to 56
                              width: 56, // Increased from 38 to 56
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.devices,
                                      size: 56, color: Colors.grey),
                            ),
                          );
                        }),
                      ),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? AppColors.activeTabText
                              : AppColors.inactiveTabText,
                        ),
                        child: Text(item.title),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 3,
                        width: isSelected ? 95.0 : 0.0,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.activeTabIndicator
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
      ],
    );
  }
}

// ==========================================
// PRODUCT HORIZONTAL LIST
// ==========================================
class ProductHorizontalList extends StatefulWidget {
  final String categoryId;

  const ProductHorizontalList({Key? key, required this.categoryId})
      : super(key: key);

  @override
  State<ProductHorizontalList> createState() => _ProductHorizontalListState();
}

class _ProductHorizontalListState extends State<ProductHorizontalList> {
  late Future<List<ProductModel>> _futureProducts;

  @override
  void initState() {
    super.initState();
    _futureProducts = _loadProducts();
  }

  @override
  void didUpdateWidget(covariant ProductHorizontalList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categoryId != widget.categoryId) {
      _futureProducts = _loadProducts();
    }
  }

  Future<List<ProductModel>> _loadProducts() async {
    if (widget.categoryId == 'mobile') {
      return _loadAvailableMobileProducts();
    }
    return const [];
  }

  Future<List<ProductModel>> _loadAvailableMobileProducts() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('second_hand_mobiles')
        .where('status', isEqualTo: 'available')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      final brand = (data['brand'] ?? '').toString();
      final model = (data['model'] ?? '').toString();
      final photo1Url = (data['photo1Url'] ?? '').toString();
      final rawPrice = data['salePrice'];
      final priceValue = rawPrice is num
          ? '₹ ${rawPrice.toStringAsFixed(0)}'
          : (rawPrice == null
              ? ''
              : rawPrice.toString().startsWith('₹')
                  ? rawPrice.toString()
                  : '₹ $rawPrice');

      return ProductModel(
        id: doc.id,
        categoryId: 'mobile',
        brand: brand,
        title: '$brand $model'.trim(),
        imageUrl: photo1Url,
        featureTag: '',
        discount: '',
        price: priceValue,
        originalPrice: '',
        couponPrice: '',
        rating: '',
        reviewsCount: '',
        documentId: doc.id,
        firestoreData: data,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.categoryId == 'laptops' || widget.categoryId == 'earparts') {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text('Coming soon'),
        ),
      );
    }

    return FutureBuilder<List<ProductModel>>(
      future: _futureProducts,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox(
            height: 200,
            child: Center(
              child: Text('No products available in this category'),
            ),
          );
        }

        final products = snapshot.data!;

        // Split products into two rows (even indices and odd indices)
        final row1 = <ProductModel>[];
        final row2 = <ProductModel>[];
        for (var i = 0; i < products.length; i++) {
          if (i.isEven) {
            row1.add(products[i]);
          } else {
            row2.add(products[i]);
          }
        }

        // Use a tighter row height so the divider appears right after the cards
        const double rowHeight = 285;

        return Column(
          children: [
            SizedBox(
              height: rowHeight,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: row1.length,
                itemBuilder: (context, index) {
                  return ProductCard(product: row1[index]);
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: rowHeight,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: row2.length,
                itemBuilder: (context, index) {
                  return ProductCard(product: row2[index]);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class ProductCard extends StatelessWidget {
  final ProductModel product;

  const ProductCard({Key? key, required this.product}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hasFeatureTag = product.featureTag.isNotEmpty;
    final hasDiscount = product.discount.isNotEmpty;
    final hasCoupon = product.couponPrice.isNotEmpty;
    final hasOriginalPrice = product.originalPrice.isNotEmpty;
    final hasRating =
        product.rating.isNotEmpty || product.reviewsCount.isNotEmpty;

    return GestureDetector(
      onTap: () {
        if (product.documentId != null || product.firestoreData != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => InventoryDetailPlaceholder(
                documentId: product.documentId,
                data: product.firestoreData ??
                    {
                      'id': product.documentId,
                      'brand': product.brand,
                      'model': product.title,
                      'salePrice': product.price,
                    },
              ),
            ),
          );
        }
      },
      child: Container(
        width: 165,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 200,
                  width: 165,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9F9F9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      product.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                              child: Icon(Icons.devices,
                                  size: 50, color: Colors.grey)),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: const Icon(Icons.favorite_border,
                        size: 20, color: Colors.black45),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              product.brand,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Text(
              product.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black87, fontSize: 12),
            ),
            if (hasFeatureTag) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  product.featureTag,
                  style: const TextStyle(fontSize: 10, color: Colors.black87),
                ),
              ),
            ],
            if (hasDiscount) ...[
              const SizedBox(height: 4),
              Text(
                product.discount,
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
            Row(
              children: [
                Text(
                  product.price,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
                if (hasOriginalPrice) ...[
                  const SizedBox(width: 4),
                  Text(
                    product.originalPrice,
                    style: const TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: Colors.grey,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
            if (hasCoupon) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.couponPrice,
                      style: const TextStyle(
                        color: Color(0xFF1A73E8),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.local_offer,
                        size: 10, color: Color(0xFF1A73E8)),
                  ],
                ),
              ),
            ],
            if (hasRating) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.star, size: 12, color: Colors.green),
                  const SizedBox(width: 2),
                  Text(
                    product.rating,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    ' (${product.reviewsCount})',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class InventoryDetailPlaceholder extends StatefulWidget {
  final String? documentId;
  final Map<String, dynamic> data;

  const InventoryDetailPlaceholder({
    Key? key,
    required this.data,
    this.documentId,
  }) : super(key: key);

  @override
  State<InventoryDetailPlaceholder> createState() =>
      _InventoryDetailPlaceholderState();
}

class _InventoryDetailPlaceholderState
    extends State<InventoryDetailPlaceholder> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<String> _collectImages() {
    final d = widget.data;
    if (d['images'] is List) {
      return List<String>.from((d['images'] as List).whereType<String>());
    }
    if (d['photos'] is List) {
      return List<String>.from((d['photos'] as List).whereType<String>());
    }
    final candidates = <String>[];
    if (d['photo1Url'] is String && (d['photo1Url'] as String).isNotEmpty)
      candidates.add(d['photo1Url'] as String);
    if (d['imageUrl'] is String && (d['imageUrl'] as String).isNotEmpty)
      candidates.add(d['imageUrl'] as String);
    if (d['photo'] is String && (d['photo'] as String).isNotEmpty)
      candidates.add(d['photo'] as String);
    return candidates.isEmpty
        ? ['https://via.placeholder.com/600x400?text=No+Image']
        : candidates;
  }

  int _safeInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String)
      return int.tryParse(v.replaceAll(RegExp('[^0-9]'), '')) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final images = _collectImages();
    final brand = (d['brand'] ?? d['maker'] ?? '')?.toString() ?? '';
    final model =
        (d['model'] ?? d['title'] ?? d['name'] ?? '')?.toString() ?? '';
    final description = (d['description'] ?? d['desc'] ?? '')?.toString() ?? '';

    final rawFinal =
        d['salePrice'] ?? d['finalPrice'] ?? d['price'] ?? d['finalPayout'];
    final finalPrice = _safeInt(rawFinal);
    final rawOriginal = d['originalPrice'] ?? d['mrp'] ?? d['basePrice'];
    final originalPrice = _safeInt(rawOriginal);
    int discountPercent = 0;
    if (originalPrice > 0 && originalPrice > finalPrice) {
      discountPercent =
          ((originalPrice - finalPrice) * 100 / originalPrice).round();
    }

    final Map<String, dynamic> specs = {};
    if (d['specs'] is Map) specs.addAll(Map<String, dynamic>.from(d['specs']));
    for (final key in [
      'brand',
      'model',
      'ram',
      'storage',
      'battery',
      'processor',
      'color',
      'os'
    ]) {
      if (d.containsKey(key) && d[key] != null)
        specs[key.toUpperCase()] = d[key].toString();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(model.isNotEmpty ? '$brand $model' : 'Product Details'),
        backgroundColor: AppColors.primaryTheme,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Final Price',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Text('₹$finalPrice',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryTheme)),
                  ],
                ),
              ),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryTheme,
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Buy flow not implemented')));
                  },
                  child: const Text('Buy Now',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 320,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: images.length,
                    onPageChanged: (i) => setState(() => _currentIndex = i),
                    itemBuilder: (context, index) {
                      return Container(
                        color: Colors.grey[200],
                        child: Image.network(
                          images[index],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                                child: CircularProgressIndicator());
                          },
                        ),
                      );
                    },
                  ),
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(images.length, (i) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentIndex == i ? 18 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentIndex == i
                                ? Colors.white
                                : Colors.white70,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model.isNotEmpty
                        ? '$brand $model'
                        : (brand.isNotEmpty ? brand : 'Product'),
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (originalPrice > 0) ...[
                        Text('₹$originalPrice',
                            style: const TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey)),
                        const SizedBox(width: 8),
                      ],
                      if (discountPercent > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(6)),
                          child: Text('-$discountPercent%',
                              style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text('₹$finalPrice',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryTheme)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Overview',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(description.isNotEmpty
                      ? description
                      : 'No description available.'),
                  const SizedBox(height: 16),
                  const Text('Specifications',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Builder(builder: (context) {
                    if (specs.isEmpty)
                      return const Text('No specifications available.');
                    return Column(
                      children: specs.entries.map((e) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            children: [
                              Expanded(
                                  child: Text(e.key.toString(),
                                      style:
                                          const TextStyle(color: Colors.grey))),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Text(e.value.toString(),
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600))),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  }),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// ANIMATED SEARCH BAR & BANNER SLIDER
// ==========================================
// ==========================================
// ANIMATED SEARCH BAR
// ==========================================
class AnimatedSearchBar extends StatefulWidget {
  const AnimatedSearchBar({Key? key}) : super(key: key);

  @override
  State<AnimatedSearchBar> createState() => _AnimatedSearchBarState();
}

class _AnimatedSearchBarState extends State<AnimatedSearchBar> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  final List<String> _searchKeywords = [
    'TWS Earbuds',
    'Blenders & Fans',
    'Grooming Trimmers',
    'Powerbanks',
    'Headphones',
  ];

  String _currentDisplayedText = '';
  int _keywordIndex = 0;
  int _characterIndex = 0;
  bool _isDeleting = false;
  Timer? _animationTimer;

  @override
  void initState() {
    super.initState();
    _startTypewriterAnimation();

    _searchController.addListener(() {
      setState(() {});
    });

    _focusNode.addListener(() {
      setState(() {});
    });
  }

  void _startTypewriterAnimation() {
    _animationTimer =
        Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_searchController.text.isNotEmpty || _focusNode.hasFocus) {
        return;
      }

      final currentFullWord = _searchKeywords[_keywordIndex];

      if (mounted) {
        setState(() {
          if (!_isDeleting) {
            _currentDisplayedText =
                currentFullWord.substring(0, _characterIndex);
            _characterIndex++;

            if (_characterIndex > currentFullWord.length) {
              _isDeleting = true;
              _animationTimer?.cancel();
              Timer(const Duration(seconds: 2), () {
                if (mounted) _startTypewriterAnimation();
              });
            }
          } else {
            _characterIndex--;
            _currentDisplayedText =
                currentFullWord.substring(0, _characterIndex);

            if (_characterIndex == 0) {
              _isDeleting = false;
              _keywordIndex = (_keywordIndex + 1) % _searchKeywords.length;
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool showAnimatedHint =
        _searchController.text.isEmpty && !_focusNode.hasFocus;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.searchBarBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          style: const TextStyle(color: Colors.black, fontSize: 14),
          decoration: InputDecoration(
            hintText: showAnimatedHint
                ? 'Search for "$_currentDisplayedText"'
                : 'Search...',
            hintStyle: TextStyle(
              color:
                  showAnimatedHint ? Colors.black87 : AppColors.searchBarHint,
              fontSize: 14,
            ),
            prefixIcon: const Icon(
              Icons.search,
              color: AppColors.searchBarIcon,
              size: 20,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }
}

class PromoBannerSlider extends StatefulWidget {
  const PromoBannerSlider({Key? key}) : super(key: key);

  @override
  State<PromoBannerSlider> createState() => _PromoBannerSliderState();
}

class _PromoBannerSliderState extends State<PromoBannerSlider> {
  int _currentIndex = 0;
  Timer? _timer;
  final PageController _pageController = PageController(viewportFraction: 0.92);

  final List<String> banners = [
    'https://via.placeholder.com/600x300/0f2b1d/ffffff?text=Philips+Trimmers+ka+Baap',
    'https://via.placeholder.com/600x300/1e4d2b/ffffff?text=New+Launches+Now+Available',
    'https://via.placeholder.com/600x300/1a1a1a/ffffff?text=Exclusive+Festive+Offers',
  ];

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_pageController.hasClients) {
        int nextIndex = (_currentIndex + 1) % banners.length;
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemCount: banners.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    banners[index],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[800],
                      child: const Center(
                        child:
                            Icon(Icons.campaign, color: Colors.white, size: 40),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            banners.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3.0),
              height: 6,
              width: _currentIndex == index ? 20 : 6,
              decoration: BoxDecoration(
                color: _currentIndex == index
                    ? AppColors.primaryTheme
                    : Colors.grey[400],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
