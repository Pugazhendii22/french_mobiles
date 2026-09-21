import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/theme/app_theme.dart';
import 'checkup_demo.dart';
import 'checkup_test_shell.dart';

/// Vibration motor.
///
/// SELF-REPORT ONLY — flagged honestly. The device cannot feel itself; the
/// accelerometer does pick up the buzz, but it also picks up the hand holding
/// the phone, so it is not a trustworthy discriminator. The user's Yes/No is
/// the verdict.
///
/// A distinctive pattern rather than one long buzz, so the user is confirming
/// something specific instead of a vague sensation.
class VibrationTestPage extends StatefulWidget {
  const VibrationTestPage({super.key});

  @override
  State<VibrationTestPage> createState() => _VibrationTestPageState();
}

class _VibrationTestPageState extends State<VibrationTestPage>
    with CheckupTestFlow<VibrationTestPage> {
  /// short — gap — short — gap — long
  static const List<int> _pattern = [0, 200, 150, 200, 150, 600];

  @override
  String get testKey => 'vibration';
  @override
  String get testTitle => 'Vibration motor';

  bool _buzzing = false;
  bool _played = false;
  int _attempt = 1;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    disposeHardware();
    super.dispose();
  }

  @override
  void disposeHardware() {
    Vibration.cancel().catchError((_) => null);
  }

  Future<void> _run() async {
    setState(() => _buzzing = true);
    try {
      final has = await Vibration.hasVibrator();
      if (!has) {
        if (!mounted) return;
        markNotAvailable('This device reports no vibration motor');
        return;
      }

      await Vibration.vibrate(pattern: _pattern);
      // The pattern durations plus a little slack, so the prompt does not
      // appear while the phone is still buzzing.
      await Future<void>.delayed(
        Duration(milliseconds: _pattern.reduce((a, b) => a + b) + 200),
      );
    } catch (_) {
      // Fall through to the self-report: some OEM builds throw here but the
      // motor still works.
    }

    if (!mounted) return;
    setState(() {
      _buzzing = false;
      _played = true;
    });
  }

  void _retry() {
    setState(() {
      _attempt++;
      _played = false;
    });
    _run();
  }

  @override
  Widget build(BuildContext context) {
    return CheckupTestShell(
      title: 'Vibration',
      child: result != null ? CheckupVerdict(result: result!) : _testView(),
    );
  }

  Widget _testView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const CheckupInstruction(
          demo: CheckupDemoKind.vibration,
          icon: Icons.vibration_rounded,
          text: 'Hold the phone in your hand. It should buzz twice quickly, '
              'then once for longer.',
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _buzzing ? AppColors.primarySoft : AppColors.surface,
            borderRadius: AppRadius.card,
            boxShadow: AppShadows.card,
          ),
          child: Column(
            children: [
              Icon(
                Icons.vibration_rounded,
                size: 48,
                color:
                    _buzzing ? AppColors.onPrimarySoft : AppColors.textTertiary,
              ),
              const SizedBox(height: 12),
              Text(
                _buzzing ? 'Buzzing…' : 'Did you feel it?',
                style: AppTextStyles.h3.copyWith(
                  color: _buzzing
                      ? AppColors.onPrimarySoft
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CheckupActions(
          attempt: _attempt,
          primary: _buzzing || !_played
              ? null
              : () => markPass('User confirmed feeling the vibration pattern'),
          primaryLabel: 'Yes, I felt it',
          retryLabel: 'Buzz again',
          onRetry: _buzzing ? null : _retry,
          onIssue: () => markFail(
            'User did not feel the vibration after $_attempt attempt(s)',
          ),
          onSkip: skipTest,
        ),
      ],
    );
  }
}
