import 'package:flutter/material.dart';

import '../widgets/app_back_button.dart';

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
        backgroundColor: const Color(0xFF32CD32),
        foregroundColor: Colors.black,
        leading: const AppBackButton.light(),
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
                            color: Colors.black)),
                  ],
                ),
              ),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF32CD32),
                    foregroundColor: Colors.black,
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
                          color: Colors.black, fontWeight: FontWeight.bold)),
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
                        color: Colors.black),
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
                              color: const Color(0xFFDFF8DF),
                              borderRadius: BorderRadius.circular(6)),
                          child: Text('-$discountPercent%',
                              style: const TextStyle(
                                  color: const Color(0xFF0B5A0B),
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text('₹$finalPrice',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black)),
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

