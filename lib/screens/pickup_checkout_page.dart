import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../firebase/catalog_firebase.dart';
import '../profile/account_pages.dart';
import '../widgets/app_back_button.dart';

import 'order_tracking_page.dart';
import 'login_page.dart';

class PickupCheckoutPage extends StatefulWidget {
  final String brandName;
  final String modelDocId;
  final String modelName;
  final String? imageUrl;
  final String variant; // storage string
  final int basePrice;
  final int finalPayout;

  const PickupCheckoutPage({
    super.key,
    required this.brandName,
    required this.modelDocId,
    required this.modelName,
    this.imageUrl,
    required this.variant,
    required this.basePrice,
    required this.finalPayout,
  });

  @override
  State<PickupCheckoutPage> createState() => _PickupCheckoutPageState();
}

class _PickupCheckoutPageState extends State<PickupCheckoutPage> {
  String? _selectedAddressLabel;
  String? _selectedAddressFullText;
  double? _selectedAddressLat;
  double? _selectedAddressLng;
  bool _loadingAddress = false;
  bool _placingOrder = false;

  @override
  void initState() {
    super.initState();
    _loadDefaultAddress();
  }

  Future<void> _loadDefaultAddress() async {
    final user = catalogAuth.currentUser;
    if (user == null) return;
    setState(() => _loadingAddress = true);
    try {
      final col = catalogFirestore.collection('users').doc(user.uid).collection('addresses');
      final snap = await col.where('isDefault', isEqualTo: true).limit(1).get();
      if (snap.docs.isNotEmpty) {
        final d = snap.docs.first.data();
        setState(() {
          _selectedAddressLabel = (d['label'] as String?) ?? 'Other';
          _selectedAddressFullText = (d['fullAddress'] as String?) ?? '';
          _selectedAddressLat = (d['latitude'] as num?)?.toDouble();
          _selectedAddressLng = (d['longitude'] as num?)?.toDouble();
        });
      }
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loadingAddress = false);
    }
  }

  Future<void> _placeOrder() async {
    if (_selectedAddressFullText == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a pickup address')));
      return;
    }

    setState(() => _placingOrder = true);

    try {
      var user = catalogAuth.currentUser;
      if (user == null) {
        final loggedIn = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
        if (loggedIn != true) {
          setState(() => _placingOrder = false);
          return;
        }
        user = catalogAuth.currentUser;
      }

      if (user == null) {
        setState(() => _placingOrder = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to determine user after login')));
        return;
      }

      final orderData = {
        'userId': user.uid,
        'brand': widget.brandName,
        'modelDocId': widget.modelDocId,
        'modelName': widget.modelName,
        'storage': widget.variant,
        'imageUrl': widget.imageUrl,
        'basePrice': widget.basePrice,
        'finalPayout': widget.finalPayout,
        'addressLabel': _selectedAddressLabel,
        'addressFullText': _selectedAddressFullText,
        'addressLatitude': _selectedAddressLat,
        'addressLongitude': _selectedAddressLng,
        'status': 'placed',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final ref = await catalogFirestore.collection('orders').add(orderData);
      final orderId = ref.id;

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => OrderTrackingPage(orderId: orderId)),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to place order: $e')));
    } finally {
      if (mounted) setState(() => _placingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const AppBackButton.light(),
        titleSpacing: 0,
        title: GestureDetector(
          onTap: () async {
            final result = await Navigator.push<Map<String, dynamic>?>(
              context,
              MaterialPageRoute(builder: (context) => const SavedAddressesPage(selectMode: true)),
            );
            if (result != null) {
              setState(() {
                _selectedAddressLabel = (result['label'] as String?) ?? _selectedAddressLabel;
                _selectedAddressFullText = (result['fullAddress'] as String?) ?? _selectedAddressFullText;
                _selectedAddressLat = (result['latitude'] as num?)?.toDouble() ?? _selectedAddressLat;
                _selectedAddressLng = (result['longitude'] as num?)?.toDouble() ?? _selectedAddressLng;
              });
            }
          },
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _selectedAddressLabel ?? 'Add a pickup address',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down, color: Colors.black),
                      ],
                    ),
                    Text(
                      _selectedAddressFullText ?? '',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.schedule, size: 20, color: Colors.black87),
                                SizedBox(width: 8),
                                Text(
                                  'Doorstep Pickup',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFFE0E0E0)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.calendar_month_outlined,
                                      size: 16, color: Color(0xFFE91E63)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Schedule',
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: Color(0xFFF0F0F0)),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: const Icon(
                                Icons.phone_android,
                                size: 36,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.modelName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.variant,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '₹${widget.finalPayout}',
                                    style: const TextStyle(
                                      color: Color(0xFF16A34A),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sell Order Confirmed Details',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE6F4EA),
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: const Icon(
                                Icons.verified_user_outlined,
                                color: Color(0xFF16A34A),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Instant Doorstep Valuation',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    'Field executive will inspect and transfer cash on the spot.',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'To Receive',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        '₹${widget.finalPayout}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: (_placingOrder || _selectedAddressFullText == null) ? null : _placeOrder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE91E63),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _placingOrder
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text(
                                'Place Order',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
