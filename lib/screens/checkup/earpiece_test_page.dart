import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/theme/app_theme.dart';
import 'checkup_test_shell.dart';

/// Earpiece (receiver) speaker.
///
/// Speaks a random 3-digit number through the earpiece and asks the user to
/// pick what they heard from four options. A correct tap is strong evidence
/// the receiver works: the number is unguessable at 1-in-4, and it changes on
/// every retry.
///
/// PLATFORM LIMIT — earpiece routing is Android-only. flutter_tts has no
/// routing API; Android reaches it through AudioManager on a native channel
/// (see MainActivity.kt). iOS needs AVAudioSession work that is not built, so
/// there the audio plays through the loudspeaker and the page says so. That
/// still tests TTS output, but NOT the receiver specifically.
class EarpieceTestPage extends StatefulWidget {
  const EarpieceTestPage({super.key});

  @override
  State<EarpieceTestPage> createState() => _EarpieceTestPageState();
}

class _EarpieceTestPageState extends State<EarpieceTestPage>
    with CheckupTestFlow<EarpieceTestPage> {
  static const _audioChannel = MethodChannel('french_mobiles/audio_route');

  @override
  String get testKey => 'earpiece';
  @override
  String get testTitle => 'Earpiece';

  final FlutterTts _tts = FlutterTts();
  final Random _random = Random();

  late int _spoken;
  late List<int> _options;
  bool _speaking = false;
  bool _routedToEarpiece = false;
  int _attempt = 1;
  String? _wrongPick;

  bool get _earpieceSupported => Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    _newRound();
  }

  @override
  void dispose() {
    disposeHardware();
    super.dispose();
  }

  @override
  void disposeHardware() {
    _tts.stop();
    if (_routedToEarpiece) {
      _audioChannel.invokeMethod('routeToSpeaker').catchError((_) => null);
      _routedToEarpiece = false;
    }
  }

  /// Three digits: long enough that a lucky guess from a partial hearing is
  /// unlikely, short enough to hold in memory.
  void _newRound() {
    _spoken = 100 + _random.nextInt(900);

    final decoys = <int>{};
    while (decoys.length < 3) {
      final candidate = 100 + _random.nextInt(900);
      // Keep decoys away from the answer so a near-miss is a real failure,
      // not a plausible mishearing of the same number.
      if ((candidate - _spoken).abs() > 20) decoys.add(candidate);
    }

    _options = [_spoken, ...decoys]..shuffle(_random);
    _wrongPick = null;
    _speak();
  }

  Future<void> _speak() async {
    setState(() => _speaking = true);
    try {
      if (_earpieceSupported) {
        final ok = await _audioChannel.invokeMethod<bool>('routeToEarpiece');
        _routedToEarpiece = ok ?? false;
      }

      await _tts.setSpeechRate(0.4);
      await _tts.awaitSpeakCompletion(true);
      // Spaced digits: "four two seven" is far clearer through a receiver at
      // low volume than "four hundred and twenty-seven".
      await _tts.speak(_spoken.toString().split('').join(' '));
    } catch (e) {
      if (!mounted) return;
      markNotAvailable('Speech playback unavailable: $e');
      return;
    } finally {
      if (mounted) setState(() => _speaking = false);
    }
  }

  void _pick(int value) {
    if (_speaking || result != null) return;

    if (value == _spoken) {
      markPass(
        _earpieceSupported
            ? 'Heard $_spoken through the earpiece on attempt $_attempt'
            : 'Heard $_spoken through the loudspeaker (earpiece routing '
                'unavailable on iOS)',
      );
    } else {
      setState(() => _wrongPick = '$value');
    }
  }

  void _retry() {
    setState(() => _attempt++);
    _newRound();
  }

  @override
  Widget build(BuildContext context) {
    return CheckupTestShell(
      title: 'Earpiece',
      child: result != null ? CheckupVerdict(result: result!) : _testView(),
    );
  }

  Widget _testView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CheckupInstruction(
          icon: Icons.hearing_rounded,
          text: _earpieceSupported
              ? 'Hold the phone to your ear as if on a call. A 3-digit number '
                  'is being read out through the earpiece — tap the one you '
                  'hear.'
              : 'A 3-digit number is being read out — tap the one you hear.',
        ),
        if (!_earpieceSupported) ...[
          const SizedBox(height: 12),
          const CheckupInstruction(
            icon: Icons.info_outline,
            tone: AppColors.warning,
            text: 'Earpiece routing is not available on this platform yet, so '
                'the number plays through the loudspeaker. This checks speech '
                'output but not the earpiece itself.',
          ),
        ],
        const SizedBox(height: 16),
        _speakingTile(),
        const SizedBox(height: 16),
        ..._optionTiles(),
        if (_wrongPick != null) ...[
          const SizedBox(height: 12),
          const CheckupInstruction(
            icon: Icons.error_outline,
            tone: AppColors.error,
            text: 'That was not the number. Play it again, or report an issue '
                'if you cannot hear anything.',
          ),
        ],
        const SizedBox(height: 16),
        CheckupActions(
          attempt: _attempt,
          retryLabel: 'New number',
          onRetry: _speaking ? null : _retry,
          onIssue: () => markFail(
            'User could not identify the spoken number after $_attempt '
            'attempt(s)',
          ),
          onSkip: skipTest,
        ),
      ],
    );
  }

  Widget _speakingTile() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _speaking ? AppColors.primarySoft : AppColors.surface,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Icon(
            _speaking ? Icons.graphic_eq_rounded : Icons.replay_rounded,
            color: _speaking ? AppColors.onPrimarySoft : AppColors.textTertiary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _speaking
                  ? 'Speaking the number…'
                  : 'Finished speaking. Tap what you heard below.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: _speaking
                    ? AppColors.onPrimarySoft
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _optionTiles() {
    return [
      for (var i = 0; i < _options.length; i++) ...[
        if (i > 0) const SizedBox(height: 10),
        _OptionTile(
          value: _options[i],
          enabled: !_speaking,
          wrong: _wrongPick == '${_options[i]}',
          onTap: () => _pick(_options[i]),
        ),
      ],
    ];
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.value,
    required this.enabled,
    required this.wrong,
    required this.onTap,
  });

  final int value;
  final bool enabled;
  final bool wrong;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: AppRadius.card,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: wrong ? AppColors.errorSoft : AppColors.surface,
          borderRadius: AppRadius.card,
          border: Border.all(
            color: wrong ? AppColors.error : AppColors.border,
          ),
          boxShadow: wrong ? null : AppShadows.card,
        ),
        child: Text(
          value.toString().split('').join(' '),
          style: AppTextStyles.h2.copyWith(
            color: enabled
                ? (wrong ? AppColors.error : AppColors.textPrimary)
                : AppColors.textTertiary,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}
