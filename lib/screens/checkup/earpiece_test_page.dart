import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/theme/app_theme.dart';
import 'checkup_test_shell.dart';
import 'checkup_tone.dart';

/// Earpiece (receiver) speaker.
///
/// Plays between two and five beeps through the receiver and asks how many
/// were heard. A correct answer is strong evidence the earpiece works: it is
/// unguessable at 1-in-4, the count changes on every retry, and counting
/// separate beeps needs the driver to start and stop cleanly rather than just
/// make a noise.
///
/// ROUTING — this is the part that has to be right, and the part that was
/// wrong before. The test used to speak a number with flutter_tts while a
/// native channel put AudioManager into MODE_IN_COMMUNICATION with the
/// speakerphone off. That mode reroutes the *voice-call* stream; TTS plays on
/// the media stream, which stays on the loudspeaker, and flutter_tts has no
/// API to move it (only setAudioAttributesForNavigation, still media usage).
/// So the audio came out of the loudspeaker and the test proved nothing about
/// the receiver.
///
/// audioplayers can declare the routing on the player itself — voice
/// communication usage on Android, playAndRecord without defaultToSpeaker on
/// iOS — which is what actually reaches the earpiece, and works on both
/// platforms rather than Android alone. Dropping TTS also drops a dependency
/// on a speech engine and voice data being installed, which on a
/// factory-reset phone waiting to be appraised is not a safe assumption.
class EarpieceTestPage extends StatefulWidget {
  const EarpieceTestPage({super.key});

  @override
  State<EarpieceTestPage> createState() => _EarpieceTestPageState();
}

class _EarpieceTestPageState extends State<EarpieceTestPage>
    with CheckupTestFlow<EarpieceTestPage> {
  /// Only `hasEarpiece` is still wanted from the native side: audioplayers
  /// handles the routing, but nothing in it can say whether the device has a
  /// receiver at all. Tablets generally do not.
  static const _audioChannel = MethodChannel('french_mobiles/audio_route');

  /// Routes playback to the receiver instead of the loudspeaker.
  static final AudioContext _earpieceContext = AudioContext(
    android: const AudioContextAndroid(
      isSpeakerphoneOn: false,
      audioMode: AndroidAudioMode.inCommunication,
      contentType: AndroidContentType.speech,
      usageType: AndroidUsageType.voiceCommunication,
      audioFocus: AndroidAudioFocus.gainTransientMayDuck,
    ),
    iOS: AudioContextIOS(
      // playAndRecord routes to the receiver unless defaultToSpeaker is set,
      // which is exactly what this test wants.
      category: AVAudioSessionCategory.playAndRecord,
      options: const {},
    ),
  );

  @override
  String get testKey => 'earpiece';
  @override
  String get testTitle => 'Earpiece';

  static const List<int> _choices = [2, 3, 4, 5];

  final AudioPlayer _player = AudioPlayer();
  final Random _random = Random();

  late int _count;
  bool _playing = false;
  bool _played = false;
  int _attempt = 1;
  int? _wrongPick;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    disposeHardware();
    super.dispose();
  }

  @override
  void disposeHardware() {
    _player.stop().catchError((_) => null);
    // Leaving the player in communication mode would keep later sounds on the
    // receiver, so hand the session back before releasing it.
    _player
        .setAudioContext(AudioContext())
        .catchError((_) => null)
        .whenComplete(_player.dispose);
  }

  Future<void> _start() async {
    _count = _choices[_random.nextInt(_choices.length)];
    _wrongPick = null;
    await _play();
  }

  Future<void> _play() async {
    setState(() {
      _playing = true;
      _error = null;
    });

    try {
      // A device with no receiver cannot pass this, and saying so is more use
      // than letting the user hunt for a sound that has nowhere to come out.
      final hasEarpiece =
          await _audioChannel.invokeMethod<bool>('hasEarpiece');
      if (hasEarpiece == false) {
        if (!mounted) return;
        markNotAvailable('This device has no earpiece — only a loudspeaker');
        return;
      }
    } on MissingPluginException {
      // Not Android. Carry on: the iOS routing below still applies.
    } catch (_) {
      // Could not determine. Carrying on is better than blocking the test.
    }

    try {
      await _player.setAudioContext(_earpieceContext);
      await _player.setVolume(1);
      await _player.play(BytesSource(CheckupTone.beeps(count: _count)));
      await _player.onPlayerComplete.first;
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) {
        setState(() {
          _playing = false;
          _played = true;
        });
      }
    }
  }

  void _pick(int value) {
    if (_playing || result != null) return;

    if (value == _count) {
      markPass('Counted $_count beeps through the earpiece on attempt '
          '$_attempt');
    } else {
      setState(() => _wrongPick = value);
    }
  }

  Future<void> _retry() async {
    setState(() {
      _attempt++;
      _played = false;
    });
    await _start();
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const CheckupInstruction(
          icon: Icons.hearing_rounded,
          text: 'Hold the phone to your ear as if on a call. A short series '
              'of beeps is playing through the earpiece — tap how many you '
              'hear.',
        ),
        const SizedBox(height: AppSpacing.lg),
        _playingTile(),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          CheckupInstruction(
            icon: Icons.error_outline,
            tone: AppColors.error,
            text: 'Could not play through the earpiece: $_error',
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        ..._optionTiles(),
        if (_wrongPick != null) ...[
          const SizedBox(height: AppSpacing.md),
          const CheckupInstruction(
            icon: Icons.error_outline,
            tone: AppColors.error,
            text: 'That was not the number of beeps. Play a new set, or '
                'report an issue if you cannot hear anything at all.',
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        CheckupActions(
          attempt: _attempt,
          retryLabel: 'Play again',
          onRetry: _playing ? null : _retry,
          onIssue: () => markFail(
            'User could not count the beeps through the earpiece after '
            '$_attempt attempt(s)',
          ),
          onSkip: skipTest,
        ),
      ],
    );
  }

  Widget _playingTile() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: _playing ? AppColors.primarySoft : AppColors.surface,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Icon(
            _playing ? Icons.graphic_eq_rounded : Icons.replay_rounded,
            color: _playing ? AppColors.onPrimarySoft : AppColors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              _playing
                  ? 'Playing through the earpiece…'
                  : _played
                      ? 'Finished. Tap how many beeps you heard.'
                      : 'Getting ready…',
              style: AppTextStyles.bodyMedium.copyWith(
                color: _playing
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
      for (var i = 0; i < _choices.length; i++) ...[
        if (i > 0) const SizedBox(height: AppSpacing.sm),
        _OptionTile(
          value: _choices[i],
          enabled: !_playing,
          wrong: _wrongPick == _choices[i],
          onTap: () => _pick(_choices[i]),
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
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
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
          '$value beeps',
          style: AppTextStyles.h3.copyWith(
            color: enabled
                ? (wrong ? AppColors.error : AppColors.textPrimary)
                : AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}
