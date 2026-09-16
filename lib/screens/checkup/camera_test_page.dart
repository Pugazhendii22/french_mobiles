import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../models/checkup_result.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

enum _CameraPhase { front, back }

/// Test 1 — Camera.
///
/// Automatically initializes front camera preview (2s test), then back camera
/// preview (2s test), without requiring manual user confirmation taps.
class CameraTestPage extends StatefulWidget {
  const CameraTestPage({super.key});

  @override
  State<CameraTestPage> createState() => _CameraTestPageState();
}

class _CameraTestPageState extends State<CameraTestPage> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  _CameraPhase _phase = _CameraPhase.front;
  bool _busy = true;
  bool _hasRear = false;
  bool _isPermanentlyDenied = false;
  String? _cameraError;
  CheckupResult? _result;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  CameraDescription? _find(CameraLensDirection direction) {
    for (final camera in _cameras) {
      if (camera.lensDirection == direction) return camera;
    }
    return null;
  }

  Future<void> _initialize() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (status.isPermanentlyDenied) {
      setState(() => _isPermanentlyDenied = true);
      _setResult(const CheckupResult(
        key: 'camera',
        title: 'Camera',
        status: CheckupStatus.skipped,
        detail: 'Camera permission is permanently denied. Open Settings to enable.',
      ));
      return;
    }
    if (!status.isGranted) {
      _setResult(const CheckupResult(
        key: 'camera',
        title: 'Camera',
        status: CheckupStatus.skipped,
        detail: 'Camera permission was not granted.',
      ));
      return;
    }
    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) {
        _setResult(const CheckupResult(
          key: 'camera',
          title: 'Camera',
          status: CheckupStatus.skipped,
          detail: 'No camera hardware detected on device.',
        ));
        return;
      }
      setState(() {
        _cameras = cameras;
        _hasRear = _find(CameraLensDirection.back) != null;
      });

      // 1. Auto-test Front camera
      bool frontOk = await _autoTestCamera(CameraLensDirection.front);
      if (!mounted) return;

      // 2. Auto-test Rear camera if available
      bool backOk = true;
      if (_hasRear) {
        backOk = await _autoTestCamera(CameraLensDirection.back);
        if (!mounted) return;
      }

      if (frontOk && backOk) {
        _setResult(CheckupResult(
          key: 'camera',
          title: 'Camera',
          status: CheckupStatus.pass,
          detail: _hasRear
              ? 'Front & back cameras initialized and rendered successfully.'
              : 'Front camera initialized and rendered successfully.',
        ));
      } else {
        _setResult(const CheckupResult(
          key: 'camera',
          title: 'Camera',
          status: CheckupStatus.fail,
          detail: 'Failed to initialize one or more cameras.',
        ));
      }
    } catch (e) {
      if (!mounted) return;
      _setResult(CheckupResult(
        key: 'camera',
        title: 'Camera',
        status: CheckupStatus.fail,
        detail: 'Camera test error: $e',
      ));
    }
  }

  Future<bool> _autoTestCamera(CameraLensDirection direction) async {
    final camera = _find(direction) ?? _cameras.first;
    setState(() {
      _busy = true;
      _cameraError = null;
      _phase = direction == CameraLensDirection.back ? _CameraPhase.back : _CameraPhase.front;
    });

    final previous = _controller;
    _controller = null;
    if (previous != null) {
      try {
        await previous.dispose();
      } catch (_) {}
      if (!mounted) return false;
    }

    try {
      final next = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await next.initialize();
      if (!mounted) {
        await next.dispose();
        return false;
      }
      setState(() {
        _controller = next;
        _busy = false;
      });

      // Keep preview visible for 2 seconds to let the camera render frames
      await Future.delayed(const Duration(seconds: 2));
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() {
        _controller = null;
        _busy = false;
        _cameraError = 'Could not initialize $_phaseLabel';
      });
      return false;
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
        key: 'camera',
        title: 'Camera',
        status: CheckupStatus.skipped,
        detail: 'Skipped by user',
      ),
    );
  }

  String get _phaseLabel => _phase == _CameraPhase.back ? 'Back Camera' : 'Front Camera';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const AppGradientHeader(title: 'Checkup · Camera'),
          Expanded(
            child: _result != null ? _verdictView() : _cameraView(),
          ),
        ],
      ),
    );
  }

  Widget _cameraView() {
    if (_cameraError != null) return _cameraUnavailableView();
    final previewOk = _controller != null && _controller!.value.isInitialized && !_busy;
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: const Color(0xFF111418)),
        if (previewOk)
          CameraPreview(_controller!)
        else
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Color(0xFF32CD32)),
                const SizedBox(height: 12),
                Text('Testing $_phaseLabel…',
                    style: const TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
        Positioned(top: 16, left: 16, right: 16, child: _stepBanner()),
      ],
    );
  }

  Widget _cameraUnavailableView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_photography_outlined, size: 64, color: Colors.white54),
            const SizedBox(height: 14),
            const Text(
              'Camera unavailable',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _cameraError ?? 'The camera could not be opened.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 28),
            TextButton(
              onPressed: _skipTest,
              child: const Text('Skip this test', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF32CD32)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Testing $_phaseLabel… Auto-verifying camera hardware.',
              style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
            ),
          ),
        ],
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