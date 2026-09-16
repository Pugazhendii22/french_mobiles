import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../models/model_detail.dart';
import '../widgets/widgets.dart';
import 'variant_selection_page.dart';

class BrandDetailPage extends StatefulWidget {
  final String brandName;
  final Color themeColor;

  const BrandDetailPage({
    super.key,
    required this.brandName,
    required this.themeColor,
  });

  @override
  State<BrandDetailPage> createState() => _BrandDetailPageState();
}

class _BrandDetailPageState extends State<BrandDetailPage> {
  final TextEditingController _modelSearchController = TextEditingController();
  String _selectedCategory = 'All';
  List<ModelDetail> _allBrandModels = [];
  List<ModelDetail> _filteredModels = [];
  bool _isLoadingModels = true;

  FirebaseFirestore get _catalogFirestore =>
      FirebaseFirestore.instanceFor(app: Firebase.app('catalogApp'));

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  int _parsePrice(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  Future<void> _loadModels() async {
    setState(() {
      _isLoadingModels = true;
      _filteredModels = [];
    });

    try {
      final querySnapshot = await _catalogFirestore
          .collection('brands')
          .doc(widget.brandName.toLowerCase())
          .collection('models')
          .get();

      final models = <ModelDetail>[];

      final variantResults = await Future.wait(
        querySnapshot.docs.map((doc) async {
          final modelData = doc.data();
          final variantsSnapshot = await _catalogFirestore
              .collection('brands')
              .doc(widget.brandName.toLowerCase())
              .collection('models')
              .doc(doc.id)
              .collection('variants')
              .get();

          int highestBasePrice = 0;
          for (final variantDoc in variantsSnapshot.docs) {
            final variantData = variantDoc.data();
            final variantPrice = _parsePrice(variantData['base_price']);
            if (variantPrice > highestBasePrice) {
              highestBasePrice = variantPrice;
            }
          }

          final modelName = (modelData['model'] ?? 'Unknown Model').toString();
          final imageUrl = (modelData['image_url'] ?? '').toString().trim();
          final releaseYear = modelData['release_year'];
          final category =
              releaseYear == null ? 'Unknown' : releaseYear.toString();

          return ModelDetail(
            name: modelName,
            category: category,
            maxPrice: highestBasePrice == 0
                ? _parsePrice(modelData['base_price'])
                : highestBasePrice,
            imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
            docId: doc.id,
          );
        }),
      );

      models.addAll(variantResults);

      setState(() {
        _allBrandModels = models;
        _filteredModels = _applyFilters(_modelSearchController.text);
      });
    } catch (_) {
      setState(() {
        _allBrandModels = [];
        _filteredModels = [];
      });
    } finally {
      setState(() {
        _isLoadingModels = false;
      });
    }
  }

  List<ModelDetail> _applyFilters(String query) {
    final searchQuery = query.toLowerCase();
    return _allBrandModels.where((model) {
      final matchesQuery = model.name.toLowerCase().contains(searchQuery);
      final matchesCategory =
          _selectedCategory == 'All' || model.category == _selectedCategory;
      return matchesQuery && matchesCategory;
    }).toList();
  }

  Future<void> _filterModels(String query) async {
    setState(() {
      _filteredModels = _applyFilters(query);
    });
  }

  void _showModelDetailsBottomSheet(ModelDetail item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 56,
                        height: 56,
                        padding: const EdgeInsets.all(4),
                        color: const Color(0xFFEDF1F5),
                        child: (item.imageUrl != null &&
                                item.imageUrl!.isNotEmpty)
                            ? Image.network(
                                item.imageUrl!,
                                fit: BoxFit.contain,
                                width: double.infinity,
                                height: double.infinity,
                                frameBuilder:
                                    (context, child, frame, wasSynchronouslyLoaded) {
                                  if (wasSynchronouslyLoaded) return child;
                                  return AnimatedOpacity(
                                    opacity: frame == null ? 0.0 : 1.0,
                                    duration: const Duration(milliseconds: 350),
                                    curve: Curves.easeOut,
                                    child: child,
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.smartphone,
                                        color: Colors.blueGrey),
                              )
                            : const Icon(Icons.smartphone,
                                color: Colors.blueGrey),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.brandName} · $_selectedCategory'.trim(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF32CD32).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF32CD32).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.currency_rupee,
                          size: 18, color: Color(0xFF1E9B1E)),
                      const SizedBox(width: 6),
                      Text(
                        'Up to ₹${item.maxPrice}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E9B1E),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'NEXT STEPS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Evaluate basic device condition to get an exact valuation.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VariantSelectionPage(
                            brandName: widget.brandName,
                            modelDocId: item.docId!,
                            modelName: item.name,
                            imageUrl: item.imageUrl,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF32CD32),
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Evaluate Device Condition',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _modelSearchController.dispose();
    super.dispose();
  }

  String _formatPrice(int value) {
    final s = value.toString();
    return s.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    final allModels = _allBrandModels;
    final categories = [
      'All',
      ...{for (var m in allModels) m.category}
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          AppGradientHeader(title: 'Select ${widget.brandName} Model'),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _modelSearchController,
                    onChanged: _filterModels,
                    decoration: InputDecoration(
                      hintText: 'Search ${widget.brandName} model...',
                      hintStyle: const TextStyle(
                          color: Color(0xFF94A3B8), fontSize: 14),
                      prefixIcon:
                          const Icon(Icons.search, color: Color(0xFF94A3B8)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (categories.length > 2) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 36,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.only(right: 32),
                            itemCount: categories.length,
                            itemBuilder: (context, index) {
                              final cat = categories[index];
                              final isSelected = cat == _selectedCategory;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedCategory = cat;
                                    _filterModels(_modelSearchController.text);
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 20),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        cat,
                                        style: TextStyle(
                                          color: isSelected
                                              ? const Color(0xFF32CD32)
                                              : const Color(0xFF64748B),
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        height: 2.5,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(0xFF32CD32)
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          width: 28,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerRight,
                                  end: Alignment.centerLeft,
                                  colors: [
                                    Colors.white,
                                    Colors.white.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoadingModels
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF32CD32)),
                    ),
                  )
                : _filteredModels.isEmpty
                    ? const Center(
                        child: Text(
                          'No models found matching your search.',
                          style: TextStyle(color: Color(0xFF94A3B8)),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 28),
                        itemCount: _filteredModels.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 24),
                        itemBuilder: (context, index) {
                          final item = _filteredModels[index];
                          return _AnimatedBreakoutModelCard(
                            key: ValueKey('${item.name}_$index'),
                            index: index,
                            item: item,
                            onTap: () => _showModelDetailsBottomSheet(item),
                            formatPrice: _formatPrice,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedBreakoutModelCard extends StatefulWidget {
  final int index;
  final ModelDetail item;
  final VoidCallback onTap;
  final String Function(int) formatPrice;

  const _AnimatedBreakoutModelCard({
    super.key,
    required this.index,
    required this.item,
    required this.onTap,
    required this.formatPrice,
  });

  @override
  State<_AnimatedBreakoutModelCard> createState() =>
      __AnimatedBreakoutModelCardState();
}

class __AnimatedBreakoutModelCardState
    extends State<_AnimatedBreakoutModelCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _scaleAnimation = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.65),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // Stagger animation start for initial visible batch (indices 0..5)
    // and animate immediately as off-screen cards are scrolled into view
    final delayMs = widget.index < 6 ? widget.index * 80 : 0;
    if (delayMs > 0) {
      Future.delayed(Duration(milliseconds: delayMs), () {
        if (mounted) {
          _controller.forward(from: 0.0);
        }
      });
    } else {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildPhoneImage(double cardBoxHeight, double topOverflow) {
    final imageWidget = (widget.item.imageUrl != null &&
            widget.item.imageUrl!.isNotEmpty)
        ? Image.network(
            widget.item.imageUrl!,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF32CD32),
                    ),
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Icon(
                Icons.smartphone,
                size: 36,
                color: Colors.blueGrey,
              ),
            ),
          )
        : const Center(
            child: Icon(
              Icons.smartphone,
              size: 36,
              color: Colors.blueGrey,
            ),
          );

    return SizedBox(
      width: 110,
      height: cardBoxHeight + topOverflow,
      child: ClipRect(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOut,
          builder: (context, opacity, child) {
            return Opacity(
              opacity: opacity,
              child: child,
            );
          },
          child: imageWidget,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double cardBoxHeight = 100.0;
    const double topOverflow = 20.0; // 120px total height -> breakout top offset

    return Container(
      margin: const EdgeInsets.only(top: topOverflow),
      child: ClipRect(
        clipper: const _TopOnlyOverflowClipper(topOverflowLimit: 80.0),
        child: SizedBox(
          height: cardBoxHeight,
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              // 1. Box Frame - rounded white card background with details & price
              Container(
                height: cardBoxHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0D0F172A),
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: widget.onTap,
                    splashColor: const Color(0x1F32CD32),
                    highlightColor: const Color(0x0F32CD32),
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 12,
                        right: 16,
                        top: 8,
                        bottom: 8,
                      ),
                      child: Row(
                        children: [
                          // Left spacing reserve for the breakout phone image
                          const Expanded(
                            flex: 5,
                            child: SizedBox.expand(),
                          ),

                          // Right Side: Text details & Price
                          Expanded(
                            flex: 6,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.item.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'GET UP TO',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF94A3B8),
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '₹${widget.formatPrice(widget.item.maxPrice)}',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF32CD32),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 30,
                                      height: 30,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF32CD32),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.chevron_right,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 2. Animated phone image - ON TOP of the box frame
              // Starts sliding from inside the box bounds, rising up smoothly into final position.
              Positioned(
                left: 12,
                bottom: 0,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ScaleTransition(
                    alignment: Alignment.bottomCenter,
                    scale: _scaleAnimation,
                    child: _buildPhoneImage(cardBoxHeight, topOverflow),
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

/// Custom clipper that allows generous overflow above the widget (so phone top is never cut)
/// while strictly clipping any overflow extending below the box bottom edge.
class _TopOnlyOverflowClipper extends CustomClipper<Rect> {
  final double topOverflowLimit;

  const _TopOnlyOverflowClipper({this.topOverflowLimit = 80.0});

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(-20, -topOverflowLimit, size.width + 20, size.height);
  }

  @override
  bool shouldReclip(covariant _TopOnlyOverflowClipper oldClipper) {
    return topOverflowLimit != oldClipper.topOverflowLimit;
  }
}
