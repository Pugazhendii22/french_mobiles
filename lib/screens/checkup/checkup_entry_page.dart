import 'package:flutter/material.dart';

import '../../models/checkup_result.dart';
import '../../shared/motion/motion.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/widgets.dart';
import 'biometric_test_page.dart';
import 'bluetooth_test_page.dart';
import 'buttons_test_page.dart';
import 'camera_test_page.dart';
import 'display_test_page.dart';
import 'earpiece_test_page.dart';
import 'flashlight_test_page.dart';
import 'gyroscope_test_page.dart';
import 'location_test_page.dart';
import 'microphone_test_page.dart';
import 'multitouch_test_page.dart';
import 'network_test_page.dart';
import 'proximity_test_page.dart';
import 'speaker_test_page.dart';
import 'summary_page.dart';
import 'vibration_test_page.dart';
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
  const CheckupEntryPage({super.key, this.tests});

  /// Replaces [specs] for this instance.
  ///
  /// Only for tests: every registered test drives hardware that flutter_test
  /// does not provide, so sequencing behaviour can only be exercised against
  /// stand-in pages.
  @visibleForTesting
  final List<CheckupTestSpec>? tests;

  /// Every test in the run, in execution order.
  ///
  /// Public so the order and registration can be asserted without reaching
  /// into private state — this list is the flow's contract.
  static final List<CheckupTestSpec> specs = [
    const CheckupTestSpec(
      key: 'camera',
      title: 'Camera',
      description: 'Check front & back camera preview',
      icon: Icons.photo_camera_outlined,
      pageBuilder: _camera,
    ),
    const CheckupTestSpec(
      key: 'flashlight',
      title: 'Flashlight',
      description: 'Torch switches on and off',
      icon: Icons.flashlight_on_outlined,
      pageBuilder: _flashlight,
    ),
    const CheckupTestSpec(
      key: 'display',
      title: 'Display',
      description: 'Colour sweep & full-screen touch grid',
      icon: Icons.crop_portrait_outlined,
      pageBuilder: _display,
    ),
    const CheckupTestSpec(
      key: 'multitouch',
      title: 'Multi-touch',
      description: 'Panel tracks five fingers at once',
      icon: Icons.touch_app_outlined,
      pageBuilder: _multitouch,
    ),
    const CheckupTestSpec(
      key: 'buttons',
      title: 'Side buttons',
      description: 'Volume keys & power button self-report',
      icon: Icons.volume_up_outlined,
      pageBuilder: _buttons,
    ),
    const CheckupTestSpec(
      key: 'speaker',
      title: 'Loudspeaker',
      description: 'Plays a test tone through the speaker',
      icon: Icons.volume_up_outlined,
      pageBuilder: _speaker,
    ),
    const CheckupTestSpec(
      key: 'earpiece',
      title: 'Earpiece',
      description: 'Reads a number through the receiver',
      icon: Icons.hearing_outlined,
      pageBuilder: _earpiece,
    ),
    const CheckupTestSpec(
      key: 'microphone',
      title: 'Microphone',
      description: 'Records and measures captured audio',
      icon: Icons.mic_none_outlined,
      pageBuilder: _microphone,
    ),
    const CheckupTestSpec(
      key: 'proximity',
      title: 'Proximity sensor',
      description: 'Detects the phone approaching your ear',
      icon: Icons.phonelink_ring_outlined,
      pageBuilder: _proximity,
    ),
    const CheckupTestSpec(
      key: 'vibration',
      title: 'Vibration motor',
      description: 'Buzzes a pattern you confirm',
      icon: Icons.vibration_rounded,
      pageBuilder: _vibration,
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
  static Widget _flashlight(BuildContext context) =>
      const FlashlightTestPage();
  static Widget _multitouch(BuildContext context) =>
      const MultitouchTestPage();
  static Widget _speaker(BuildContext context) => const SpeakerTestPage();
  static Widget _earpiece(BuildContext context) => const EarpieceTestPage();
  static Widget _microphone(BuildContext context) =>
      const MicrophoneTestPage();
  static Widget _proximity(BuildContext context) => const ProximityTestPage();
  static Widget _vibration(BuildContext context) => const VibrationTestPage();

  @override
  State<CheckupEntryPage> createState() => _CheckupEntryPageState();
}


class _CheckupEntryPageState extends State<CheckupEntryPage> {
  List<CheckupTestSpec> get specs => widget.tests ?? CheckupEntryPage.specs;

  /// Results by spec key, whether produced by a full run or by tapping a
  /// single test. Keyed rather than listed so re-running one test replaces
  /// its earlier outcome instead of appending a second row.
  final Map<String, CheckupResult> _results = {};

  /// The spec currently on screen during a sequenced run, or null when the
  /// user is running one test on its own.
  String? _currentKey;
  bool _running = false;

  /// Collected results in registration order — the order the summary lists
  /// them, and the order they were meant to run in.
  List<CheckupResult> get _collected => [
        for (final spec in specs)
          if (_results[spec.key] != null) _results[spec.key]!,
      ];

  /// Pushes one test and returns its result, or null if the user left the
  /// page without producing one.
  ///
  /// Each hardware test rises into view; the sequence reads as a stack of
  /// steps rather than a series of cuts.
  Future<CheckupResult?> _push(CheckupTestSpec spec) {
    return Navigator.of(context).push<CheckupResult>(
      AppPageRoute<CheckupResult>(
        builder: spec.pageBuilder,
        transition: AppTransition.rise,
      ),
    );
  }

  /// Runs every test back to back.
  ///
  /// A null result means the user backed out of the test rather than
  /// finishing it, and that ends the run. Leaving is the only way out of a
  /// sixteen-step sequence — treating back as "skip and continue" trapped the
  /// user on the next test instead. "Skip this test" is still there for
  /// skipping one and carrying on.
  Future<void> _startCheckup() async {
    if (_running) return;
    setState(() {
      _running = true;
      _results.clear();
    });

    for (final spec in specs) {
      if (!mounted) return;
      setState(() => _currentKey = spec.key);

      final result = await _push(spec);
      if (!mounted) return;
      if (result == null) break;

      setState(() => _results[spec.key] = result);
    }

    if (!mounted) return;
    setState(() {
      _running = false;
      _currentKey = null;
    });

    if (_results.isEmpty) return;
    await _openSummary();
  }

  /// Runs a single test, from tapping its row in the list.
  Future<void> _runOne(CheckupTestSpec spec) async {
    if (_running) return;

    final result = await _push(spec);
    if (!mounted || result == null) return;
    setState(() => _results[spec.key] = result);
  }

  Future<void> _openSummary() {
    return Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (context) => CheckupSummaryPage(results: _collected),
        transition: AppTransition.fadeThrough,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenGutter,
                AppSpacing.lg, AppSpacing.screenGutter, AppSpacing.lg),
            child: AppScreenHeader(
              title: 'Device Auto Checkup',
              content: _intro(),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                0,
                AppSpacing.screenGutter,
                AppSpacing.xxxl,
              ),
              children: [
                // One enclosure around the whole list rather than sixteen
                // separate cards: these are steps in one procedure, not
                // sixteen unrelated things.
                AppGroup(
                  children: [
                    for (var i = 0; i < specs.length; i++)
                      _TestRow(
                        index: i + 1,
                        spec: specs[i],
                        result: _results[specs[i].key],
                        active: _currentKey == specs[i].key,
                        onTap: _running ? null : () => _runOne(specs[i]),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _startBar(),
    );
  }

  /// Sits on the page under the title — no panel. It is supporting copy for
  /// the heading above it, and a box around it would only compete with the
  /// list, which is the thing to look at.
  Widget _intro() {
    final done = _results.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${specs.length} hardware tests',
          style: AppTextStyles.bodyLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          done == 0
              ? 'Run them all in sequence, or tap any single test to run it '
                  'on its own.'
              : '$done of ${specs.length} tested. Tap a test to run it again.',
          style: AppTextStyles.bodySmall,
        ),
        if (done > 0) ...[
          const SizedBox(height: AppSpacing.md),
          _tally(),
        ],
      ],
    );
  }

  /// One badge per status that actually occurred — an empty count is noise.
  Widget _tally() {
    int count(CheckupStatus status) =>
        _results.values.where((r) => r.status == status).length;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final status in CheckupStatus.values)
          if (count(status) > 0)
            AppBadge(
              label: '${count(status)} ${status.label.toLowerCase()}',
              tone: status.badgeTone,
              icon: status.icon,
            ),
      ],
    );
  }

  Widget _startBar() {
    final hasResults = _results.isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.md,
        AppSpacing.screenGutter,
        AppSpacing.md + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppPrimaryButton(
            label: _running ? 'Running checkup…' : 'Start Checkup',
            loading: _running,
            onPressed: _running ? null : _startCheckup,
          ),
          if (hasResults && !_running)
            TextButton(
              onPressed: _openSummary,
              child: Text(
                'View results',
                style: AppTextStyles.button
                    .copyWith(color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}

/// One test in the list: its place in the running order, what it checks, and
/// its outcome once it has one.
class _TestRow extends StatelessWidget {
  const _TestRow({
    required this.index,
    required this.spec,
    required this.result,
    required this.active,
    required this.onTap,
  });

  final int index;
  final CheckupTestSpec spec;
  final CheckupResult? result;

  /// True while a sequenced run has this test on screen.
  final bool active;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final status = result?.status;

    return AppSurface(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          _leading(status),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  spec.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  // Once a test has run, what it found is more use than what
                  // it was going to do.
                  result?.detail?.isNotEmpty == true
                      ? result!.detail!
                      : spec.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (status != null)
            AppBadge(label: status.label, tone: status.badgeTone)
          else if (active)
            const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
          else
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textTertiary,
            ),
        ],
      ),
    );
  }

  /// The running number, replaced by the test's icon in its status colour
  /// once there is a verdict to show.
  Widget _leading(CheckupStatus? status) {
    return Container(
      height: 32,
      width: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: status == null
            ? AppColors.surfaceMuted
            : status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: status == null
          ? Text(
              '$index',
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            )
          : Icon(spec.icon, size: 17, color: status.color),
    );
  }
}
