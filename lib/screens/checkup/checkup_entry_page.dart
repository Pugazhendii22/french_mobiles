import 'package:flutter/material.dart';

import '../../models/checkup_result.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/widgets.dart';
import 'biometric_test_page.dart';
import 'bluetooth_test_page.dart';
import 'buttons_test_page.dart';
import 'camera_test_page.dart';
import 'display_test_page.dart';
import 'gyroscope_test_page.dart';
import 'location_test_page.dart';
import 'network_test_page.dart';
import 'summary_page.dart';
import 'wifi_test_page.dart';

/// One entry in the checkup run, in the order tests execute.
class CheckupTestSpec {
  final String key;
  final String title;
  final String description;
  final IconData icon;
  final WidgetBuilder pageBuilder;

  const CheckupTestSpec({
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.pageBuilder,
  });
}

/// Orchestrator — lists hardware tests and steps through them in order,
/// collecting a [CheckupResult] from each before opening the summary.
class CheckupEntryPage extends StatefulWidget {
  const CheckupEntryPage({super.key});

  @override
  State<CheckupEntryPage> createState() => _CheckupEntryPageState();
}

class _CheckupEntryPageState extends State<CheckupEntryPage> {
  static final List<CheckupTestSpec> specs = [
    const CheckupTestSpec(
      key: 'camera',
      title: 'Camera',
      description: 'Check front & back camera preview',
      icon: Icons.photo_camera_outlined,
      pageBuilder: _camera,
    ),
    const CheckupTestSpec(
      key: 'display',
      title: 'Display',
      description: 'Colour sweep & full-screen touch grid',
      icon: Icons.crop_portrait_outlined,
      pageBuilder: _display,
    ),
    const CheckupTestSpec(
      key: 'buttons',
      title: 'Side buttons',
      description: 'Volume keys & power button self-report',
      icon: Icons.volume_up_outlined,
      pageBuilder: _buttons,
    ),
    const CheckupTestSpec(
      key: 'wifi',
      title: 'Wi-Fi',
      description: 'Radio scans for nearby networks',
      icon: Icons.wifi,
      pageBuilder: _wifi,
    ),
    const CheckupTestSpec(
      key: 'bluetooth',
      title: 'Bluetooth',
      description: 'Radio turns on & scans for devices',
      icon: Icons.bluetooth,
      pageBuilder: _bluetooth,
    ),
    const CheckupTestSpec(
      key: 'biometric',
      title: 'Biometric',
      description: 'Enrolled screen-lock authentication prompt',
      icon: Icons.lock_outline,
      pageBuilder: _biometric,
    ),
    const CheckupTestSpec(
      key: 'network',
      title: 'Mobile network',
      description: 'SIM present, carrier & data route',
      icon: Icons.signal_cellular_alt_outlined,
      pageBuilder: _network,
    ),
    const CheckupTestSpec(
      key: 'location',
      title: 'Location (GPS)',
      description: 'Acquires a GPS satellite fix',
      icon: Icons.my_location,
      pageBuilder: _location,
    ),
    const CheckupTestSpec(
      key: 'gyroscope',
      title: 'Gyroscope',
      description: 'Detects phone rotation on two axes',
      icon: Icons.threed_rotation,
      pageBuilder: _gyroscope,
    ),
  ];

  static Widget _camera(BuildContext context) => const CameraTestPage();
  static Widget _display(BuildContext context) => const DisplayTestPage();
  static Widget _buttons(BuildContext context) => const ButtonsTestPage();
  static Widget _wifi(BuildContext context) => const WifiTestPage();
  static Widget _bluetooth(BuildContext context) => const BluetoothTestPage();
  static Widget _biometric(BuildContext context) => const BiometricTestPage();
  static Widget _network(BuildContext context) => const NetworkTestPage();
  static Widget _location(BuildContext context) => const LocationTestPage();
  static Widget _gyroscope(BuildContext context) => const GyroscopeTestPage();

  bool _running = false;

  Future<void> _startCheckup() async {
    if (_running) return;
    setState(() => _running = true);

    final results = <CheckupResult>[];
    for (final spec in specs) {
      if (!mounted) return;

      final result = await Navigator.of(context).push<CheckupResult>(
        MaterialPageRoute<CheckupResult>(
          builder: spec.pageBuilder,
          fullscreenDialog: false,
        ),
      );
      if (!mounted) return;
      results.add(
        result ??
            CheckupResult(
              key: spec.key,
              title: spec.title,
              status: CheckupStatus.skipped,
              detail: 'Test was not completed',
            ),
      );
    }

    if (!mounted) return;
    setState(() => _running = false);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => CheckupSummaryPage(results: results),
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
            child: AppScreenHeader(title: 'Device Auto Checkup'),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              children: [
                _introCard(),
                const SizedBox(height: 18),
                for (var i = 0; i < specs.length; i++) ...[
                  _testTile(i + 1, specs[i]),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _startBar(),
    );
  }

  Widget _introCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.build_circle_outlined,
                color: AppColors.surface, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '9 hardware tests',
                  style: AppTextStyles.body.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Runs automatically in sequence, then displays your test summary.',
                  style: AppTextStyles.body.copyWith(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _testTile(int index, CheckupTestSpec spec) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: AppColors.transparent,
        borderRadius: AppRadius.card,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(spec.icon, size: 19, color: AppColors.primaryDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$index. ${spec.title}',
                      style: AppTextStyles.body.copyWith(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      spec.description,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _startBar() {
    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      child: SizedBox(
        height: 52,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            textStyle: AppTextStyles.body.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          onPressed: _running ? null : _startCheckup,
          child: Text(_running ? 'Running checkup…' : 'Start Checkup'),
        ),
      ),
    );
  }
}