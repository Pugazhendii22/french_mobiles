// Animating between tabs without rebuilding them.
//
// Switching destinations was a cut — an IndexedStack changes which child it
// paints and the new page is simply there. The obvious fix is AnimatedSwitcher,
// which animates by building the new child and disposing the old: every tab
// would lose its scroll position and re-run its Firestore reads on the way
// back. So the property that matters here is not that it animates, it is that
// it animates *and* keeps state.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/shared/motion/motion.dart';

/// Counts how many times each tab's State was created.
late List<int> built;

class _Tab extends StatefulWidget {
  const _Tab({required this.index});

  final int index;

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  int taps = 0;

  @override
  void initState() {
    super.initState();
    built[widget.index]++;
  }

  @override
  Widget build(BuildContext context) => Center(
        child: TextButton(
          onPressed: () => setState(() => taps++),
          child: Text('tab ${widget.index}: $taps'),
        ),
      );
}

class _Host extends StatefulWidget {
  const _Host();

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppTabSwitcher(
        index: index,
        children: const [_Tab(index: 0), _Tab(index: 1), _Tab(index: 2)],
      ),
      bottomNavigationBar: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var i = 0; i < 3; i++)
            TextButton(
              onPressed: () => setState(() => index = i),
              child: Text('go $i'),
            ),
        ],
      ),
    );
  }
}

Future<void> _pump(WidgetTester t) async {
  built = [0, 0, 0];
  t.view.physicalSize = const Size(400, 800);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);

  await t.pumpWidget(const MaterialApp(home: _Host()));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('switching tabs does not rebuild them', (t) async {
    await _pump(t);
    expect(built, [1, 1, 1]);

    await t.tap(find.text('go 1'));
    await t.pumpAndSettle();
    await t.tap(find.text('go 0'));
    await t.pumpAndSettle();

    expect(built, [1, 1, 1],
        reason: 'a rebuild here is a lost scroll position and a repeated '
            'Firestore read every time someone changes tab');
  });

  testWidgets('a tab keeps its state across a switch', (t) async {
    await _pump(t);

    await t.tap(find.text('tab 0: 0'));
    await t.pumpAndSettle();
    expect(find.text('tab 0: 1'), findsOneWidget);

    await t.tap(find.text('go 2'));
    await t.pumpAndSettle();
    await t.tap(find.text('go 0'));
    await t.pumpAndSettle();

    expect(find.text('tab 0: 1'), findsOneWidget);
  });

  testWidgets('both tabs are on screen mid-transition', (t) async {
    await _pump(t);

    await t.tap(find.text('go 1'));
    await t.pump();
    // Part-way through: the old one is still fading out.
    await t.pump(const Duration(milliseconds: 80));

    expect(find.text('tab 0: 0', skipOffstage: false), findsOneWidget);
    expect(find.text('tab 1: 0', skipOffstage: false), findsOneWidget);

    final opacities = t
        .widgetList<Opacity>(find.byType(Opacity))
        .map((o) => o.opacity)
        .where((o) => o > 0 && o < 1);
    expect(opacities, isNotEmpty,
        reason: 'something has to be part-way faded, or this is still a cut');

    await t.pumpAndSettle();
  });

  testWidgets('the settled tab is fully opaque and the rest are hidden',
      (t) async {
    await _pump(t);
    await t.tap(find.text('go 1'));
    await t.pumpAndSettle();

    expect(find.text('tab 1: 0'), findsOneWidget);
    expect(find.text('tab 0: 0'), findsNothing,
        reason: 'offstage once the swap is done, so it cannot be read or '
            'tapped by accident');
  });

  testWidgets('the outgoing tab stops taking taps immediately', (t) async {
    await _pump(t);

    await t.tap(find.text('go 1'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 40));

    // Still painted, but must not respond.
    final ignoring = t
        .widgetList<IgnorePointer>(find.byType(IgnorePointer))
        .where((w) => w.ignoring);
    expect(ignoring, isNotEmpty);

    await t.pumpAndSettle();
  });

  testWidgets('reduced motion swaps without animating', (t) async {
    built = [0, 0, 0];
    t.view.physicalSize = const Size(400, 800);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(const MediaQuery(
      data: MediaQueryData(disableAnimations: true),
      child: MaterialApp(home: _Host()),
    ));
    await t.pumpAndSettle();

    await t.tap(find.text('go 1'));
    await t.pump();

    expect(find.text('tab 1: 0'), findsOneWidget,
        reason: 'vestibular disorders make this an accessibility setting, '
            'not a preference');
    expect(built, [1, 1, 1]);
  });
}
