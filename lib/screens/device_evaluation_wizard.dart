import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../models/quote_breakdown.dart';
import '../shared/widgets/quote_breakdown_view.dart';

import '../shared/motion/motion.dart';
import '../shared/theme/app_colors.dart';
import '../shared/theme/app_text_styles.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/widgets.dart';
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
  static const List<String> _stepTitles = [
    'Screen condition',
    'Body & frame',
    'Battery health',
    'Functionality faults',
    'Accessories',
    'Lock status & payout',
  ];

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

  @override
  void initState() {
    super.initState();
    _loadDeductionRules();
  }

  /// The fraction of the base price a given option costs.
  double _fractionAt(List<Map<String, dynamic>> list, int index) {
    if (index < 0 || index >= list.length) return 0.0;
    final d = list[index]['deduction'];
    if (d is num) return d.toDouble();
    if (d is String) return double.tryParse(d) ?? 0.0;
    return 0.0;
  }

  /// One line for a chosen option, or null when it costs nothing.
  ///
  /// A zero-percent choice — a flawless screen, the box included — is the
  /// absence of a deduction, and listing it as "− ₹ 0" pads the table with
  /// rows that say nothing.
  QuoteLine? _lineFor(
    String category,
    List<Map<String, dynamic>> list,
    int index,
  ) {
    final fraction = _fractionAt(list, index);
    if (fraction <= 0) return null;

    return QuoteLine(
      category: category,
      choice: (list[index]['title'] ?? '').toString(),
      percent: (list[index]['percent'] as num?)?.round() ??
          (fraction * 100).round(),
      amount: (widget.basePrice * fraction).round(),
    );
  }

  /// The quote, itemised.
  ///
  /// Built from exactly the selections the payout is calculated from, so the
  /// lines shown and the figure paid can never disagree.
  QuoteBreakdown _buildQuote() {
    final lines = <QuoteLine>[];
    void add(QuoteLine? line) {
      if (line != null) lines.add(line);
    }

    add(_lineFor('Screen condition', _screenOptions, _selectedScreenIndex));
    add(_lineFor('Body & frame', _bodyOptions, _selectedBodyIndex));
    add(_lineFor('Battery health', _batteryOptions, _selectedBatteryIndex));
    for (final faultIndex in _selectedFaults) {
      add(_lineFor('Functionality fault', _faultOptions, faultIndex));
    }
    add(_lineFor('Accessories', _accessoryOptions, _selectedAccessoryIndex));
    add(_lineFor('Lock status', _lockOptions, _selectedLockIndex));

    var totalFraction = _fractionAt(_screenOptions, _selectedScreenIndex) +
        _fractionAt(_bodyOptions, _selectedBodyIndex) +
        _fractionAt(_batteryOptions, _selectedBatteryIndex) +
        _fractionAt(_accessoryOptions, _selectedAccessoryIndex) +
        _fractionAt(_lockOptions, _selectedLockIndex);
    for (final faultIndex in _selectedFaults) {
      totalFraction += _fractionAt(_faultOptions, faultIndex);
    }

    return QuoteBreakdown.from(
      basePrice: widget.basePrice,
      lines: lines,
      totalFraction: totalFraction,
    );
  }

  int _calculateFinalValuation() => _buildQuote().finalPayout;

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
          final rawOptions =
              (data != null && data['options'] is List) ? List.from(data['options']) : [];

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

            final percent = (deduction * 100).round();

            return {
              'title': label,
              'subtitle': '$percent% Deduction',
              'percent': percent,
              'deduction': deduction,
              'icon_url': iconUrl,
            };
          }).toList();

          results.add(mapped);
        } catch (_) {
          results.add([]);
        }
      }

      setState(() {
        _screenOptions = results.isNotEmpty ? results[0] : [];
        _bodyOptions = results.length > 1 ? results[1] : [];
        _batteryOptions = results.length > 2 ? results[2] : [];
        _faultOptions = results.length > 3 ? results[3] : [];
        _accessoryOptions = results.length > 4 ? results[4] : [];
        _lockOptions = results.length > 5 ? results[5] : [];

        // clamp selected indices to available lengths
        _selectedScreenIndex = _selectedScreenIndex.clamp(
            0, _screenOptions.isEmpty ? 0 : _screenOptions.length - 1);
        _selectedBodyIndex = _selectedBodyIndex.clamp(
            0, _bodyOptions.isEmpty ? 0 : _bodyOptions.length - 1);
        _selectedBatteryIndex = _selectedBatteryIndex.clamp(
            0, _batteryOptions.isEmpty ? 0 : _batteryOptions.length - 1);
        _selectedAccessoryIndex = _selectedAccessoryIndex.clamp(
            0, _accessoryOptions.isEmpty ? 0 : _accessoryOptions.length - 1);
        _selectedLockIndex = _selectedLockIndex.clamp(
            0, _lockOptions.isEmpty ? 0 : _lockOptions.length - 1);

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

  void _openCheckout() {
    // The quote is built once and carried, rather than recomputed at
    // checkout: two calculations of the same number is two chances for them
    // to differ, and the validity window has to start somewhere definite.
    context.pushScreen(PickupCheckoutPage(
          brandName: widget.brandName,
          modelDocId: widget.modelDocId,
          modelName: widget.modelName,
          imageUrl: widget.imageUrl,
          variant: widget.storage,
          basePrice: widget.basePrice,
          finalPayout: _calculateFinalValuation(),
          quote: _buildQuote(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLastStep = _currentStep == 5;

    return Theme(
      data: AppTheme.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenGutter,
                  AppSpacing.lg,
                  AppSpacing.screenGutter,
                  AppSpacing.lg,
                ),
                child: AppScreenHeader(
                  title: _stepTitles[_currentStep],
                  onBack: _prevStep,
                  trailing: AppBadge(
                    label: 'STEP ${_currentStep + 1}/6',
                    tone: AppBadgeTone.primary,
                  ),
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppStepProgress(total: 6, current: _currentStep),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        isLastStep
                            ? 'Review your final estimated cash payout'
                            : 'Select the options that apply to your device',
                        style: AppTextStyles.bodySmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [widget.modelName, widget.storage]
                            .where((s) => s.isNotEmpty)
                            .join(' · '),
                        style: AppTextStyles.label,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(child: _buildStepBody()),
            ],
          ),
        ),
        bottomNavigationBar: AppBottomBar(
          child: isLastStep ? _buildPayoutBar() : _buildContinueBar(),
        ),
      ),
    );
  }

  Widget _buildContinueBar() {
    return AppPrimaryButton(
      label: 'Continue',
      icon: Icons.arrow_forward_rounded,
      onPressed: _nextStep,
    );
  }

  Widget _buildPayoutBar() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Calculated value', style: AppTextStyles.caption),
              // Counts to the new figure so a changed selection is visibly
              // reflected in the payout rather than silently swapped.
              AppAnimatedCount(
                value: _calculateFinalValuation(),
                prefix: '₹ ',
                style: AppTextStyles.h1.copyWith(
                  color: AppColors.onPrimarySoft,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        AppPrimaryButton(
          label: 'Get paid',
          expand: false,
          onPressed: _openCheckout,
        ),
      ],
    );
  }

  Widget _buildStepBody() {
    if (_isLoadingOptions) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenGutter,
          0,
          AppSpacing.screenGutter,
          AppSpacing.xxl,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.95,
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
        ),
        itemCount: 4,
        itemBuilder: (_, __) =>
            const AppShimmer(width: double.infinity, height: double.infinity),
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
        return _buildFinalStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _emptyOptions() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenGutter),
      child: AppEmptyState(
        title: 'Options unavailable',
        message: 'We could not load the grading options for this step.',
        icon: Icons.rule_outlined,
        onRetry: _loadDeductionRules,
      ),
    );
  }

  /// The last step: the remaining question, then the arithmetic.
  ///
  /// The breakdown belongs here rather than only at checkout — this is where
  /// the seller first sees a number, and a number they cannot check is the
  /// one they stop trusting later.
  Widget _buildFinalStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        0,
        AppSpacing.screenGutter,
        AppSpacing.xxl,
      ),
      children: [
        _buildSingleSelectGrid(
          _lockOptions,
          _selectedLockIndex,
          (i) => setState(() => _selectedLockIndex = i),
          embedded: true,
        ),
        const SizedBox(height: AppSpacing.xxl),
        const AppSectionHeader(
          title: 'How we got to this price',
          subtitle: 'Every deduction, itemised',
        ),
        const SizedBox(height: AppSpacing.md),
        QuoteBreakdownView(breakdown: _buildQuote()),
      ],
    );
  }

  Widget _grid({
    required int itemCount,
    required IndexedWidgetBuilder builder,
    bool embedded = false,
  }) {
    return GridView.builder(
      // Embedded, the grid is one child of a scrolling column rather than the
      // scroller itself, so it must size to its content and not scroll.
      shrinkWrap: embedded,
      physics: embedded ? const NeverScrollableScrollPhysics() : null,
      padding: embedded
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(
              AppSpacing.screenGutter,
              0,
              AppSpacing.screenGutter,
              AppSpacing.xxl,
            ),
      itemCount: itemCount,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.95,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
      ),
      itemBuilder: (context, index) =>
          AppReveal(index: index, slots: 6, child: builder(context, index)),
    );
  }

  Widget _buildSingleSelectGrid(
    List<Map<String, dynamic>> items,
    int selectedIndex,
    void Function(int) onSelect, {
    bool embedded = false,
  }) {
    if (items.isEmpty) return _emptyOptions();

    return _grid(
      embedded: embedded,
      itemCount: items.length,
      builder: (context, index) {
        final item = items[index];
        return AppOptionCard(
          title: (item['title'] ?? '').toString(),
          subtitle: (item['subtitle'] ??
                  (item['percent'] != null
                      ? '${item['percent']}% Deduction'
                      : ''))
              .toString(),
          iconUrl: (item['icon_url'] ?? '').toString(),
          selected: selectedIndex == index,
          onTap: () => onSelect(index),
        );
      },
    );
  }

  Widget _buildMultiSelectGrid() {
    if (_faultOptions.isEmpty) return _emptyOptions();

    return _grid(
      itemCount: _faultOptions.length,
      builder: (context, index) {
        final item = _faultOptions[index];
        final isSelected = _selectedFaults.contains(index);

        return AppOptionCard(
          title: (item['title'] ?? '').toString(),
          subtitle: (item['subtitle'] ??
                  (item['percent'] != null
                      ? '${item['percent']}% Deduction'
                      : ''))
              .toString(),
          iconUrl: (item['icon_url'] ?? '').toString(),
          fallbackIcon: Icons.build_outlined,
          selected: isSelected,
          multiSelect: true,
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
}
