import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../models/checkup_result.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_text_styles.dart';
import 'checkup_test_shell.dart';

/// Test 8 — Location (GPS).
///
/// Requests location permission, verifies location services are on, then tries
/// to acquire a real GPS fix within ~15 seconds. Passes on GPS fix. Auto-advances verdict.
class LocationTestPage extends StatefulWidget {
  const LocationTestPage({super.key});

  @override
  State<LocationTestPage> createState() => _LocationTestPageState();
}

class _LocationTestPageState extends State<LocationTestPage> {
  bool _busy = true;
  bool _isPermanentlyDenied = false;
  String _statusText = 'Checking location permission…';
  CheckupResult? _result;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final status = await Permission.location.request();
    if (!mounted) return;
    if (status.isPermanentlyDenied) {
      setState(() => _isPermanentlyDenied = true);
      _setResult(const CheckupResult(
        key: 'location',
        title: 'Location (GPS)',
        status: CheckupStatus.skipped,
        detail: 'Location permission is permanently denied. Open Settings to grant.',
      ), hold: true);
      return;
    }
    if (!status.isGranted) {
      _setResult(const CheckupResult(
        key: 'location',
        title: 'Location (GPS)',
        status: CheckupStatus.skipped,
        detail: 'Location permission was denied.',
      ));
      return;
    }

    if (!mounted) return;
    setState(() => _statusText = 'Checking location services…');
    final servicesEnabled = await Geolocator.isLocationServiceEnabled();
    if (!mounted) return;
    if (!servicesEnabled) {
      _setResult(const CheckupResult(
        key: 'location',
        title: 'Location (GPS)',
        status: CheckupStatus.skipped,
        detail: 'Location services are switched off — turn them on for a GPS fix.',
      ));
      return;
    }

    if (!mounted) return;
    setState(() => _statusText = 'Waiting for a GPS fix…');
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      final accuracy = position.accuracy > 0
          ? '${position.accuracy.toStringAsFixed(0)} m'
          : 'unknown';
      _setResult(CheckupResult(
        key: 'location',
        title: 'Location (GPS)',
        status: CheckupStatus.pass,
        detail: 'GPS fix acquired (accuracy ~$accuracy)',
      ));
    } on TimeoutException {
      if (!mounted) return;
      _setResult(const CheckupResult(
        key: 'location',
        title: 'Location (GPS)',
        status: CheckupStatus.fail,
        detail: 'No GPS fix was acquired within 15 seconds.',
      ));
    } on PermissionDeniedException {
      if (!mounted) return;
      _setResult(const CheckupResult(
        key: 'location',
        title: 'Location (GPS)',
        status: CheckupStatus.skipped,
        detail: 'Location permission needed for a GPS fix was not granted.',
      ));
    } on LocationServiceDisabledException {
      if (!mounted) return;
      _setResult(const CheckupResult(
        key: 'location',
        title: 'Location (GPS)',
        status: CheckupStatus.skipped,
        detail: 'Location services are switched off — turn them on for a GPS fix.',
      ));
    } catch (e) {
      if (!mounted) return;
      _setResult(CheckupResult(
        key: 'location',
        title: 'Location (GPS)',
        status: CheckupStatus.fail,
        detail: 'Could not acquire a GPS fix: $e',
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
    setState(() {
      _busy = false;
      _result = result;
    });
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
        key: 'location',
        title: 'Location (GPS)',
        status: CheckupStatus.skipped,
        detail: 'Skipped by user',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CheckupTestShell(
      title: 'Location',
      child: _result != null ? _verdictView() : _testView(),
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
              const Icon(Icons.location_searching, color: AppColors.primary, size: 48),
            const SizedBox(height: 20),
            Text(
              _statusText,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                  fontSize: 14, height: 1.45, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            CheckupSkipButton(onSkip: _skipTest),
          ],
        ),
      ),
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