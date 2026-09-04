import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../models/model_detail.dart';
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

          final modelName = (modelData['model'] ?? 'Unknown Model')
              .toString();
          final imageUrl = (modelData['image_url'] ?? '').toString().trim();
          final releaseYear = modelData['release_year'];
          final category = releaseYear == null ? 'Unknown' : releaseYear.toString();

          return ModelDetail(
            name: modelName,
            category: category,
            maxPrice: highestBasePrice == 0 ? _parsePrice(modelData['base_price']) : highestBasePrice,
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
      final matchesCategory = _selectedCategory == 'All' || model.category == _selectedCategory;
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
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFFFAF8FF),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Maximum estimated value: ₹${item.maxPrice}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF16A34A),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Next steps: Evaluate basic device condition to get exact valuation.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
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
                    backgroundColor: const Color(0xFF00B69B),
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
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
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

  @override
  Widget build(BuildContext context) {
    final allModels = _allBrandModels;
    final categories = ['All', ...{for (var m in allModels) m.category}];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Select ${widget.brandName} Model',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (categories.length > 2) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 36,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        final isSelected = cat == _selectedCategory;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(cat),
                            selected: isSelected,
                            selectedColor: const Color(0xFFE2E8F0),
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: isSelected ? Colors.transparent : const Color(0xFFE2E8F0),
                              ),
                            ),
                            labelStyle: TextStyle(
                              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              fontSize: 13,
                            ),
                            onSelected: (selected) {
                              setState(() {
                                _selectedCategory = cat;
                                _filterModels(_modelSearchController.text);
                              });
                            },
                          ),
                        );
                      },
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
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00B69B)),
                    ),
                  )
                : _filteredModels.isEmpty
                    ? const Center(
                        child: Text(
                          'No models found matching your search.',
                          style: TextStyle(color: Color(0xFF94A3B8)),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredModels.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.82,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemBuilder: (context, index) {
                          final item = _filteredModels[index];
                          return GestureDetector(
                            onTap: () => _showModelDetailsBottomSheet(item),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                                          ? Image.network(
                                              item.imageUrl!,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: double.infinity,
                                              loadingBuilder: (context, child, loadingProgress) {
                                                if (loadingProgress == null) {
                                                  return child;
                                                }
                                                return const Center(
                                                  child: SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor: AlwaysStoppedAnimation<Color>(
                                                        Color(0xFF00B69B),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                              errorBuilder: (context, error, stackTrace) {
                                                return Icon(
                                                  Icons.smartphone,
                                                  size: 48,
                                                  color: Colors.blueGrey.shade300,
                                                );
                                              },
                                            )
                                          : Icon(
                                              Icons.smartphone,
                                              size: 48,
                                              color: Colors.blueGrey.shade300,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Get up to ₹${item.maxPrice}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF16A34A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
