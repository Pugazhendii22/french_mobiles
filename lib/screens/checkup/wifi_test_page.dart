import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_scan/wifi_scan.dart';

import '../../models/checkup_result.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/widgets.dart';

/// Test 4 — Wi-Fi.
///
/// Requests the permissions Wi-Fi scanning needs, prompts to turn on Location service
/// via native location dialog if off, then performs a scan. Passes when at least
/// one nearby network is found. Auto-advances result.
class WifiTestPage extends StatefulWidget {
  const WifiTestPage({super.key});

  @override
  State<WifiTestPage> createState() => _WifiTestPageState();
}

class _WifiTestPageState extends State<WifiTestPage>
    with WidgetsBindingObserver {
  final List<WiFiAccessPoint> _networks = [];
  bool _scanning = false;
  bool _isPermanentlyDenied = false;
  bool _awaitingLocationSettings = false;
  String _statusText = 'Preparing Wi-Fi scan…';
  CheckupResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _run();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingLocationSettings) {
      _awaitingLocationSettings = false;
      _resumeAfterLocationSettings();
    }
  }

  Future<void> _run() async {
    if (!mounted) return;
    setState(() {
      _scanning = true;
      _statusText = 'Checking Wi-Fi permissions…';
    });

    final nearby = await Permission.nearbyWifiDevices.request();
    if (!mounted) return;
    if (nearby.isPermanentlyDenied) {
      setState(() => _isPermanentlyDenied = true);
      _setResult(const CheckupResult(
        key: 'wifi',
        title: 'Wi-Fi',
        status: CheckupStatus.skipped,
        detail: 'Nearby Wi-Fi permission is permanently denied. Open Settings to grant.',
      ));
      return;
    }
    if (!nearby.isGranted) {
      _setResult(const CheckupResult(
        key: 'wifi',
        title: 'Wi-Fi',
        status: CheckupStatus.skipped,
        detail: 'Nearby device (Wi-Fi) permission was denied.',
      ));
      return;
    }

    final location = await Permission.location.request();
    if (!mounted) return;
    if (location.isPermanentlyDenied) {
      setState(() => _isPermanentlyDenied = true);
      _setResult(const CheckupResult(
        key: 'wifi',
        title: 'Wi-Fi',
        status: CheckupStatus.skipped,
        detail: 'Location permission is permanently denied. Open Settings to grant.',
      ));
      return;
    }
    if (!location.isGranted) {
      _setResult(const CheckupResult(
        key: 'wifi',
        title: 'Wi-Fi',
        status: CheckupStatus.skipped,
        detail: 'Location permission needed for Wi-Fi scanning was not granted.',
      ));
      return;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _awaitingLocationSettings = true;
      await Geolocator.openLocationSettings();
      return;
    }

    await _startScan();
  }

  Future<void> _resumeAfterLocationSettings() async {
    if (!mounted) return;
    setState(() {
      _scanning = true;
      _statusText = 'Checking location status…';
    });
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!mounted) return;
    if (!serviceEnabled) {
      _setResult(const CheckupResult(
        key: 'wifi',
        title: 'Wi-Fi',
        status: CheckupStatus.skipped,
        detail:
            'Location services are switched off — turn them on to scan for Wi-Fi.',
      ));
      return;
    }
    await _startScan();
  }

  Future<void> _startScan() async {
    if (!mounted) return;

    final can = await WiFiScan.instance.canStartScan(askPermissions: true);
    if (!mounted) return;
    switch (can) {
      case CanStartScan.yes:
        break;
      case CanStartScan.noLocationServiceDisabled:
        _setResult(const CheckupResult(
          key: 'wifi',
          title: 'Wi-Fi',
          status: CheckupStatus.skipped,
          detail: 'Location services must be on for a Wi-Fi scan.',
        ));
        return;
      case CanStartScan.noLocationPermissionRequired:
      case CanStartScan.noLocationPermissionDenied:
      case CanStartScan.noLocationPermissionUpgradeAccuracy:
        _setResult(const CheckupResult(
          key: 'wifi',
          title: 'Wi-Fi',
          status: CheckupStatus.skipped,
          detail: 'Location permission needed for Wi-Fi scanning was not granted.',
        ));
        return;
      case CanStartScan.notSupported:
        _setResult(const CheckupResult(
          key: 'wifi',
          title: 'Wi-Fi',
          status: CheckupStatus.skipped,
          detail: 'Wi-Fi scanning is not supported on this device.',
        ));
        return;
      case CanStartScan.failed:
        _setResult(const CheckupResult(
          key: 'wifi',
          title: 'Wi-Fi',
          status: CheckupStatus.fail,
          detail: 'Could not start a Wi-Fi scan.',
        ));
        return;
    }

    setState(() {
      _scanning = true;
      _statusText = 'Scanning for nearby networks…';
    });

    try {
      final scanning = await WiFiScan.instance.startScan();
      if (!scanning) {
        _setResult(const CheckupResult(
          key: 'wifi',
          title: 'Wi-Fi',
          status: CheckupStatus.fail,
          detail: 'The Wi-Fi radio did not start a scan.',
        ));
        return;
      }

      List<WiFiAccessPoint> found = const [];
      for (var i = 0; i < 12; i++) {
        try {
          found = await WiFiScan.instance.getScannedResults();
        } catch (_) {}
        if (found.isNotEmpty) break;
        await Future<void>.delayed(const Duration(milliseconds: 800));
      }

      setState(() {
        _networks
          ..clear()
          ..addAll(found);
        _scanning = false;
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      final message = e.message?.toLowerCase() ?? e.code.toLowerCase();
      if (message.contains('location') || message.contains('accesspoint')) {
        _setResult(const CheckupResult(
          key: 'wifi',
          title: 'Wi-Fi',
          status: CheckupStatus.skipped,
          detail: 'Location services off — required for a Wi-Fi scan.',
        ));
        return;
      }
      if (message.contains('permission') || message.contains('security')) {
        _setResult(const CheckupResult(
          key: 'wifi',
          title: 'Wi-Fi',
          status: CheckupStatus.skipped,
          detail: 'Permission for Wi-Fi scanning was not granted.',
        ));
        return;
      }
      _setResult(CheckupResult(
        key: 'wifi',
        title: 'Wi-Fi',
        status: CheckupStatus.fail,
        detail: 'Wi-Fi scan failed: ${e.message ?? e.code}',
      ));
      return;
    } catch (e) {
      if (!mounted) return;
      _setResult(CheckupResult(
        key: 'wifi',
        title: 'Wi-Fi',
        status: CheckupStatus.fail,
        detail: 'Wi-Fi scan failed: $e',
      ));
      return;
    }

    if (!mounted) return;
    if (_networks.isNotEmpty) {
      final strongest = _networks
          .where((n) => n.ssid.isNotEmpty)
          .toList()
        ..sort((a, b) => b.level.compareTo(a.level));
      final name = strongest.isNotEmpty ? strongest.first.ssid : null;
      _setResult(CheckupResult(
        key: 'wifi',
        title: 'Wi-Fi',
        status: CheckupStatus.pass,
        detail: 'Found ${_networks.length} network(s)'
            '${name != null ? ', closest: $name' : ''}',
      ));
    } else {
      _setResult(const CheckupResult(
        key: 'wifi',
        title: 'Wi-Fi',
        status: CheckupStatus.fail,
        detail: 'Scan completed but no networks were found.',
      ));
    }
  }

  void _setResult(CheckupResult result) {
    if (!mounted) return;
    setState(() => _result = result);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.of(context).pop(_result);
      }
    });
  }

  void _skipTest() {
    Navigator.of(context).pop(
      const CheckupResult(
        key: 'wifi',
        title: 'Wi-Fi',
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
            child: AppScreenHeader(title: 'Checkup · Wi-Fi'),
          ),
          Expanded(child: _result != null ? _verdictView() : _testView()),
        ],
      ),
    );
  }

  Widget _testView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.card,
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              if (_scanning)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                )
              else
                const Icon(Icons.wifi, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _statusText,
                  style: AppTextStyles.body.copyWith(
                      fontSize: 13.5, height: 1.4, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        if (_networks.isNotEmpty) ...[
          const SizedBox(height: 16),
          for (final network in _networks.take(6))
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              dense: true,
              leading: const Icon(Icons.wifi, color: AppColors.textSecondary),
              title: Text(
                network.ssid.isEmpty ? '(hidden network)' : network.ssid,
                style: AppTextStyles.body.copyWith(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              ),
              trailing: Text(
                '${network.level} dBm',
                style: AppTextStyles.body.copyWith(
                    color: AppColors.textTertiary, fontSize: 12),
              ),
            ),
        ],
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: _skipTest,
            child: Text('Skip this test',
                style: AppTextStyles.body.copyWith(color: AppColors.textTertiary)),
          ),
        ),
      ],
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