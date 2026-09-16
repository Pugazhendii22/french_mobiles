import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../../models/checkup_result.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/widgets.dart';

enum _BiometricPhase { checking, prompt, selfReport, verdict }

/// Test 6 — Biometric (screen lock) authentication.
///
/// Runs the real system biometric prompt automatically. A genuine success passes
/// immediately. If the prompt fails, errors out, or is cancelled — which can
/// happen on OEM devices where face unlock isn't wired into BiometricPrompt, even
/// when the sensor works fine — the test falls back to a user self-report instead
/// of wrongly failing.
class BiometricTestPage extends StatefulWidget {
  const BiometricTestPage({super.key});

  @override
  State<BiometricTestPage> createState() => _BiometricTestPageState();
}

class _BiometricTestPageState extends State<BiometricTestPage> {
  _BiometricPhase _phase = _BiometricPhase.checking;
  CheckupResult? _result;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final auth = LocalAuthentication();

    List<BiometricType> available = const [];
    try {
      available = await auth.getAvailableBiometrics();
    } catch (_) {}

    if (!mounted) return;
    if (available.isEmpty) {
      Navigator.of(context).pop(
        const CheckupResult(
          key: 'biometric',
          title: 'Biometric',
          status: CheckupStatus.notAvailable,
          detail: 'No biometric authentication set up on this device.',
        ),
      );
      return;
    }

    setState(() => _phase = _BiometricPhase.prompt);

    var autoVerified = false;
    try {
      final success = await auth.authenticate(
        localizedReason: 'Verify biometric security is working',
        options: const AuthenticationOptions(
          useErrorDialogs: false,
          biometricOnly: true,
          stickyAuth: false,
        ),
      );
      if (success) autoVerified = true;
    } catch (_) {}

    if (!mounted) return;
    if (autoVerified) {
      _setResult(CheckupResult(
        key: 'biometric',
        title: 'Biometric',
        status: CheckupStatus.pass,
        detail: '${_describeBiometrics(available)} and verified',
      ));
      return;
    }

    setState(() => _phase = _BiometricPhase.selfReport);
  }

  String _describeBiometrics(List<BiometricType> types) {
    final names = <String>{};
    for (final type in types) {
      switch (type) {
        case BiometricType.face:
          names.add('Face');
        case BiometricType.fingerprint:
          names.add('Fingerprint');
        case BiometricType.iris:
          names.add('Iris');
        case BiometricType.strong:
        case BiometricType.weak:
          break;
      }
    }
    if (names.isEmpty) return 'Biometric authentication available';
    final list = names.toList();
    if (list.length == 1) return '${list.first} unlock available';
    return '${list.sublist(0, list.length - 1).join(', ')} and ${list.last} unlock available';
  }

  void _setResult(CheckupResult result) {
    if (!mounted) return;
    setState(() {
      _result = result;
      _phase = _BiometricPhase.verdict;
    });
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.of(context).pop(_result);
      }
    });
  }

  void _completeWith(CheckupResult result) {
    if (!mounted) return;
    Navigator.of(context).pop(result);
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
            child: AppScreenHeader(title: 'Checkup · Biometric'),
          ),
          Expanded(child: switch (_phase) {
            _BiometricPhase.checking ||
            _BiometricPhase.prompt =>
              _loadingView(),
            _BiometricPhase.selfReport => _selfReportView(),
            _BiometricPhase.verdict => _verdictView(),
          }),
        ],
      ),
    );
  }

  Widget _loadingView() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }

  Widget _selfReportView() {
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
          child: Text(
            'We couldn\'t verify automatically — this can happen on some phones even when the sensor works fine. Try unlocking with your fingerprint or face ID now, then tell us what happened.',
            style: AppTextStyles.body.copyWith(
                fontSize: 13.5, height: 1.45, color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: 16),
        _reportButton(
          'Works',
          Icons.check_circle_outline,
          AppColors.primary,
          () => _completeWith(const CheckupResult(
            key: 'biometric',
            title: 'Biometric',
            status: CheckupStatus.pass,
            detail: 'Verified by user after automatic check was inconclusive.',
          )),
        ),
        const SizedBox(height: 12),
        _reportButton(
          "Doesn't work",
          Icons.cancel_outlined,
          AppColors.error,
          () => _completeWith(const CheckupResult(
            key: 'biometric',
            title: 'Biometric',
            status: CheckupStatus.fail,
            detail: "User confirmed biometric unlock isn't working.",
          )),
        ),
        const SizedBox(height: 12),
        _reportButton(
          'Not set up',
          Icons.lock_open_outlined,
          AppColors.textSecondary,
          () => _completeWith(const CheckupResult(
            key: 'biometric',
            title: 'Biometric',
            status: CheckupStatus.skipped,
            detail: 'User reported no biometric method is actively in use.',
          )),
        ),
      ],
    );
  }

  Widget _reportButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(label, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
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
          ],
        ),
      ),
    );
  }
}