import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/theme/app_theme.dart';
import 'checkup_demo.dart';
import 'checkup_test_shell.dart';

/// One probe of the mobile data connection.
class ConnectionSample {
  const ConnectionSample({
    required this.atSecond,
    required this.reached,
    this.millis,
  });

  /// Seconds since the watch started, for the time axis.
  final int atSecond;

  /// Whether the probe actually got through to the internet.
  final bool reached;

  /// Round trip in milliseconds, null when it did not get through.
  final int? millis;
}

/// Mobile data held over several minutes, rather than at one instant.
///
/// The existing Internet test answers "does data work right now", which a
/// failing modem passes: a phone with a cracked antenna seat or a dying RF
/// chip commonly registers, connects, works for a minute or two and then goes
/// quiet until it is power-cycled. That is precisely the fault a seller may
/// not mention and a buyer discovers on day two, so it is worth the minutes
/// it costs to catch.
///
/// Reachability is measured, not signal bars. Bars are what the radio claims;
/// they sit at full strength on a phone whose data is dead because the bill
/// is unpaid or the APN never provisioned. A 204 probe over the cellular
/// route is the only thing that proves the phone can actually use the
/// connection.
///
/// A single missed probe does not count against the phone — servers hiccup,
/// and a test that fails a working handset is worse than no test. A dropout
/// means two consecutive misses.
class InternetStabilityTestPage extends StatefulWidget {
  const InternetStabilityTestPage({super.key});

  @override
  State<InternetStabilityTestPage> createState() =>
      _InternetStabilityTestPageState();
}

