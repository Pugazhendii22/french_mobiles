import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'pickup_checkout_page.dart';

class DeviceEvaluationWizard extends StatefulWidget {
  final String brandName;
  final String modelDocId;
  final String modelName;
  final String? imageUrl;
  final int basePrice;
  final String storage;

  const DeviceEvaluationWizard({
    super.key,
    required this.brandName,
    required this.modelDocId,
    required this.modelName,
    this.imageUrl,
    required this.basePrice,
    required this.storage,
  });

  @override
  State<DeviceEvaluationWizard> createState() => _DeviceEvaluationWizardState();
}

class _DeviceEvaluationWizardState extends State<DeviceEvaluationWizard> {
  int _currentStep = 0;

  int _selectedScreenIndex = 0;
  int _selectedBodyIndex = 0;
  int _selectedBatteryIndex = 0;
  final Set<int> _selectedFaults = {};
  int _selectedAccessoryIndex = 0;
  int _selectedLockIndex = 0;
  List<Map<String, dynamic>> _screenOptions = [];
  List<Map<String, dynamic>> _bodyOptions = [];
  List<Map<String, dynamic>> _batteryOptions = [];
  List<Map<String, dynamic>> _faultOptions = [];
  List<Map<String, dynamic>> _accessoryOptions = [];
  List<Map<String, dynamic>> _lockOptions = [];

  bool _isLoadingOptions = true;

  FirebaseFirestore get _catalogFirestore =>
      FirebaseFirestore.instanceFor(app: Firebase.app('catalogApp'));

  int _calculateFinalValuation() {
    double totalDeduction = 0.0;

    double safeLookup(List<Map<String, dynamic>> list, int index) {
      if (index >= 0 && index < list.length) {
        final d = list[index]['deduction'];
        if (d is num) return d.toDouble();
        if (d is String) return double.tryParse(d) ?? 0.0;
      }
      return 0.0;
    }

    totalDeduction += safeLookup(_screenOptions, _selectedScreenIndex);
    totalDeduction += safeLookup(_bodyOptions, _selectedBodyIndex);
    totalDeduction += safeLookup(_batteryOptions, _selectedBatteryIndex);

    for (int faultIndex in _selectedFaults) {
      totalDeduction += safeLookup(_faultOptions, faultIndex);
    }

    totalDeduction += safeLookup(_accessoryOptions, _selectedAccessoryIndex);
    totalDeduction += safeLookup(_lockOptions, _selectedLockIndex);

    double remainingFactor = 1.0 - totalDeduction;
    if (remainingFactor < 0.10) remainingFactor = 0.10;

    return (widget.basePrice * remainingFactor).round();
  }

