import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:sim_data/sim_data.dart';

import '../../models/checkup_result.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/widgets.dart';

/// Test 7 — Mobile network.
///
/// Reads SIM presence + carrier name via the sim_data plugin, then confirms the
/// device currently has a working route to the internet with a lightweight
/// HTTP probe. Auto-advances verdict.
class NetworkTestPage extends StatefulWidget {
  const NetworkTestPage({super.key});

  @override
  State<NetworkTestPage> createState() => _NetworkTestPageState();
}

class _NetworkTestPageState extends State<NetworkTestPage> {
  bool _busy = true;
  bool _isPermanentlyDenied = false;
  String _statusText = 'Reading SIM state…';
  CheckupResult? _result;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final phone = await Permission.phone.request();
    if (!mounted) return;
    if (phone.isPermanentlyDenied) {
      setState(() => _isPermanentlyDenied = true);
      _setResult(const CheckupResult(
        key: 'network',
        title: 'Mobile network',
        status: CheckupStatus.skipped,
        detail: 'Phone state permission is permanently denied. Open Settings to grant.',
      ));
      return;
    }
    if (!phone.isGranted) {
      _setResult(const CheckupResult(
        key: 'network',
        title: 'Mobile network',
        status: CheckupStatus.skipped,
        detail: 'Phone state permission was not granted.',
      ));
      return;
    }

    String? carrier;
    bool hasSim = false;
    try {
      final simData = await SimDataPlugin.getSimData();
      if (simData.cards.isNotEmpty) {
        hasSim = true;
        final card = simData.cards.first;
        carrier = card.carrierName.isEmpty ? card.displayName : card.carrierName;
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      _setResult(CheckupResult(
        key: 'network',
        title: 'Mobile network',
        status: CheckupStatus.skipped,
        detail: 'Could not read SIM state (sim_data error: ${e.message ?? e.code})',
      ));
      return;
    } catch (e) {
      if (!mounted) return;
      _setResult(CheckupResult(
        key: 'network',
        title: 'Mobile network',
        status: CheckupStatus.skipped,
        detail: 'Could not read SIM state: $e',
      ));
      return;
    }

    if (!mounted) return;
    if (!hasSim) {
      _setResult(const CheckupResult(
        key: 'network',
        title: 'Mobile network',
        status: CheckupStatus.skipped,
        detail: 'No SIM card detected on this device.',
      ));
      return;
    }

    setState(() => _statusText = 'Checking mobile data route…');

    final connectivity = Connectivity();
    final types = await connectivity.checkConnectivity();
    final hasNetwork = types.isNotEmpty &&
        !types.every((t) => t == ConnectivityResult.none);

    final routeWorks = await _probeInternet();
    if (!mounted) return;

    if (!hasNetwork) {
      _setResult(const CheckupResult(
        key: 'network',
        title: 'Mobile network',
        status: CheckupStatus.fail,
        detail: 'No active network connection detected.',
      ));
      return;
    }

    if (routeWorks) {
      final carrierLabel = (carrier == null || carrier.isEmpty)
          ? 'carrier name unavailable'
          : 'carrier: $carrier';
      _setResult(CheckupResult(
        key: 'network',
        title: 'Mobile network',
        status: CheckupStatus.pass,
        detail: 'SIM detected ($carrierLabel), mobile data route works.',
      ));
    } else {
      _setResult(const CheckupResult(
        key: 'network',
        title: 'Mobile network',
        status: CheckupStatus.fail,
        detail: 'SIM detected but the data route could not reach the internet.',
      ));
    }
  }

  Future<bool> _probeInternet() async {
    try {
      final response = await http
          .get(Uri.parse('https://connectivitycheck.gstatic.com/generate_204'))
          .timeout(const Duration(seconds: 10));
      return response.statusCode >= 200 && response.statusCode < 400;
    } catch (_) {
      return false;
    }
  }

  void _setResult(CheckupResult result) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = result;
    });
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.of(context).pop(_result);
      }
    });
  }

  void _skipTest() {
    Navigator.of(context).pop(
      const CheckupResult(
        key: 'network',
        title: 'Mobile network',
        status: CheckupStatus.skipped,
        detail: 'Skipped by user',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(AppSpacing.screenGutter,
                AppSpacing.lg, AppSpacing.screenGutter, AppSpacing.lg),
            child: AppScreenHeader(title: 'Checkup · Mobile network'),
          ),
          Expanded(child: _result != null ? _verdictView() : _testView()),
        ],
      ),
    );
  }

  Widget _testView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_busy)
              const CircularProgressIndicator(color: AppColors.primary)
            else
              const Icon(Icons.signal_cellular_alt,
                  size: 56, color: AppColors.primary),
            const SizedBox(height: 20),
            Text(
              _statusText,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                  fontSize: 14, height: 1.45, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: _skipTest,
              child: Text('Skip this test',
                  style: AppTextStyles.body.copyWith(color: AppColors.textTertiary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _verdictView() {
    final r = _result!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(r.status.icon, color: r.status.color, size: 64),
            const SizedBox(height: 14),
            Text(
              r.status.label,
              style: AppTextStyles.body.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: r.status.color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              r.detail ?? '',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(fontSize: 14, color: AppColors.textSecondary),
            ),
            if (_isPermanentlyDenied) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                ),
                onPressed: () => openAppSettings(),
                icon: const Icon(Icons.settings),
                label: Text('Open Settings', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}