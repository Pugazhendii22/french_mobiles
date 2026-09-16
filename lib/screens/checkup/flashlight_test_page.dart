import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/theme/app_theme.dart';
import 'checkup_test_shell.dart';

enum _TorchStep { on, off }

/// Flashlight / torch.
///
/// SELF-REPORT ONLY — flagged honestly. No sensor on the device can see its
/// own torch: the ambient light sensor is on the opposite face. The user
/// confirms twice, on and then off, which at least catches a torch stuck in
/// one state — a single "is it on?" would not.
///
/// Reuses the `camera` package already pulled in by the camera test rather
/// than adding a torch package: CameraController.setFlashMode(FlashMode.torch)
/// drives the same LED.
class FlashlightTestPage extends StatefulWidget {
  const FlashlightTestPage({super.key});

  @override
  State<FlashlightTestPage> createState() => _FlashlightTestPageState();
}

class _FlashlightTestPageState extends State<FlashlightTestPage>
    with CheckupTestFlow<FlashlightTestPage> {
  @override
  String get testKey => 'flashlight';
  @override
  String get testTitle => 'Flashlight';

  CameraController? _controller;
  _TorchStep _step = _TorchStep.on;
  bool _busy = true;
  bool _confirmedOn = false;
  int _attempt = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void dispose() {
    disposeHardware();
    super.dispose();
  }

  @override
  void disposeHardware() {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      // Always try to put the torch out before releasing the camera,
      // otherwise the LED can stay lit after the page is gone.
      controller
          .setFlashMode(FlashMode.off)
          .catchError((_) => null)
          .whenComplete(controller.dispose);
    }
  }

  Future<void> _open() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        back,
        ResolutionPreset.low,
        enableAudio: false,
      );
      await controller.initialize();
      _controller = controller;
      await controller.setFlashMode(FlashMode.torch);

      if (!mounted) return;
      setState(() => _busy = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  Future<void> _confirmOn() async {
    setState(() {
      _confirmedOn = true;
      _busy = true;
    });
    try {
      await _controller?.setFlashMode(FlashMode.off);
    } catch (_) {
      // Fall through: the user still has to confirm what they observed.
    }
    if (!mounted) return;
    setState(() {
      _step = _TorchStep.off;
      _busy = false;
    });
  }

  void _confirmOff() => markPass(
        'User confirmed the torch switched on and then off',
      );

  Future<void> _retry() async {
    setState(() {
      _attempt++;
      _step = _TorchStep.on;
      _confirmedOn = false;
    });
    disposeHardware();
    await _open();
  }

  @override
  Widget build(BuildContext context) {
    return CheckupTestShell(
      title: 'Flashlight',
      child: result != null ? CheckupVerdict(result: result!) : _testView(),
    );
  }

  Widget _testView() {
    final isOnStep = _step == _TorchStep.on;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CheckupInstruction(
          icon: Icons.flashlight_on_outlined,
          text: isOnStep
              ? 'The torch has been switched on. Look at the back of the '
                  'phone — is the flashlight lit?'
              : 'The torch has been switched off. Is the flashlight now dark?',
        ),
        const SizedBox(height: 16),
        _torchTile(isOnStep),
        if (_error != null) ...[
          const SizedBox(height: 12),
          CheckupInstruction(
            icon: Icons.error_outline,
            tone: AppColors.error,
            text: 'Could not control the torch: $_error',
          ),
        ],
        const SizedBox(height: 16),
        CheckupActions(
          attempt: _attempt,
          primary: _busy
              ? null
              : (isOnStep ? _confirmOn : _confirmOff),
          primaryLabel: isOnStep ? 'Yes, it is lit' : 'Yes, it is off',
          retryLabel: 'Try again',
          onRetry: _busy ? null : _retry,
          onIssue: () => markFail(
            _confirmedOn
                ? 'Torch switched on but did not switch off'
                : 'Torch did not light up',
          ),
          onSkip: skipTest,
        ),
      ],
    );
  }

  Widget _torchTile(bool isOnStep) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isOnStep ? AppColors.warningSoft : AppColors.surface,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Icon(
            isOnStep
                ? Icons.flashlight_on_rounded
                : Icons.flashlight_off_rounded,
            size: 48,
            color: isOnStep ? AppColors.warning : AppColors.textTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            _busy
                ? 'Switching…'
                : isOnStep
                    ? 'Torch ON'
                    : 'Torch OFF',
            style: AppTextStyles.h3,
          ),
          const SizedBox(height: 6),
          Text(
            'Step ${isOnStep ? 1 : 2} of 2',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
