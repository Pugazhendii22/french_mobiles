import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/theme/app_theme.dart';
import 'checkup_demo.dart';
import 'checkup_test_shell.dart';
import 'checkup_tone.dart';

/// What the test is asking the user to identify.
enum EarpieceMode {
  /// A two-digit number read aloud. Preferred: unambiguous, and hearing a
  /// word rather than a tone also exercises the range speech actually
  /// occupies, which is where a tired receiver fails first.
  spokenNumber,

  /// A count of beeps. Used when the phone has no usable speech engine.
  beepCount,
}

/// Earpiece (receiver) speaker.
///
/// Plays a two-digit number through the receiver and asks which one it was.
/// A correct answer is strong evidence the earpiece works: it is unguessable
/// at 1-in-4, the number changes on every retry, and making out a spoken
/// number needs the driver to reproduce speech rather than merely make a
/// noise.
///
/// ROUTING — this is the part that has to be right, and the part that was
/// wrong once already. Speaking through flutter_tts directly does NOT work:
/// TTS plays on the *media* stream, which stays on the loudspeaker, and
/// flutter_tts has no API to move it (only setAudioAttributesForNavigation,
/// still media usage). A test whose sound comes out of the loudspeaker proves
/// nothing about the receiver.
///
/// So the speech is synthesised to a file first and that file is played
/// through audioplayers, which *can* declare the routing on the player —
/// voice-communication usage on Android, playAndRecord without
/// defaultToSpeaker on iOS. That is what actually reaches the earpiece.
///
/// A phone waiting to be appraised may have been factory reset, and a reset
/// phone may have no speech engine or no voice data installed. When synthesis
/// fails for any reason the test falls back to counting beeps, which needs
/// nothing installed — a working test asking an easier question beats a
/// broken test asking the right one.
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

  /// Candidates for the spoken round.
  ///
  /// No teens: "fifteen" and "fifty" are near-identical through a small
  /// receiver, and a test that punishes a working earpiece for an ambiguity
  /// of English is worse than no test. The four shown are further constrained
  /// to have different tens *and* units digits.
  static const List<int> _numberPool = [
    21,
    34,
    47,
    52,
    63,
    76,
    85,
    98,
    29,
    41,
    58,
    67,
    72,
    96,
  ];

  static const List<int> _beepChoices = [2, 3, 4, 5];

  final AudioPlayer _player = AudioPlayer();
  final FlutterTts _tts = FlutterTts();
  final Random _random = Random();

  EarpieceMode _mode = EarpieceMode.spokenNumber;
  List<int> _options = const [];
  late int _answer;

  String? _spokenFilePath;
  bool _preparing = true;
  bool _playing = false;
  bool _played = false;
  int _attempt = 1;
  int? _wrongPick;
  String? _error;

  @override
  String get testKey => 'earpiece';
  @override
  String get testTitle => 'Earpiece';

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
    _tts.stop().catchError((_) => null);
    _player.stop().catchError((_) => null);
    // Leaving the player in communication mode would keep later sounds on the
    // receiver, so hand the session back before releasing it.
    _player
        .setAudioContext(AudioContext())
        .catchError((_) => null)
        .whenComplete(_player.dispose);
    _deleteSpokenFile();
  }

  void _deleteSpokenFile() {
    final path = _spokenFilePath;
    _spokenFilePath = null;
    if (path == null) return;
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {
      // A leftover file in the temp directory is not worth reporting.
    }
  }

  Future<void> _start() async {
    setState(() {
      _preparing = true;
      _wrongPick = null;
      _error = null;
    });

    if (!await _confirmEarpieceExists()) return;

    final prepared = await _prepareSpokenNumber();
    if (!mounted) return;

    if (!prepared) {
      _prepareBeeps();
    }

    setState(() => _preparing = false);
    await _play();
  }

  /// False when the device has no receiver and the test has been concluded.
  Future<bool> _confirmEarpieceExists() async {
    try {
      final hasEarpiece = await _audioChannel.invokeMethod<bool>('hasEarpiece');
      if (hasEarpiece == false) {
        if (!mounted) return false;
        markNotAvailable('This device has no earpiece — only a loudspeaker');
        return false;
      }
    } on MissingPluginException {
      // Not Android. Carry on: the iOS routing still applies.
    } catch (_) {
      // Could not determine. Carrying on is better than blocking the test.
    }
    return true;
  }

  /// Renders a spoken number to a file. False means speech is unavailable on
  /// this phone and the caller should fall back to beeps.
  Future<bool> _prepareSpokenNumber() async {
    _deleteSpokenFile();

    try {
      final available = await _tts.isLanguageAvailable('en-US');
      if (available != true) return false;

      await _tts.setLanguage('en-US');
      await _tts.setVolume(1);
      await _tts.setPitch(1);
      // Slower than conversational: the point is to be intelligible through a
      // receiver that may be partly blocked with pocket lint.
      await _tts.setSpeechRate(0.4);
      await _tts.awaitSynthCompletion(true);

      final options = _pickNumbers();
      final answer = options[_random.nextInt(options.length)];

      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/earpiece_${DateTime.now().millisecondsSinceEpoch}.wav';

      // Spelled out rather than passed as digits: engines differ on whether
      // "47" is read as "forty seven" or "four seven".
      final result = await _tts.synthesizeToFile(_spell(answer), path, true);
      if (result != 1) return false;

      final file = File(path);
      if (!await file.exists() || await file.length() == 0) return false;

      if (!mounted) return false;
      setState(() {
        _mode = EarpieceMode.spokenNumber;
        _options = options;
        _answer = answer;
        _spokenFilePath = path;
      });
      return true;
    } catch (_) {
      // No engine, no voice data, storage unavailable — all mean the same
      // thing here.
      return false;
    }
  }

  void _prepareBeeps() {
    setState(() {
      _mode = EarpieceMode.beepCount;
      _options = _beepChoices;
      _answer = _beepChoices[_random.nextInt(_beepChoices.length)];
    });
  }

  /// Four numbers that cannot be confused for one another: no shared tens
  /// digit, no shared units digit.
  List<int> _pickNumbers() {
    final pool = [..._numberPool]..shuffle(_random);
    final picked = <int>[];
    final tens = <int>{};
    final units = <int>{};

    for (final candidate in pool) {
      final ten = candidate ~/ 10;
      final unit = candidate % 10;
      if (tens.contains(ten) || units.contains(unit)) continue;
      picked.add(candidate);
      tens.add(ten);
      units.add(unit);
      if (picked.length == 4) break;
    }

    picked.sort();
    return picked;
  }

  static String _spell(int value) {
    const tensWords = {
      2: 'twenty',
      3: 'thirty',
      4: 'forty',
      5: 'fifty',
      6: 'sixty',
      7: 'seventy',
      8: 'eighty',
      9: 'ninety',
    };
    const unitWords = {
      1: 'one',
      2: 'two',
      3: 'three',
      4: 'four',
      5: 'five',
      6: 'six',
      7: 'seven',
      8: 'eight',
      9: 'nine',
    };
    final ten = tensWords[value ~/ 10];
    final unit = unitWords[value % 10];
    if (ten == null) return '$value';
    return unit == null ? ten : '$ten $unit';
  }

  Future<void> _play() async {
    setState(() {
      _playing = true;
      _error = null;
    });

    try {
      await _player.setAudioContext(_earpieceContext);
      await _player.setVolume(1);

      final path = _spokenFilePath;
      if (_mode == EarpieceMode.spokenNumber && path != null) {
        await _player.play(DeviceFileSource(path));
      } else {
        await _player.play(BytesSource(CheckupTone.beeps(count: _answer)));
      }
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
    if (_playing || _preparing || result != null) return;

    if (value == _answer) {
      markPass(_mode == EarpieceMode.spokenNumber
          ? 'Heard the spoken number $_answer through the earpiece on '
              'attempt $_attempt'
          : 'Counted $_answer beeps through the earpiece on attempt $_attempt');
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

  bool get _spoken => _mode == EarpieceMode.spokenNumber;

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
        CheckupInstruction(
          demo: CheckupDemoKind.earpieceToEar,
          icon: Icons.hearing_rounded,
          text: _spoken
              ? 'Hold the phone to your ear as if on a call. A number is '
                  'being read out through the earpiece — tap the one you hear.'
              : 'Hold the phone to your ear as if on a call. A short series '
                  'of beeps is playing through the earpiece — tap how many '
                  'you hear.',
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
          CheckupInstruction(
            icon: Icons.error_outline,
            tone: AppColors.error,
            text: _spoken
                ? 'That was not the number. Play a new one, or report an '
                    'issue if you cannot hear anything at all.'
                : 'That was not the number of beeps. Play a new set, or '
                    'report an issue if you cannot hear anything at all.',
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        CheckupActions(
          attempt: _attempt,
          retryLabel: 'Play again',
          onRetry: (_playing || _preparing) ? null : _retry,
          onIssue: () => markFail(
            _spoken
                ? 'User could not make out the spoken number through the '
                    'earpiece after $_attempt attempt(s)'
                : 'User could not count the beeps through the earpiece after '
                    '$_attempt attempt(s)',
          ),
          onSkip: skipTest,
        ),
      ],
    );
  }

  Widget _playingTile() {
    final String label;
    if (_preparing) {
      label = 'Getting ready…';
    } else if (_playing) {
      label = 'Playing through the earpiece…';
    } else if (_played) {
      label = _spoken
          ? 'Finished. Tap the number you heard.'
          : 'Finished. Tap how many beeps you heard.';
    } else {
      label = 'Getting ready…';
    }

    final busy = _playing || _preparing;

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
            busy ? Icons.graphic_eq_rounded : Icons.replay_rounded,
            color: _playing ? AppColors.onPrimarySoft : AppColors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                color:
                    _playing ? AppColors.onPrimarySoft : AppColors.textPrimary,
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
        if (i > 0) const SizedBox(height: AppSpacing.sm),
        _OptionTile(
          label: _spoken ? '${_options[i]}' : '${_options[i]} beeps',
          enabled: !_playing && !_preparing,
          wrong: _wrongPick == _options[i],
          onTap: () => _pick(_options[i]),
        ),
      ],
    ];
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.enabled,
    required this.wrong,
    required this.onTap,
  });

  final String label;
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
          label,
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