class _InternetStabilityTestPageState extends State<InternetStabilityTestPage>
    with CheckupTestFlow<InternetStabilityTestPage> {
  /// Shared with the one-shot Internet test — it already knows how to send a
  /// request over the cellular network specifically, which is the whole point:
  /// an ordinary request would go out over Wi-Fi and prove nothing.
  static const _channel = MethodChannel('french_mobiles/internet');

  static const Duration _interval = Duration(seconds: 10);
  static const int _blockSeconds = 180;

  /// Below this, the connection is called unreliable even with no full
  /// dropout — a phone that answers four probes in five is not usable.
  static const double _passRatio = 0.9;

  @override
  String get testKey => 'internet_stability';
  @override
  String get testTitle => 'Connection stability';

  final List<ConnectionSample> _samples = [];
  final Stopwatch _watch = Stopwatch();

  int _targetSeconds = _blockSeconds;
  bool _stopped = false;
  bool _running = false;
  Timer? _ticker;

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
    _stopped = true;
    _ticker?.cancel();
    _watch.stop();
  }

  Future<void> _run() async {
    setState(() => _running = true);
    _watch.start();

    // Redraws the clock between probes; the samples arrive only every 10s and
    // a timer that appears frozen reads as a hung test.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_stopped) setState(() {});
    });

    while (mounted && !_stopped && _watch.elapsed.inSeconds < _targetSeconds) {
      final startedAt = _watch.elapsed;
      final sample = await _probe(startedAt.inSeconds);
      if (!mounted || _stopped) return;

      // Nothing to measure over time if there is no mobile network at all.
      // Better to say so in seconds than to sit for three minutes recording
      // failures that say nothing about the hardware.
      if (sample == null) {
        disposeHardware();
        markNotAvailable(
          'No mobile data network was offered, so the modem could not be '
          'watched. Insert a SIM with an active data plan and retry.',
        );
        return;
      }

      setState(() => _samples.add(sample));

      final spent = _watch.elapsed - startedAt;
      final wait = _interval - spent;
      if (wait > Duration.zero) {
        await Future<void>.delayed(wait);
      }
    }

    if (!mounted || _stopped) return;
    _conclude();
  }

  /// One probe over the cellular route. Null means there is no cellular route
  /// to probe, which is a different thing from a probe that failed.
  Future<ConnectionSample?> _probe(int atSecond) async {
    try {
      final raw = await _channel
          .invokeMapMethod<String, dynamic>('probeCellular')
          .timeout(const Duration(seconds: 9));

      if (raw == null) return null;

      switch (raw['status']) {
        case 'ok':
          return ConnectionSample(
            atSecond: atSecond,
            reached: true,
            millis: (raw['ms'] as num?)?.round(),
          );
        case 'no_cellular':
          return null;
        // A captive portal is not the internet, so it counts as a miss rather
        // than a pass — the phone cannot use the connection either way.
        default:
          return ConnectionSample(atSecond: atSecond, reached: false);
      }
    } on MissingPluginException {
      return null;
    } catch (_) {
      return ConnectionSample(atSecond: atSecond, reached: false);
    }
  }

  int get _reached => _samples.where((s) => s.reached).length;

  double get _uptime => _samples.isEmpty ? 0 : _reached / _samples.length;

  /// Runs of two or more consecutive misses. One miss on its own is treated
  /// as noise, not as the phone dropping the network.
  List<int> get _dropoutLengths {
    final runs = <int>[];
    var current = 0;
    for (final sample in _samples) {
      if (sample.reached) {
        if (current >= 2) runs.add(current);
        current = 0;
      } else {
        current++;
      }
    }
    if (current >= 2) runs.add(current);
    return runs;
  }

  int? get _averageMillis {
    final times = _samples
        .where((s) => s.reached && s.millis != null)
        .map((s) => s.millis!)
        .toList();
    if (times.isEmpty) return null;
    return times.reduce((a, b) => a + b) ~/ times.length;
  }

  void _conclude() {
    disposeHardware();

    if (_samples.isEmpty) {
      markNotAvailable('The connection could not be sampled.');
      return;
    }

    final dropouts = _dropoutLengths;
    final watched = _formatDuration(_watch.elapsed.inSeconds);
    final percent = (_uptime * 100).round();
    final latency = _averageMillis;
    final speed = latency != null ? ' · typically ${latency}ms' : '';

    if (dropouts.isEmpty && _uptime >= _passRatio) {
      markPass('Mobile data stayed connected for $percent% of $watched'
          ' with no dropouts$speed');
      return;
    }

    final longest = dropouts.isEmpty
        ? 0
        : dropouts.reduce((a, b) => a > b ? a : b) * _interval.inSeconds;
    final dropText = dropouts.isEmpty
        ? 'no full dropout, but $percent% of probes got through'
        : '${dropouts.length} dropout${dropouts.length == 1 ? '' : 's'}, '
            'the longest about ${longest}s';

    markFail('Mobile data was unreliable over $watched: $dropText$speed. '
        'This is the pattern of a failing modem or antenna.');
  }

  void _stopNow() {
    if (_samples.isEmpty) {
      skipTest();
      return;
    }
    _stopped = true;
    _ticker?.cancel();
    _watch.stop();
    _conclude();
  }

  void _extend() {
    setState(() => _targetSeconds += _blockSeconds);
  }

  static String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return m > 0 ? '${m}m ${s.toString().padLeft(2, '0')}s' : '${s}s';
  }

  static String _clock(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return CheckupTestShell(
      title: 'Connection stability',
      child: result != null ? CheckupVerdict(result: result!) : _testView(),
    );
  }

  Widget _testView() {
    final elapsed = _watch.elapsed.inSeconds.clamp(0, _targetSeconds);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        CheckupInstruction(
          demo: CheckupDemoKind.connectionGraph,
          icon: Icons.timeline_rounded,
          busy: _running,
          text: 'Watching whether mobile data stays up, not just whether it '
              'works this second. You can keep using the phone — leave this '
              'page open until it finishes.',
        ),
        const SizedBox(height: AppSpacing.lg),
        _progressCard(elapsed),
        const SizedBox(height: AppSpacing.md),
        _graphCard(),
        const SizedBox(height: AppSpacing.lg),
        CheckupActions(
          primary: _samples.isEmpty ? null : _stopNow,
          primaryLabel: 'Finish now and record this',
          onRetry: _extend,
          retryLabel: '+3 more minutes',
          onIssue: () => markFail(
            'User reported a mobile data problem during the stability watch',
          ),
          onSkip: skipTest,
        ),
      ],
    );
  }

  Widget _progressCard(int elapsed) {
    final dropouts = _dropoutLengths.length;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${_clock(elapsed)} / ${_clock(_targetSeconds)}',
                style: AppTextStyles.h3,
              ),
              const Spacer(),
              if (_samples.isNotEmpty)
                Text(
                  '${(_uptime * 100).round()}% connected',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: _uptime >= _passRatio
                        ? AppColors.success
                        : AppColors.error,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _targetSeconds == 0 ? 0 : elapsed / _targetSeconds,
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _samples.isEmpty
                ? 'Taking the first reading…'
                : '${_samples.length} checks so far · '
                    '${dropouts == 0 ? 'no dropouts' : '$dropouts dropout${dropouts == 1 ? '' : 's'}'}',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }

  Widget _graphCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Connection over time', style: AppTextStyles.bodyMedium),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 92,
            width: double.infinity,
            child: _samples.isEmpty
                ? Center(
                    child:
                        Text('No readings yet', style: AppTextStyles.caption),
                  )
                : CustomPaint(
                    painter: _StabilityGraphPainter(
                      samples: _samples,
                      totalSeconds: _targetSeconds,
                    ),
                  ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _legendDot(AppColors.success, 'Reached — taller is faster'),
              const SizedBox(width: AppSpacing.md),
              _legendDot(AppColors.error, 'Missed'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color colour, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}

/// One bar per probe across a fixed time axis.
///
/// A reached probe is drawn green and as tall as it was fast, so a connection
/// degrading before it drops is visible rather than only the drop itself. A
/// miss is a full-height red bar: the alarming thing should look alarming.
class _StabilityGraphPainter extends CustomPainter {
  _StabilityGraphPainter({required this.samples, required this.totalSeconds});

  final List<ConnectionSample> samples;
  final int totalSeconds;

  /// A probe slower than this is drawn at the minimum height. Well past the
  /// point where a connection feels broken.
  static const double _slowMillis = 1500;

  @override
  void paint(Canvas canvas, Size size) {
    final baseline = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height - 1),
      Offset(size.width, size.height - 1),
      baseline,
    );

    if (samples.isEmpty || totalSeconds <= 0) return;

    // Bars are placed by when they happened, not by index, so a gap where
    // probes were slow to return reads as a gap.
    final slotWidth = size.width / ((totalSeconds / 10).ceil().clamp(1, 1000));
    final barWidth = (slotWidth * 0.6).clamp(2.0, 14.0);

    for (final sample in samples) {
      final x = (sample.atSecond / totalSeconds) * size.width;

      final double heightFraction;
      final Color colour;
      if (sample.reached) {
        final ms = (sample.millis ?? 0).toDouble();
        heightFraction = (1 - (ms / _slowMillis)).clamp(0.25, 1.0);
        colour = AppColors.success;
      } else {
        heightFraction = 1;
        colour = AppColors.error;
      }

      final barHeight = (size.height - 2) * heightFraction;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          (x - barWidth / 2).clamp(0.0, size.width - barWidth),
          size.height - 1 - barHeight,
          barWidth,
          barHeight,
        ),
        const Radius.circular(2),
      );
      canvas.drawRRect(rect, Paint()..color = colour);
    }
  }

  @override
  bool shouldRepaint(_StabilityGraphPainter oldDelegate) =>
      oldDelegate.samples.length != samples.length ||
      oldDelegate.totalSeconds != totalSeconds;
}
