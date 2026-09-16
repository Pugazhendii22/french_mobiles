import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../models/checkup_result.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

/// Test 5 — Bluetooth.
///
/// Ensures the Bluetooth radio is on and performs a short scan. Passes when
/// scan completes without error. Auto-advances verdict.
class BluetoothTestPage extends StatefulWidget {
  const BluetoothTestPage({super.key});

  @override
  State<BluetoothTestPage> createState() => _BluetoothTestPageState();
}

class _BluetoothTestPageState extends State<BluetoothTestPage> {
  bool _scanning = false;
  bool _isPermanentlyDenied = false;
  List<ScanResult> _devices = [];
  String _statusText = 'Requesting Bluetooth access…';
  CheckupResult? _result;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final scanPerm = await Permission.bluetoothScan.request();
    final connectPerm = await Permission.bluetoothConnect.request();
    final locationPerm = await Permission.location.request();

    if (!mounted) return;

    if (scanPerm.isPermanentlyDenied || connectPerm.isPermanentlyDenied || locationPerm.isPermanentlyDenied) {
      setState(() => _isPermanentlyDenied = true);
      _setResult(const CheckupResult(
        key: 'bluetooth',
        title: 'Bluetooth',
        status: CheckupStatus.skipped,
        detail: 'Bluetooth/Location permission is permanently denied. Open Settings to grant.',
      ));
      return;
    }

    if (!scanPerm.isGranted && !connectPerm.isGranted && !locationPerm.isGranted) {
      _setResult(const CheckupResult(
        key: 'bluetooth',
        title: 'Bluetooth',
        status: CheckupStatus.skipped,
        detail: 'Bluetooth permission was not granted.',
      ));
      return;
    }

    setState(() {
      _scanning = true;
      _statusText = 'Turning Bluetooth radio on…';
    });

    try {
      final state = await FlutterBluePlus.adapterState
          .first
          .timeout(const Duration(seconds: 10));
      if (state != BluetoothAdapterState.on) {
        try {
          await FlutterBluePlus.turnOn().timeout(const Duration(seconds: 20));
        } catch (_) {
          if (!mounted) return;
          _setResult(const CheckupResult(
            key: 'bluetooth',
            title: 'Bluetooth',
            status: CheckupStatus.skipped,
            detail: 'Bluetooth could not be enabled (system prompt declined).',
          ));
          return;
        }
        await FlutterBluePlus.adapterState
            .firstWhere((s) => s == BluetoothAdapterState.on)
            .timeout(const Duration(seconds: 10));
      }

      if (!mounted) return;
      setState(() => _statusText = 'Scanning for nearby Bluetooth devices…');

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      final found = await FlutterBluePlus.scanResults
          .firstWhere((list) => list.isNotEmpty)
          .timeout(const Duration(seconds: 12), onTimeout: () => <ScanResult>[]);
      await FlutterBluePlus.stopScan();

      if (!mounted) return;
      setState(() {
        _devices = found;
        _scanning = false;
      });
      if (found.isNotEmpty) {
        _setResult(CheckupResult(
          key: 'bluetooth',
          title: 'Bluetooth',
          status: CheckupStatus.pass,
          detail: 'Bluetooth radio works — ${found.length} device(s) found',
        ));
      } else {
        _setResult(const CheckupResult(
          key: 'bluetooth',
          title: 'Bluetooth',
          status: CheckupStatus.pass,
          detail: 'Bluetooth radio works — scan completed (no devices nearby)',
        ));
      }
    } catch (e) {
      if (!mounted) return;
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
      _setResult(CheckupResult(
        key: 'bluetooth',
        title: 'Bluetooth',
        status: CheckupStatus.fail,
        detail: 'Bluetooth test failed: $e',
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
        key: 'bluetooth',
        title: 'Bluetooth',
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
          const AppGradientHeader(title: 'Checkup · Bluetooth'),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              if (_scanning)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF32CD32)),
                )
              else
                const Icon(Icons.bluetooth, color: Color(0xFF32CD32)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _statusText,
                  style: const TextStyle(
                      fontSize: 13.5, height: 1.4, color: Color(0xFF475569)),
                ),
              ),
            ],
          ),
        ),
        if (_devices.isNotEmpty) ...[
          const SizedBox(height: 16),
          for (final result in _devices.take(8))
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              dense: true,
              leading: const Icon(Icons.bluetooth, color: Color(0xFF64748B)),
              title: Text(
                result.device.platformName.isEmpty
                    ? result.device.advName.isEmpty
                        ? result.device.remoteId.str
                        : result.device.advName
                    : result.device.platformName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A)),
              ),
            ),
        ],
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: _skipTest,
            child: const Text('Skip this test',
                style: TextStyle(color: Color(0xFF94A3B8))),
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
              style: TextStyle(
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
              style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
            ),
            if (_isPermanentlyDenied) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF32CD32),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                ),
                onPressed: () => openAppSettings(),
                icon: const Icon(Icons.settings),
                label: const Text('Open Settings', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}