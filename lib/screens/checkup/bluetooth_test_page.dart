import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../models/checkup_result.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_text_styles.dart';
import 'checkup_test_shell.dart';

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
      ), hold: true);
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

  /// Records the verdict and pops back to the orchestrator.
  ///
  /// [hold] keeps the page open instead: for a verdict the user can act on,
  /// such as a permanently denied permission, popping after a second and a
  /// half would take the only remaining control away with it.
  void _setResult(CheckupResult result, {bool hold = false}) {
    if (!mounted) return;
    setState(() => _result = result);
    if (hold) return;
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
    return CheckupTestShell(
      title: 'Bluetooth',
      child: _result != null ? _verdictView() : _testView(),
    );
  }

  Widget _testView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CheckupInstruction(
          icon: Icons.bluetooth,
          busy: _scanning,
          text: _statusText,
        ),
        if (_devices.isNotEmpty) ...[
          const SizedBox(height: 16),
          for (final result in _devices.take(8))
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              dense: true,
              leading: const Icon(Icons.bluetooth, color: AppColors.textSecondary),
              title: Text(
                result.device.platformName.isEmpty
                    ? result.device.advName.isEmpty
                        ? result.device.remoteId.str
                        : result.device.advName
                    : result.device.platformName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMedium,
              ),
            ),
        ],
        const SizedBox(height: 16),
        CheckupSkipButton(onSkip: _skipTest),
      ],
    );
  }

  Widget _verdictView() {
    return CheckupVerdict(
      result: _result!,
      // Only a permanently denied permission leaves the user something to do
      // here; every other verdict is read-only and pops on its own.
      action: _isPermanentlyDenied
          ? CheckupPermissionAction(
              onOpenSettings: openAppSettings,
              onContinue: () => Navigator.of(context).pop(_result),
            )
          : null,
    );
  }
}