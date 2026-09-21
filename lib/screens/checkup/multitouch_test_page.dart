import 'package:flutter/material.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/theme/app_theme.dart';
import 'checkup_demo.dart';
import 'checkup_test_shell.dart';

/// Multi-touch.
///
/// Genuinely verifiable: the pass requires the digitiser to report the
/// required number of simultaneous pointers, which cannot be faked by the
/// user. The display test already covers dead zones by swipe coverage, but
/// only ever tracks one finger — a panel can register single touches
/// perfectly while failing to separate two.
class MultitouchTestPage extends StatefulWidget {
  const MultitouchTestPage({super.key});

  @override
  State<MultitouchTestPage> createState() => _MultitouchTestPageState();
}

class _MultitouchTestPageState extends State<MultitouchTestPage>
    with CheckupTestFlow<MultitouchTestPage> {
  /// Two is the meaningful floor (pinch-to-zoom); five is what most panels
  /// support and what a buyer would expect to work.
  static const int _required = 5;

  @override
  String get testKey => 'multitouch';
  @override
  String get testTitle => 'Multi-touch';

  final Map<int, Offset> _pointers = {};
  int _maxSeen = 0;
  int _attempt = 1;

  void _update() {
    final count = _pointers.length;
    if (count > _maxSeen) {
      _maxSeen = count;
      if (_maxSeen >= _required) {
        markPass('Registered $_maxSeen simultaneous touch points');
        return;
      }
    }
    setState(() {});
  }

  void _retry() {
    setState(() {
      _attempt++;
      _pointers.clear();
      _maxSeen = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CheckupTestShell(
      title: 'Multi-touch',
      child: result != null ? CheckupVerdict(result: result!) : _testView(),
    );
  }

  Widget _testView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CheckupInstruction(
            demo: CheckupDemoKind.fiveFingers,
            icon: Icons.touch_app_outlined,
            text: 'Place $_required fingers on the panel below at the same '
                'time. Best seen so far: $_maxSeen of $_required.',
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: _panel()),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: CheckupActions(
            attempt: _attempt,
            onRetry: _maxSeen > 0 ? _retry : null,
            onIssue: () => markFail(
              'Panel registered at most $_maxSeen simultaneous touch points '
              '(needs $_required)',
            ),
            onSkip: skipTest,
          ),
        ),
      ],
    );
  }

  Widget _panel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          _pointers[e.pointer] = e.localPosition;
          _update();
        },
        onPointerMove: (e) {
          _pointers[e.pointer] = e.localPosition;
          _update();
        },
        onPointerUp: (e) {
          _pointers.remove(e.pointer);
          _update();
        },
        onPointerCancel: (e) {
          _pointers.remove(e.pointer);
          _update();
        },
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.card,
            border: Border.all(
              color: _pointers.isEmpty ? AppColors.border : AppColors.primary,
              width: _pointers.isEmpty ? 1 : 1.5,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  '${_pointers.length}',
                  style: AppTextStyles.h1.copyWith(
                    // Deliberately outsized: it is a readout filling the
                    // panel behind the touch points, not a heading.
                    fontSize: 64,
                    color: AppColors.border,
                  ),
                ),
              ),
              for (final entry in _pointers.entries)
                Positioned(
                  left: entry.value.dx - 28,
                  top: entry.value.dy - 28,
                  child: Container(
                    height: 56,
                    width: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
