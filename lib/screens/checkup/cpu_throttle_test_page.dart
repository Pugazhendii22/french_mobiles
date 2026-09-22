import 'dart:async';
import 'dart:io' show Platform;
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/widgets.dart';
import 'checkup_demo.dart';
import 'checkup_test_shell.dart';

/// One second of work.
class ThroughputSample {
  const ThroughputSample({required this.atSecond, required this.opsPerSecond});

  final int atSecond;
  final double opsPerSecond;
}

/// Whether the processor can hold its speed, or folds when it gets warm.
///
/// Chipset *specifications* are worth nothing here: the model is already
/// known from the catalogue, so "eight cores, 2.4GHz" is a fact about the
/// phone's name rather than about its condition, and it moves no price.
/// Sustained performance is different — a phone that starts fast and halves
/// its speed after a minute has something wrong with it: dried thermal
/// compound, a swelling battery pressing on the board, a failing SoC. That is
/// a fault a buyer discovers and a seller rarely mentions.
///
/// Measured as work done per second rather than by reading clock speeds from
/// /sys/devices/system/cpu. Those files are unreadable on most modern Android
/// — SELinux closed them — and where they can be read the governor's numbers
/// describe intent rather than delivery. Counting completed work needs no
/// permissions and cannot be fooled by a governor lying about its plans.
class CpuThrottleTestPage extends StatefulWidget {
  const CpuThrottleTestPage({super.key});

  @override
  State<CpuThrottleTestPage> createState() => _CpuThrottleTestPageState();
}

