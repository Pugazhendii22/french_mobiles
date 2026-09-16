import 'dart:async';

import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/theme/app_theme.dart';
import 'checkup_test_shell.dart';

/// Microphone.
///
/// Genuinely verifiable, unlike the speaker: records for three seconds and
/// passes only if the captured amplitude rises clearly above the ambient
/// floor. The user is asked to speak, but the pass comes from what the mic
/// actually captured, not from them saying it worked.
class MicrophoneTestPage extends StatefulWidget {
  const MicrophoneTestPage({super.key});

  @override
  State<MicrophoneTestPage> createState() => _MicrophoneTestPageState();
}

class _MicrophoneTestPageState extends State<MicrophoneTestPage>
    with CheckupTestFlow<MicrophoneTestPage> {
  /// Amplitude arrives in dBFS: 0 is clipping, -160 is digital silence. A
  /// quiet room floor sits near -50; speech at arm's length is well above
  /// -30. -35 keeps a soft speaker passing without letting room noise alone
  /// carry the test.
  static const double _speechFloor = -35;
  static const Duration _window = Duration(seconds: 3);

  @override
  String get testKey => 'microphone';
  @override
  String get testTitle => 'Microphone';

  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Amplitude>? _amplitudes;
  Timer? _stopTimer;

  bool _recording = false;
  double _peak = -160;
  double _current = -160;
  bool _finished = false;
  int _attempt = 1;
  String? _error;

  @override
  void dispose() {
    disposeHardware();
    super.dispose();
  }

  @override
  void disposeHardware() {
    _amplitudes?.cancel();
    _amplitudes = null;
    _stopTimer?.cancel();
    _stopTimer = null;
    _recorder.stop().catchError((_) => null);
    _recorder.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _finished = false;
      _peak = -160;
      _current = -160;
    });

    try {
      if (!await _recorder.hasPermission()) {
        if (!mounted) return;
        markNotAvailable('Microphone permission was denied');
        return;
      }

      // Streamed rather than written to a file: nothing is persisted, the
      // amplitude is all this test needs.
      await _recorder.startStream(
        const RecordConfig(encoder: AudioEncoder.pcm16bits),
      );

      if (!mounted) return;
      setState(() => _recording = true);

      _amplitudes = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 150))
          .listen((amp) {
        if (!mounted) return;
        setState(() {
          _current = amp.current;
          if (amp.current > _peak) _peak = amp.current;
        });
      });

      _stopTimer = Timer(_window, _finish);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _recording = false;
        _error = '$e';
      });
    }
  }

  Future<void> _finish() async {
    _amplitudes?.cancel();
    _amplitudes = null;
    await _recorder.stop().catchError((_) => null);
    if (!mounted) return;

    setState(() {
      _recording = false;
      _finished = true;
    });

    if (_peak > _speechFloor) {
      markPass(
        'Captured audio peaking at ${_peak.toStringAsFixed(1)} dBFS',
      );
    }
    // Below the floor the page stays put and offers a retry rather than
    // failing outright: the user may simply not have spoken in time.
  }

  void _retry() {
    setState(() => _attempt++);
    _start();
  }

  @override
  Widget build(BuildContext context) {
    return CheckupTestShell(
      title: 'Microphone',
      child: result != null ? CheckupVerdict(result: result!) : _testView(),
    );
  }

  Widget _testView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const CheckupInstruction(
          icon: Icons.mic_none_rounded,
          text: 'Tap record, then speak normally for three seconds — say '
              'anything. The test measures what the microphone actually '
              'captured.',
        ),
        const SizedBox(height: 16),
        _meter(),
        if (_error != null) ...[
          const SizedBox(height: 12),
          CheckupInstruction(
            icon: Icons.error_outline,
            tone: AppColors.error,
            text: 'Could not start recording: $_error',
          ),
        ],
        if (_finished && _peak <= _speechFloor) ...[
          const SizedBox(height: 12),
          const CheckupInstruction(
            icon: Icons.volume_off_outlined,
            tone: AppColors.warning,
            text: 'Almost nothing was captured. Check that nothing is '
                'covering the microphone at the bottom edge, then try again.',
          ),
        ],
        const SizedBox(height: 16),
        CheckupActions(
          attempt: _attempt,
          primary: _recording ? null : (_finished ? null : _start),
          primaryLabel: 'Start recording',
          retryLabel: 'Record again',
          onRetry: _recording ? null : (_finished || _error != null ? _retry : null),
          onIssue: () => markFail(
            _finished
                ? 'Captured audio peaked at only '
                    '${_peak.toStringAsFixed(1)} dBFS'
                : 'User reported a microphone issue',
          ),
          onSkip: skipTest,
        ),
      ],
    );
  }

  Widget _meter() {
    // dBFS -60..0 mapped to 0..1 for the bar.
    final level = ((_current + 60) / 60).clamp(0.0, 1.0);
    final peakLevel = ((_peak + 60) / 60).clamp(0.0, 1.0);
    final passed = _peak > _speechFloor;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Icon(
            _recording ? Icons.mic_rounded : Icons.mic_off_rounded,
            size: 40,
            color: _recording ? AppColors.primary : AppColors.textTertiary,
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: AppRadius.pill,
            child: Stack(
              children: [
                Container(height: 10, color: AppColors.surfaceMuted),
                FractionallySizedBox(
                  widthFactor: level,
                  child: Container(
                    height: 10,
                    color: passed ? AppColors.success : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _recording
                ? 'Listening… speak now'
                : _finished
                    ? 'Peak ${_peak.toStringAsFixed(1)} dBFS'
                    : 'Not recording',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Needs to exceed ${_speechFloor.toStringAsFixed(0)} dBFS',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: peakLevel,
            minHeight: 3,
            backgroundColor: AppColors.surfaceMuted,
            color: passed ? AppColors.success : AppColors.borderStrong,
          ),
        ],
      ),
    );
  }
}