  void _nextStep() {
    if (_currentStep < 5) {
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadDeductionRules();
  }

  @override
  Widget build(BuildContext context) {
    final String stepTitle = [
      '1. Screen Condition',
      '2. Body / Frame Condition',
      '3. Battery Health',
      '4. Functionality Faults',
      '5. Accessories / Completeness',
      '6. Lock Status & Payout',
    ][_currentStep];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: _prevStep,
        ),
        title: Text(
          stepTitle,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: Column(
              children: [
                Text(
                  _currentStep < 5
                      ? 'Select options that apply to your device'
                      : 'Review your final estimated cash payout',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.modelName,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildStepGrid(),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: SafeArea(
              child: _currentStep < 5
                  ? SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _nextStep,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00B69B),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                          ],
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'CALCULATED VALUE',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '₹${_calculateFinalValuation()}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PickupCheckoutPage(
                                        brandName: widget.brandName,
                                        modelDocId: widget.modelDocId,
                                        modelName: widget.modelName,
                                        imageUrl: widget.imageUrl,
                                        variant: widget.storage,
                                        basePrice: widget.basePrice,
                                        finalPayout: _calculateFinalValuation(),
                                      ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00B69B),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: const Text(
                              'Get Paid',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
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

  Widget _buildStepGrid() {
    if (_isLoadingOptions) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00B69B)),
        ),
      );
    }
    switch (_currentStep) {
      case 0:
        return _buildSingleSelectGrid(
          _screenOptions,
          _selectedScreenIndex,
          (i) => setState(() => _selectedScreenIndex = i),
        );
      case 1:
        return _buildSingleSelectGrid(
          _bodyOptions,
          _selectedBodyIndex,
          (i) => setState(() => _selectedBodyIndex = i),
        );
      case 2:
        return _buildSingleSelectGrid(
          _batteryOptions,
          _selectedBatteryIndex,
          (i) => setState(() => _selectedBatteryIndex = i),
        );
      case 3:
        return _buildMultiSelectGrid();
      case 4:
        return _buildSingleSelectGrid(
          _accessoryOptions,
          _selectedAccessoryIndex,
          (i) => setState(() => _selectedAccessoryIndex = i),
        );
      case 5:
        return _buildSingleSelectGrid(
          _lockOptions,
          _selectedLockIndex,
          (i) => setState(() => _selectedLockIndex = i),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSingleSelectGrid(
    List<Map<String, dynamic>> items,
    int selectedIndex,
    Function(int) onSelect,
  ) {
    return GridView.builder(
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.95,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = selectedIndex == index;

        return _buildGridTile(
          title: item['title'] ?? '',
          subtitle: item['subtitle'] ?? (item['percent'] != null ? '${item['percent'].toString()}% Deduction' : ''),
          icon: item['icon_url'] ?? '',
          isSelected: isSelected,
          onTap: () => onSelect(index),
        );
      },
    );
  }

  Widget _buildMultiSelectGrid() {
    return GridView.builder(
      itemCount: _faultOptions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.95,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemBuilder: (context, index) {
        final item = _faultOptions[index];
        final isSelected = _selectedFaults.contains(index);

        return _buildGridTile(
          title: item['title'] ?? '',
          subtitle: item['subtitle'] ?? (item['percent'] != null ? '${item['percent'].toString()}% Deduction' : ''),
          icon: item['icon_url'] ?? '',
          isSelected: isSelected,
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedFaults.remove(index);
              } else {
                _selectedFaults.add(index);
              }
            });
          },
        );
      },
    );
  }

  Widget _buildGridTile({
    required String title,
    required String subtitle,
    required dynamic icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE6F8F5) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF00B69B) : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: (() {
                  if (icon is String && icon.isNotEmpty) {
                    return Image.network(
                      icon,
                      width: 42,
                      height: 42,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00B69B)),
                          ),
                        );
                      },
                    );
                  }

                  if (icon is IconData) {
                    return Icon(
                      icon,
                      size: 42,
                      color: isSelected ? const Color(0xFF00B69B) : Colors.grey.shade400,
                    );
                  }

                  return const SizedBox.shrink();
                })(),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFD0F2EC) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(11),
                  bottomRight: Radius.circular(11),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? const Color(0xFF007A68) : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadDeductionRules() async {
    setState(() {
      _isLoadingOptions = true;
    });

    try {
      final ids = [
        'screen_condition',
        'body_condition',
        'battery_health',
        'functionality_faults',
        'accessories',
        'lock_status',
      ];

      final col = _catalogFirestore.collection('deduction_rules');
      final results = <List<Map<String, dynamic>>>[];

      for (final id in ids) {
        try {
          final doc = await col.doc(id).get();
          final data = doc.data();
          final rawOptions = (data != null && data['options'] is List) ? List.from(data['options']) : [];

          final mapped = rawOptions.map<Map<String, dynamic>>((o) {
            final label = (o['label'] ?? '').toString();
            final iconUrl = (o['icon_url'] ?? '').toString().trim();
            double deduction = 0.0;
            // Firestore stores whole-number percent (e.g. 30 meaning 30%).
            if (o['percent'] is num) {
              deduction = (o['percent'] as num).toDouble() / 100.0;
            } else if (o['percent'] is String) {
              deduction = (double.tryParse(o['percent']) ?? 0.0) / 100.0;
            }

            final percentDisplay = ((deduction * 100).round()).toString();

            return {
              'title': label,
              'subtitle': '%s' /* placeholder */,
              'percent': (deduction * 100).round(),
              'deduction': deduction,
              'icon_url': iconUrl,
            }..update('subtitle', (v) => '$percentDisplay% Deduction');
          }).toList();

          results.add(mapped);
        } catch (_) {
          results.add([]);
        }
      }

      setState(() {
        _screenOptions = results.length > 0 ? results[0] : [];
        _bodyOptions = results.length > 1 ? results[1] : [];
        _batteryOptions = results.length > 2 ? results[2] : [];
        _faultOptions = results.length > 3 ? results[3] : [];
        _accessoryOptions = results.length > 4 ? results[4] : [];
        _lockOptions = results.length > 5 ? results[5] : [];

        // clamp selected indices to available lengths
        _selectedScreenIndex = _selectedScreenIndex.clamp(0, _screenOptions.isEmpty ? 0 : _screenOptions.length - 1);
        _selectedBodyIndex = _selectedBodyIndex.clamp(0, _bodyOptions.isEmpty ? 0 : _bodyOptions.length - 1);
        _selectedBatteryIndex = _selectedBatteryIndex.clamp(0, _batteryOptions.isEmpty ? 0 : _batteryOptions.length - 1);
        _selectedAccessoryIndex = _selectedAccessoryIndex.clamp(0, _accessoryOptions.isEmpty ? 0 : _accessoryOptions.length - 1);
        _selectedLockIndex = _selectedLockIndex.clamp(0, _lockOptions.isEmpty ? 0 : _lockOptions.length - 1);

        // remove selected faults outside range
        _selectedFaults.retainWhere((i) => i >= 0 && i < _faultOptions.length);
      });
    } catch (e) {
      setState(() {
        _screenOptions = [];
        _bodyOptions = [];
        _batteryOptions = [];
        _faultOptions = [];
        _accessoryOptions = [];
        _lockOptions = [];
      });
    } finally {
      setState(() {
        _isLoadingOptions = false;
      });
    }
  }
}