class _CpuThrottleTestPageState extends State<CpuThrottleTestPage>
    with CheckupTestFlow<CpuThrottleTestPage> {
  /// Long enough for a phone to get warm and the governor to react. Under
  /// about forty seconds almost nothing throttles and the test says nothing.
  static const int _seconds = 60;

  /// Sustained work below this share of the peak counts as throttling. Every
  /// phone drops a little; halving is not "a little".
  static const double _failRatio = 0.62;

  /// The platform's own account of whether it is holding the phone back —
  /// better evidence than anything inferred, and free.
  static const _thermal = MethodChannel('french_mobiles/thermal');

  /// Beyond this the system says it is at the throttling threshold.
  static const double _headroomLimit = 1.0;

  @override
  String get testKey => 'cpu_throttle';
  @override
  String get testTitle => 'Processor under load';

  final List<ThroughputSample> _samples = [];
  /// One worker per core.
  ///
  /// A single isolate is a single core, and a modern phone has eight — so the
  /// old one-worker test loaded about an eighth of the processor, which the
  /// scheduler was free to park on a little core. It never got the die warm
  /// enough to throttle, so it never measured the thing it exists to measure.
  final List<Isolate> _workers = [];
  ReceivePort? _port;
  Timer? _ticker;
  bool _running = false;
  int _elapsed = 0;
  int _attempt = 1;

  String? _thermalStatus;
  double? _headroom;
  double? _startTemperature;
  double? _peakTemperature;

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
    _ticker?.cancel();
    _ticker = null;
    _port?.close();
    _port = null;
    // Killing it matters: the loop below never returns on its own, so a
    // worker left running would keep a core pinned for the rest of the
    // session and quietly flatten the battery.
    for (final worker in _workers) {
      worker.kill(priority: Isolate.immediate);
    }
    _workers.clear();
  }

  Future<void> _start() async {
    setState(() {
      _running = true;
      _elapsed = 0;
      _samples.clear();
    });

    final port = ReceivePort();
    _port = port;

    // One short of the core count, so the UI isolate still has somewhere to
    // run — a phone that cannot repaint looks like a crash, and a frozen
    // screen is indistinguishable from a failed test. Always at least one.
    final cores = Platform.numberOfProcessors;
    final workers = (cores - 1).clamp(1, 16);

    for (var i = 0; i < workers; i++) {
      _workers.add(await Isolate.spawn(_burn, port.sendPort));
    }

    // Each worker reports once a second on its own clock, so their messages
    // interleave rather than arrive together. Summing per worker and only
    // then taking a sample keeps one slow worker from reading as a drop in
    // total throughput.
    final latest = <int, double>{};
    port.listen((message) {
      if (!mounted || message is! List || message.length != 2) return;
      final id = message[0] as int;
      latest[id] = message[1] as double;
      if (latest.length < workers) return;
      final total = latest.values.reduce((a, b) => a + b);
      latest.clear();
      setState(() {
        _samples.add(
          ThroughputSample(atSecond: _samples.length, opsPerSecond: total),
        );
      });
    });

    await _readThermal();
    _startTemperature = _peakTemperature;

    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _elapsed++);
      // Every few seconds is plenty; the phone does not heat up in one.
      if (_elapsed % 3 == 0) _readThermal();
      if (_elapsed >= _seconds) _finish();
    });
  }

  /// Asks the platform how hot it is and how close to being held back.
  Future<void> _readThermal() async {
    Map<String, dynamic>? reading;
    try {
      reading = (await _thermal
              .invokeMapMethod<String, dynamic>('read')
              .timeout(const Duration(seconds: 3)))
          ?.cast<String, dynamic>();
    } catch (_) {
      // Not Android, or no thermal HAL. The throughput measurement stands on
      // its own; this only corroborates it.
      return;
    }
    if (!mounted || reading == null) return;

    final sensors = reading['sensors'];
    double? hottest;
    if (sensors is List && sensors.isNotEmpty) {
      final first = sensors.first;
      if (first is Map) hottest = (first['celsius'] as num?)?.toDouble();
    }

    setState(() {
      _thermalStatus = reading!['status'] as String?;
      _headroom = (reading['headroom'] as num?)?.toDouble();
      if (hottest != null) {
        _peakTemperature = _peakTemperature == null
            ? hottest
            : (hottest > _peakTemperature! ? hottest : _peakTemperature);
      }
    });
  }

  /// Busy work, reporting how much of it got done each second.
  ///
  /// Deliberately integer arithmetic with a data dependency between rounds,
  /// so the compiler cannot hoist or vectorise it away and leave the test
  /// measuring nothing.
  static void _burn(SendPort send) {
    final id = identityHashCode(send);
    var accumulator = 1;
    var float = 1.0000001;
    while (true) {
      final watch = Stopwatch()..start();
      var rounds = 0;
      while (watch.elapsedMilliseconds < 1000) {
        for (var i = 0; i < 20000; i++) {
          accumulator = (accumulator * 1103515245 + 12345) & 0x3FFFFFFF;
          // Floating-point work alongside the integer arithmetic, because the
          // two use different silicon: an integer-only loop leaves the FPU
          // idle and draws far less power than real use does.
          float = float * 1.0000001 + 0.0000001;
          if (float > 2.0) float = 1.0000001;
        }
        rounds++;
      }
      // The float is folded into the result so nothing above can be optimised
      // away as dead code.
      final guard = float > 0 ? 1 : 0;
      send.send([
        id,
        rounds * 20000 * guard / (watch.elapsedMicroseconds / 1e6),
      ]);
    }
  }

  double get _peak => _samples.isEmpty
      ? 0
      : _samples.map((s) => s.opsPerSecond).reduce((a, b) => a > b ? a : b);

  /// The last third of the run: what the phone can actually hold, as opposed
  /// to what it manages in the first few seconds while still cold.
  double get _sustained {
    if (_samples.length < 3) return _peak;
    final tail = _samples.skip((_samples.length * 2 / 3).floor()).toList();
    final total = tail.fold<double>(0, (sum, s) => sum + s.opsPerSecond);
    return total / tail.length;
  }

  double get _ratio => _peak == 0 ? 1 : _sustained / _peak;

  void _finish() {
    disposeHardware();
    if (!mounted) return;

    if (_samples.length < 5) {
      markNotAvailable('The processor could not be measured for long enough '
          'to say anything useful.');
      return;
    }

    final percent = (_ratio * 100).round();
    final status = _thermalStatus;
    final headroom = _headroom;

    final data = <String, dynamic>{
      'sustainedRatio': double.parse(_ratio.toStringAsFixed(3)),
      'seconds': _samples.length,
      if (status != null) 'thermalStatus': status,
      if (headroom != null)
        'thermalHeadroom': double.parse(headroom.toStringAsFixed(2)),
      if (_peakTemperature != null) 'peakTemperatureCelsius': _peakTemperature,
    };

    final heat = _heatWords();

    // The system saying it is throttling hard is a fault on its own, even if
    // the work held up — it means the phone only kept pace by running at a
    // temperature it cannot sustain.
    final systemThrottling =
        status == 'severe' || status == 'critical' || status == 'emergency';

    if (_ratio < _failRatio || systemThrottling) {
      markFail(
        'The processor held only $percent% of its peak speed over '
        '${_samples.length}s$heat. A drop this steep usually means the phone '
        'is overheating — worn thermal paste, or a swelling battery against '
        'the board.',
        data: data,
      );
      return;
    }

    markPass(
      'The processor held $percent% of its peak speed over '
      '${_samples.length}s$heat, which is normal.',
      data: data,
    );
  }

  /// The thermal detail, as a clause to append to a sentence.
  String _heatWords() {
    final parts = <String>[];
    final status = _thermalStatus;
    if (status != null && status != 'none') parts.add('thermal load $status');

    final start = _startTemperature;
    final peak = _peakTemperature;
    if (start != null && peak != null && peak > start) {
      parts.add('${start.round()}°C rising to ${peak.round()}°C');
    } else if (peak != null) {
      parts.add('${peak.round()}°C');
    }

    final headroom = _headroom;
    if (headroom != null && headroom >= _headroomLimit) {
      parts.add('at the system\'s throttling threshold');
    }

    return parts.isEmpty ? '' : ' (${parts.join(', ')})';
  }

  void _stopEarly() {
    _ticker?.cancel();
    _finish();
  }

  void _retry() {
    disposeHardware();
    setState(() => _attempt++);
    _start();
  }

  @override
  Widget build(BuildContext context) {
    return CheckupTestShell(
      title: 'Processor',
      child: result != null ? CheckupVerdict(result: result!) : _testView(),
    );
  }

  Widget _testView() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        CheckupInstruction(
          icon: Icons.memory_rounded,
          busy: _running,
          demo: CheckupDemoKind.cpuLoad,
          text: 'Working the processor hard to see whether it can keep the '
              'pace up. The phone will get warm — that is the point. Leave '
              'this page open.',
        ),
        const SizedBox(height: AppSpacing.lg),
        _progress(),
        const SizedBox(height: AppSpacing.md),
        if (_thermalStatus != null || _peakTemperature != null) ...[
          _thermalCard(),
          const SizedBox(height: AppSpacing.md),
        ],
        _graph(),
        const SizedBox(height: AppSpacing.lg),
        CheckupActions(
          attempt: _attempt,
          primary: _samples.length >= 5 ? _stopEarly : null,
          primaryLabel: 'Finish now and record this',
          onRetry: _running && _samples.length < 5 ? null : _retry,
          retryLabel: 'Run again',
          onIssue: () => markFail('User reported the phone overheating'),
          onSkip: skipTest,
        ),
      ],
    );
  }

  Widget _progress() {
    final percent = (_ratio * 100).round();

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
              Text('${_elapsed}s / ${_seconds}s', style: AppTextStyles.h3),
              const Spacer(),
              if (_samples.length >= 3)
                Text(
                  '$percent% of peak',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: _ratio < _failRatio
                        ? AppColors.error
                        : AppColors.success,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_elapsed / _seconds).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thermalCard() {
    final status = _thermalStatus ?? 'unknown';
    final headroom = _headroom;
    final peak = _peakTemperature;

    // The system's own scale. Light is ordinary under load; severe upward
    // means it is actively holding the phone back.
    final hot = status == 'severe' ||
        status == 'critical' ||
        status == 'emergency' ||
        (headroom != null && headroom >= _headroomLimit);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Icon(
            Icons.thermostat_rounded,
            size: 30,
            color: hot ? AppColors.error : AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      peak == null
                          ? 'Thermal load'
                          : '${peak.toStringAsFixed(1)}°C',
                      style: AppTextStyles.h3.copyWith(
                        color: hot ? AppColors.error : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppBadge(
                      label: status,
                      tone: hot ? AppBadgeTone.error : AppBadgeTone.neutral,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  headroom == null
                      ? 'Reported by the system while the test runs'
                      : 'Headroom ${(headroom * 100).round()}% of the '
                          'throttling threshold',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _graph() {
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
          Text('Work done each second', style: AppTextStyles.bodyMedium),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 92,
            width: double.infinity,
            child: _samples.isEmpty
                ? Center(
                    child: Text('Warming up…', style: AppTextStyles.caption))
                : CustomPaint(
                    painter: _ThroughputPainter(
                      samples: _samples,
                      totalSeconds: _seconds,
                      peak: _peak,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// One bar per second, scaled against the fastest second of the run.
///
/// Drawn relative to the phone's own peak rather than to an absolute figure,
/// because the question is not how fast this processor is — it is whether it
/// can still do what it was doing a minute ago.
class _ThroughputPainter extends CustomPainter {
  _ThroughputPainter({
    required this.samples,
    required this.totalSeconds,
    required this.peak,
  });

  final List<ThroughputSample> samples;
  final int totalSeconds;
  final double peak;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(0, size.height - 1),
      Offset(size.width, size.height - 1),
      Paint()
        ..color = AppColors.border
        ..strokeWidth = 1,
    );
    if (samples.isEmpty || peak <= 0) return;

    final slot = size.width / totalSeconds;
    final barWidth = (slot * 0.62).clamp(2.0, 12.0);

    for (final sample in samples) {
      final share = (sample.opsPerSecond / peak).clamp(0.0, 1.0);
      final height = (size.height - 2) * share;
      final x = sample.atSecond * slot + slot / 2;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            (x - barWidth / 2).clamp(0.0, size.width - barWidth),
            size.height - 1 - height,
            barWidth,
            height,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = Color.lerp(AppColors.error, AppColors.success, share)!,
      );
    }
  }

  @override
  bool shouldRepaint(_ThroughputPainter old) =>
      old.samples.length != samples.length || old.peak != peak;
}
