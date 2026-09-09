import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../firebase/catalog_firebase.dart';
import '../widgets/app_back_button.dart';
import 'profile_widgets.dart';

class SavedAddressesPage extends StatefulWidget {
  final bool selectMode;
  const SavedAddressesPage({super.key, this.selectMode = false});

  @override
  State<SavedAddressesPage> createState() => _SavedAddressesPageState();
}

class _SavedAddressesPageState extends State<SavedAddressesPage> {
  CollectionReference<Map<String, dynamic>>? _addressesRef;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _fetchingLocation = false;

  @override
  void initState() {
    super.initState();
    final user = catalogAuth.currentUser;
    if (user != null) {
      _addressesRef = catalogFirestore
          .collection('users')
          .doc(user.uid)
          .collection('addresses');
    }
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteAddress(String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete address'),
        content: const Text('Are you sure you want to delete this address?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _addressesRef!.doc(docId).delete();
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to delete address: $e')));
      }
    }
  }

  void _openAddEdit({DocumentSnapshot<Map<String, dynamic>>? doc}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          AddEditAddressSheet(addressRef: _addressesRef!, existing: doc),
    );
  }

  Future<void> _useCurrentLocationDirect() async {
    if (_addressesRef == null) return;
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Location permission is required to use current location')),
        );
      }
      return;
    }

    setState(() => _fetchingLocation = true);
    try {
      final pos = await Geolocator.getCurrentPosition();
      String addressStr =
          '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';

      try {
        final uri = Uri.parse(
            'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${pos.latitude}&lon=${pos.longitude}');
        final res = await http.get(uri,
            headers: {'User-Agent': 'french-mobiles-app/1.0 (contact: none)'});
        if (res.statusCode == 200) {
          final Map<String, dynamic> j = jsonDecode(res.body);
          if (j['display_name'] is String &&
              (j['display_name'] as String).trim().isNotEmpty) {
            addressStr = j['display_name'] as String;
          }
        }
      } catch (_) {
        // network/geocoding failed — keep coordinate string as fallback
      }

      if (!mounted) return;
      setState(() => _fetchingLocation = false);

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => AddEditAddressSheet(
          addressRef: _addressesRef!,
          prefillAddress: addressStr,
          prefillLatitude: pos.latitude,
          prefillLongitude: pos.longitude,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _fetchingLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unable to fetch location: $e')));
      }
    }
  }

  void _requestFromFriend() {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Coming soon')));
  }

  void _shareAddress(String label, String fullAddress) {
    Share.share('$label: $fullAddress');
  }

  Future<void> _setAsDefault(String docId) async {
    if (_addressesRef == null) return;
    try {
      final batch = catalogFirestore.batch();
      final snap = await _addressesRef!.get();
      for (final d in snap.docs) {
        batch.update(d.reference, {'isDefault': d.id == docId});
      }
      await batch.commit();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to set default: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = catalogAuth.currentUser;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: const AppBackButton.light(),
        title: const Text(
          'Select Location',
          style: TextStyle(
              color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: user == null || _addressesRef == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'You\'re not signed in. Please sign in to manage saved addresses.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[700], fontSize: 16),
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search Address',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF00B69B)),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    color: const Color(0xFFF5F5F7),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              ListTile(
                                leading: _fetchingLocation
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Icon(Icons.my_location,
                                        color: Color(0xFFE91E63)),
                                title: const Text(
                                  'Use my Current Location',
                                  style: TextStyle(
                                      color: Color(0xFFE91E63),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                ),
                                onTap: _fetchingLocation
                                    ? null
                                    : _useCurrentLocationDirect,
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.add,
                                    color: Color(0xFFE91E63)),
                                title: const Text(
                                  'Add New Address',
                                  style: TextStyle(
                                      color: Color(0xFFE91E63),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                ),
                                trailing: const Icon(Icons.chevron_right,
                                    color: Colors.black45),
                                onTap: () => _openAddEdit(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ListTile(
                            leading: const Icon(Icons.chat_bubble_outline,
                                color: Colors.green),
                            title: const Text(
                              'Request address from friend',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            trailing: const Icon(Icons.chevron_right,
                                color: Colors.black45),
                            onTap: _requestFromFriend,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Padding(
                          padding: EdgeInsets.only(left: 4, bottom: 8),
                          child: Text(
                            'Saved Addresses',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black87),
                          ),
                        ),
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: _addressesRef!
                              .orderBy('createdAt', descending: true)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 40),
                                child: Center(
                                    child: Text('Error: ${snapshot.error}')),
                              );
                            }
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 40),
                                child:
                                    Center(child: CircularProgressIndicator()),
                              );
                            }
                            var docs = snapshot.data?.docs ?? [];
                            docs.sort((a, b) {
                              final aDef =
                                  a.data()['isDefault'] == true;
                              final bDef =
                                  b.data()['isDefault'] == true;
                              if (aDef && !bDef) return -1;
                              if (!aDef && bDef) return 1;
                              return 0;
                            });
                            if (_searchQuery.isNotEmpty) {
                              docs = docs.where((doc) {
                                final data = doc.data();
                                final label = (data['label'] as String? ?? '')
                                    .toLowerCase();
                                final addr =
                                    (data['fullAddress'] as String? ?? '')
                                        .toLowerCase();
                                return label.contains(_searchQuery) ||
                                    addr.contains(_searchQuery);
                              }).toList();
                            }
                            if (docs.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 40),
                                child: Center(
                                    child: Text('No saved addresses found')),
                              );
                            }
                            return Column(
                              children: docs.map((doc) {
                                final data = doc.data();
                                final label =
                                    (data['label'] as String?) ?? 'Other';
                                final fullAddress =
                                    (data['fullAddress'] as String?) ?? '';
                                final isDefault = data['isDefault'] == true;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: isDefault
                                        ? Border.all(
                                            color: const Color(0xFF00B69B),
                                            width: 1.5)
                                        : null,
                                  ),
                                  child: InkWell(
                                    onTap: widget.selectMode
                                        ? () {
                                            Navigator.pop(context, {
                                              'id': doc.id,
                                              'label': label,
                                              'fullAddress': fullAddress,
                                              'latitude': data['latitude'],
                                              'longitude': data['longitude'],
                                            });
                                          }
                                        : () => _openAddEdit(doc: doc),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          label == 'Home'
                                              ? Icons.home_outlined
                                              : Icons.location_on_outlined,
                                          color: Colors.black87,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(label,
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 15)),
                                                  if (isDefault) ...[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                              horizontal: 6,
                                                              vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                            0xFF00B69B),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(4),
                                                      ),
                                                      child: const Text(
                                                          'DEFAULT',
                                                          style: TextStyle(
                                                              color: Colors
                                                                  .white,
                                                              fontSize: 9,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold)),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                fullAddress,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 13),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          children: [
                                            IconButton(
                                              onPressed: () => _shareAddress(
                                                  label, fullAddress),
                                              icon: const Icon(Icons.ios_share,
                                                  size: 20,
                                                  color: Colors.black54),
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                            ),
                                            const SizedBox(height: 8),
                                            PopupMenuButton<String>(
                                              padding: EdgeInsets.zero,
                                              icon: const Icon(Icons.more_vert,
                                                  size: 20,
                                                  color: Colors.black54),
                                              onSelected: (value) {
                                                if (value == 'edit') {
                                                  _openAddEdit(doc: doc);
                                                } else if (value == 'delete') {
                                                  _deleteAddress(doc.id);
                                                } else if (value ==
                                                    'setDefault') {
                                                  _setAsDefault(doc.id);
                                                }
                                              },
                                              itemBuilder: (context) => [
                                                const PopupMenuItem(
                                                    value: 'edit',
                                                    child: Text('Edit')),
                                                if (!isDefault)
                                                  const PopupMenuItem(
                                                      value: 'setDefault',
                                                      child: Text(
                                                          'Set as default')),
                                                const PopupMenuItem(
                                                    value: 'delete',
                                                    child: Text('Delete')),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
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

class AddEditAddressSheet extends StatefulWidget {
  final CollectionReference<Map<String, dynamic>> addressRef;
  final DocumentSnapshot<Map<String, dynamic>>? existing;
  final String? prefillAddress;
  final double? prefillLatitude;
  final double? prefillLongitude;

  const AddEditAddressSheet({
    super.key,
    required this.addressRef,
    this.existing,
    this.prefillAddress,
    this.prefillLatitude,
    this.prefillLongitude,
  });

  @override
  State<AddEditAddressSheet> createState() => _AddEditAddressSheetState();
}

class _AddEditAddressSheetState extends State<AddEditAddressSheet> {
  String _label = 'Home';
  final TextEditingController _addressController = TextEditingController();
  double? _latitude;
  double? _longitude;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final d = widget.existing!.data()!;
      _label = (d['label'] as String?) ?? 'Other';
      _addressController.text = (d['fullAddress'] as String?) ?? '';
      _latitude = (d['latitude'] as num?)?.toDouble();
      _longitude = (d['longitude'] as num?)?.toDouble();
    } else if (widget.prefillAddress != null) {
      _addressController.text = widget.prefillAddress!;
      _latitude = widget.prefillLatitude;
      _longitude = widget.prefillLongitude;
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Location permission is required to use current location')));
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition();
      String addressStr =
          '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';

      try {
        final uri = Uri.parse(
            'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${pos.latitude}&lon=${pos.longitude}');
        final res = await http.get(uri,
            headers: {'User-Agent': 'french-mobiles-app/1.0 (contact: none)'});
        if (res.statusCode == 200) {
          final Map<String, dynamic> j = jsonDecode(res.body);
          if (j['display_name'] is String &&
              (j['display_name'] as String).trim().isNotEmpty) {
            addressStr = j['display_name'] as String;
          }
        }
      } catch (_) {
        // network/geocoding failed — keep coordinate string as fallback
      }

      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
        _addressController.text = addressStr;
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unable to fetch location: $e')));
    }
  }

  Future<void> _save() async {
    final text = _addressController.text.trim();
    if (text.isEmpty) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Enter an address')));
      return;
    }
    setState(() => _saving = true);

    try {
      if (widget.existing == null) {
        final snapshot = await widget.addressRef.get();
        final first = snapshot.docs.isEmpty;
        await widget.addressRef.add({
          'label': _label,
          'fullAddress': text,
          'latitude': _latitude,
          'longitude': _longitude,
          'isDefault': first,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await widget.addressRef.doc(widget.existing!.id).update({
          'label': _label,
          'fullAddress': text,
          'latitude': _latitude,
          'longitude': _longitude,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save address: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add / Edit Address',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: ['Home', 'Office', 'Other'].map((label) {
                  final selected = _label == label;
                  return ChoiceChip(
                    label: Text(label),
                    selected: selected,
                    onSelected: (_) => setState(() => _label = label),
                    selectedColor: const Color(0xFF00B69B),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addressController,
                maxLines: 4,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter full address'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _useCurrentLocation,
                    icon:
                        const Icon(Icons.my_location, color: Color(0xFF00B69B)),
                    label: const Text('Use Current Location',
                        style: TextStyle(color: Color(0xFF00B69B))),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF00B69B))),
                  ),
                  const SizedBox(width: 8),
                  if (_latitude != null && _longitude != null)
                    Text(
                        '(${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)})',
                        style: const TextStyle(color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00B69B),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: _saving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PaymentMethodsPage extends StatelessWidget {
  const PaymentMethodsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kProfileSurface,
      appBar: AppBar(
        backgroundColor: kProfilePrimaryTheme,
        elevation: 0,
        title: const Text(
          'Payment Methods',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: const AppBackButton.dark(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader(title: 'SAVED UPI ACCOUNTS FOR INSTANT PAYOUT'),
          const SizedBox(height: 8),
          _buildPaymentCard(
            title: 'Google Pay / UPI',
            subtitle: 'alex.shopping@okaxis',
            icon: Icons.qr_code_scanner,
            isDefault: true,
          ),
          _buildPaymentCard(
            title: 'PhonePe UPI',
            subtitle: '9876543210@ybl',
            icon: Icons.account_balance_wallet_outlined,
            isDefault: false,
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'LINKED BANK ACCOUNTS'),
          const SizedBox(height: 8),
          _buildPaymentCard(
            title: 'HDFC Bank',
            subtitle: 'Account ending in •••• 4920',
            icon: Icons.account_balance,
            isDefault: false,
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: kProfilePrimaryTheme),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {},
            icon: const Icon(Icons.add_card, color: kProfilePrimaryTheme),
            label: const Text(
              'Add New Payout Method',
              style: TextStyle(
                  color: kProfilePrimaryTheme, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isDefault,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kProfileBorder),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: kProfilePrimaryTheme.withValues(alpha: 0.1),
          child: Icon(icon, color: kProfilePrimaryTheme, size: 20),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
        trailing: isDefault
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Text(
                  'PRIMARY',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : const Icon(Icons.more_vert, size: 20, color: Colors.grey),
      ),
    );
  }
}

class NotificationPreferencesPage extends StatefulWidget {
  const NotificationPreferencesPage({super.key});

  @override
  State<NotificationPreferencesPage> createState() =>
      _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState
    extends State<NotificationPreferencesPage> {
  bool orderUpdates = true;
  bool priceAlerts = true;
  bool promoOffers = false;
  bool whatsappUpdates = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kProfileSurface,
      appBar: AppBar(
        backgroundColor: kProfilePrimaryTheme,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: const AppBackButton.dark(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kProfileBorder),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  activeThumbColor: kProfilePrimaryTheme,
                  title: const Text(
                    'Order & Pickup Status',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Get live updates on agent assignment & instant payment',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  value: orderUpdates,
                  onChanged: (val) => setState(() => orderUpdates = val),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  activeThumbColor: kProfilePrimaryTheme,
                  title: const Text(
                    'Price Drop Alerts',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Notifications when trade-in values increase for wishlisted devices',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  value: priceAlerts,
                  onChanged: (val) => setState(() => priceAlerts = val),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  activeThumbColor: kProfilePrimaryTheme,
                  title: const Text(
                    'WhatsApp Notifications',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Receive pickup details & receipts directly on WhatsApp',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  value: whatsappUpdates,
                  onChanged: (val) => setState(() => whatsappUpdates = val),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  activeThumbColor: kProfilePrimaryTheme,
                  title: const Text(
                    'Promotions & Discounts',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Special bonus trade-in offers and seasonal coupons',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  value: promoOffers,
                  onChanged: (val) => setState(() => promoOffers = val),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PrivacySecurityPage extends StatefulWidget {
  const PrivacySecurityPage({super.key});

  @override
  State<PrivacySecurityPage> createState() => _PrivacySecurityPageState();
}

class _PrivacySecurityPageState extends State<PrivacySecurityPage> {
  bool biometrics = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kProfileSurface,
      appBar: AppBar(
        backgroundColor: kProfilePrimaryTheme,
        elevation: 0,
        title: const Text(
          'Privacy & Security',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: const AppBackButton.dark(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kProfileBorder),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_outline,
                      color: kProfilePrimaryTheme),
                  title: const Text(
                    'Change Password',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Update your login password regularly',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                const Divider(height: 1),
                SwitchListTile(
                  activeThumbColor: kProfilePrimaryTheme,
                  secondary: const Icon(Icons.fingerprint,
                      color: kProfilePrimaryTheme),
                  title: const Text(
                    'Biometric Lock',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Require FaceID / Fingerprint to open app',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  value: biometrics,
                  onChanged: (val) => setState(() => biometrics = val),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.shield_outlined,
                      color: kProfilePrimaryTheme),
                  title: const Text(
                    'Data & Privacy Policy',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Learn how we protect your device wipe verification data',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HelpCenterPage extends StatelessWidget {
  const HelpCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kProfileSurface,
      appBar: AppBar(
        backgroundColor: kProfilePrimaryTheme,
        elevation: 0,
        title: const Text(
          'Help Center',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: const AppBackButton.dark(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search for issues, orders, payments...',
              prefixIcon: const Icon(Icons.search, color: kProfilePrimaryTheme),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kProfileBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kProfileBorder),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'HELP CATEGORIES'),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              _buildHelpCategory(Icons.phone_android, 'Device Valuation',
                  kProfilePrimaryTheme),
              _buildHelpCategory(Icons.local_shipping, 'Pickup & Delivery',
                  kProfilePrimaryTheme),
              _buildHelpCategory(
                  Icons.payment, 'Instant Payments', kProfilePrimaryTheme),
              _buildHelpCategory(
                  Icons.security, 'Data Wipe Safety', kProfilePrimaryTheme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHelpCategory(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kProfileBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kProfileSurface,
      appBar: AppBar(
        backgroundColor: kProfilePrimaryTheme,
        elevation: 0,
        title: const Text(
          'About Us',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: const AppBackButton.dark(),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 40,
                backgroundColor: kProfilePrimaryTheme,
                child:
                    Icon(Icons.phonelink_setup, size: 40, color: Colors.white),
              ),
              const SizedBox(height: 16),
              const Text(
                'TradeIn Express',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const Text(
                'Version 2.4.0',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 24),
              const Text(
                'We are committed to providing seamless, instant doorstep device valuation, data security, and hassle-free phone trade-ins across India.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Color(0xFF64748B), height: 1.5, fontSize: 13),
              ),
              const SizedBox(height: 32),
              const Divider(),
              ListTile(
                title: const Text(
                  'Terms of Service',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () {},
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text(
                  'Privacy Policy',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}
