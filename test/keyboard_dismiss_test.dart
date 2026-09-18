// Leaving a screen dismisses its keyboard.
//
// A FocusNode keeps its focus while its page sits under a pushed route, so
// returning re-opens the keyboard over a page the user came back to look at.
// Tapping search on home, opening a phone and pressing back landed on the
// list with the keyboard already up and the field still active.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/features/home/data/home_repository.dart';
import 'package:french_mobiles/features/shell/main_shell.dart';
import 'package:french_mobiles/shared/motion/motion.dart';

/// Focus nodes by label, so a test can ask whether a specific field still
/// holds focus. Checking FocusManager.primaryFocus does not answer that:
/// after an unfocus the primary focus moves to the enclosing scope, which
/// legitimately has it.
final Map<String, FocusNode> nodes = {};

/// A page with a field that can be focused, and a button that pushes.
class _Searchable extends StatefulWidget {
  const _Searchable({this.label = 'field'});

  final String label;

  @override
  State<_Searchable> createState() => _SearchableState();
}

class _SearchableState extends State<_Searchable> {
  late final FocusNode node =
      nodes.putIfAbsent(widget.label, () => FocusNode());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TextField(
            focusNode: node,
            decoration: InputDecoration(hintText: widget.label),
          ),
          TextButton(
            onPressed: () => context.pushScreen(const _Elsewhere()),
            child: const Text('open'),
          ),
        ],
      ),
    );
  }
}

class _Elsewhere extends StatelessWidget {
  const _Elsewhere();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('back'),
          ),
        ),
      );
}

class _Repo extends HomeRepository {
  const _Repo();
  @override
  bool get isSignedIn => true;
}

Future<void> _boot(WidgetTester t, Widget home) async {
  t.view.physicalSize = const Size(400, 800);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(home: home));
  await t.pump();
}

void main() {
  setUp(() {
    for (final node in nodes.values) {
      node.dispose();
    }
    nodes.clear();
  });

  testWidgets('pushing a screen drops the focus behind it', (t) async {
    await _boot(t, const _Searchable());

    await t.tap(find.byType(TextField));
    await t.pumpAndSettle();
    expect(nodes['field']!.hasFocus, isTrue);

    await t.tap(find.text('open'));
    await t.pumpAndSettle();

    expect(nodes['field']!.hasFocus, isFalse,
        reason: 'the field must not still hold focus under the pushed route');
  });

  testWidgets('coming back does not re-open the keyboard', (t) async {
    await _boot(t, const _Searchable());

    await t.tap(find.byType(TextField));
    await t.pumpAndSettle();

    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tap(find.text('back'));
    await t.pumpAndSettle();

    // The keyboard is a platform view; what the framework controls is
    // whether anything is still asking for it.
    expect(nodes['field']!.hasFocus, isFalse,
        reason: 'returning to a page should not put the keyboard back up');
  });

  testWidgets('switching tabs drops the focus too', (t) async {
    await _boot(
      t,
      MainShell(
        repository: const _Repo(),
        pageBuilder: (tab) =>
            _Searchable(label: tab.name),
      ),
    );

    await t.tap(find.byType(TextField).first);
    await t.pumpAndSettle();
    expect(nodes['home']!.hasFocus, isTrue);

    await t.tap(find.text('Sell'));
    await t.pumpAndSettle();

    expect(nodes['home']!.hasFocus, isFalse,
        reason: 'the tab being left keeps its focus otherwise, and returning '
            'to it re-opens the keyboard');
  });

  testWidgets('a field can still be focused normally', (t) async {
    await _boot(t, const _Searchable());

    await t.tap(find.byType(TextField));
    await t.pumpAndSettle();

    expect(nodes['field']!.hasFocus, isTrue,
        reason: 'dismissing on navigation must not stop search working');
  });
}
