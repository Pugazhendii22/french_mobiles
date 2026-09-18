// The shell that holds the five main destinations.
//
// The bar used to live on Home alone, and every other destination was pushed
// on top of it, so it vanished the moment you went anywhere. What matters now
// is that the five sit side by side under one bar, that a tab is not built
// until it is opened, and that opening one and coming back does not throw
// away what was on it.
//
// Every real destination reads Firebase on its first frame, so these run
// against stand-in pages through the shell's pageBuilder seam.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/features/home/data/home_repository.dart';
import 'package:french_mobiles/features/home/widgets/home_bottom_nav.dart';
import 'package:french_mobiles/features/shell/main_shell.dart';
import 'package:french_mobiles/screens/login_page.dart';

/// Answers the shell's sign-in gate without a Firebase User.
class _Repo extends HomeRepository {
  const _Repo({required this.signedIn});

  final bool signedIn;

  @override
  bool get isSignedIn => signedIn;
}

/// Records which tabs were ever built, so laziness can be asserted.
final List<HomeNavTab> built = [];

/// A stand-in page that keeps a little state, to prove state survives a
/// switch away and back.
class _Stand extends StatefulWidget {
  const _Stand({required this.tab});

  final HomeNavTab tab;

  @override
  State<_Stand> createState() => _StandState();
}

class _StandState extends State<_Stand> {
  int taps = 0;

  @override
  void initState() {
    super.initState();
    built.add(widget.tab);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => setState(() => taps++),
          child: Text('${widget.tab.name} taps: $taps'),
        ),
      ),
    );
  }
}

Future<void> _pump(
  WidgetTester t, {
  Size size = const Size(400, 800),
  bool signedIn = true,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);

  await t.pumpWidget(MaterialApp(
    home: MainShell(
      pageBuilder: (tab) => _Stand(tab: tab),
      repository: _Repo(signedIn: signedIn),
    ),
  ));
  await t.pump();
}

void main() {
  setUp(() {
    built.clear();
    MainShell.request.value = null;
  });

  testWidgets('every destination carries the navigation bar', (t) async {
    await _pump(t);

    for (final tab in HomeNavTab.values) {
      if (tab != HomeNavTab.home) {
        await t.tap(find.text(_labelFor(tab)));
        await t.pumpAndSettle();
      }

      expect(find.byType(HomeBottomNav), findsOneWidget,
          reason: 'the bar should be under ${tab.name}, not just home');
      expect(find.textContaining('${tab.name} taps:'), findsOneWidget);
    }
  });

  testWidgets('a tab is not built until it is opened', (t) async {
    await _pump(t);

    expect(built, [HomeNavTab.home],
        reason: 'building all five at launch opens Firestore streams for '
            'tabs the user has not looked at');

    await t.tap(find.text('Saved'));
    await t.pumpAndSettle();

    expect(built, [HomeNavTab.home, HomeNavTab.wishlist]);
    expect(built, isNot(contains(HomeNavTab.orders)));
  });

  testWidgets('leaving a tab and coming back keeps its state', (t) async {
    await _pump(t);

    await t.tap(find.text('home taps: 0'));
    await t.pump();
    expect(find.text('home taps: 1'), findsOneWidget);

    await t.tap(find.text('Sell'));
    await t.pumpAndSettle();
    await t.tap(find.text('Home'));
    await t.pumpAndSettle();

    expect(find.text('home taps: 1'), findsOneWidget,
        reason: 'keeping tabs alive is the point of the IndexedStack');
    expect(built, [HomeNavTab.home, HomeNavTab.sell],
        reason: 'returning to a tab should not rebuild it from scratch');
  });

  testWidgets('back from another tab returns to home rather than exiting',
      (t) async {
    await _pump(t);
    await t.tap(find.text('Profile'));
    await t.pumpAndSettle();
    expect(find.textContaining('profile taps:'), findsOneWidget);

    final popped = await t.binding.handlePopRoute();
    await t.pumpAndSettle();

    expect(popped, isTrue, reason: 'the route itself must not be popped');
    expect(find.textContaining('home taps:'), findsOneWidget);
  });

  testWidgets('back from home lets the app close', (t) async {
    await _pump(t);

    // Home is the last stop. Back here must fall through to the system,
    // otherwise the app can never be closed with the back button at all.
    final popped = await t.binding.handlePopRoute();
    await t.pumpAndSettle();

    expect(popped, isFalse,
        reason: 'unhandled means the system closes the app, which is right '
            'on the first tab');
    expect(find.textContaining('home taps:'), findsOneWidget);
  });

  testWidgets('goHome switches the tab from outside the shell', (t) async {
    await _pump(t);
    await t.tap(find.text('Sell'));
    await t.pumpAndSettle();
    expect(find.textContaining('sell taps:'), findsOneWidget);

    // Called the way the checkout and the checkup summary call it: no
    // context, from a route that is a sibling of the shell rather than a
    // child of it.
    MainShell.goHome();
    await t.pumpAndSettle();

    expect(find.textContaining('home taps:'), findsOneWidget);
    expect(MainShell.request.value, isNull,
        reason: 'a handled request should not fire again on the next rebuild');
  });

  testWidgets('select moves to any tab from outside', (t) async {
    await _pump(t);

    MainShell.select(HomeNavTab.wishlist);
    await t.pumpAndSettle();

    expect(find.textContaining('wishlist taps:'), findsOneWidget);
  });

  testWidgets('the shell opens on the tab it is given', (t) async {
    t.view.physicalSize = const Size(400, 800);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(MaterialApp(
      home: MainShell(
        initialTab: HomeNavTab.profile,
        pageBuilder: (tab) => _Stand(tab: tab),
        repository: const _Repo(signedIn: true),
      ),
    ));
    await t.pump();

    expect(find.textContaining('profile taps:'), findsOneWidget);
    expect(built, [HomeNavTab.profile]);
  });

  testWidgets('Orders asks a signed-out user to sign in first', (t) async {
    await _pump(t, signedIn: false);

    await t.tap(find.text('Orders'));
    await t.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget,
        reason: 'an orders list is empty and confusing when signed out');
    expect(find.textContaining('orders taps:'), findsNothing,
        reason: 'the tab should not open behind the sign-in prompt');
  });

  testWidgets('a signed-in user reaches Orders directly', (t) async {
    await _pump(t, signedIn: true);

    await t.tap(find.text('Orders'));
    await t.pumpAndSettle();

    expect(find.byType(LoginPage), findsNothing);
    expect(find.textContaining('orders taps:'), findsOneWidget);
  });

  testWidgets('lays out on a narrow screen', (t) async {
    await _pump(t, size: const Size(320, 640));
    expect(find.byType(HomeBottomNav), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}

String _labelFor(HomeNavTab tab) {
  switch (tab) {
    case HomeNavTab.home:
      return 'Home';
    case HomeNavTab.sell:
      return 'Sell';
    case HomeNavTab.orders:
      return 'Orders';
    case HomeNavTab.wishlist:
      return 'Saved';
    case HomeNavTab.profile:
      return 'Profile';
  }
}
