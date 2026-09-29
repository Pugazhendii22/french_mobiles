// What MyApp is responsible for.
//
// This file used to assert that the home screen showed "Hello, Guest" and
// "Sell Phone". It had been failing for months for two separate reasons: the
// first string was deleted in the redesign and exists nowhere in the app, and
// booting the real shell reads Firebase, which a widget test has none of. A
// permanently red test is worse than no test — it teaches everyone to skim
// past a failure line.
//
// So it now tests the thing MyApp actually decides, which is narrow but real:
// that every screen inherits the design system from one place. That mattered
// enough to fix once already — screens used to wrap themselves in
// AppTheme.light individually, and the checkup flow, which never did, rendered
// black-on-green buttons on a white page.
//
// The `home` override exists for exactly this and is why no Firebase is needed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:french_mobiles/main.dart';
import 'package:french_mobiles/shared/theme/app_colors.dart';

void main() {
  testWidgets('hands the design system to whatever it hosts', (tester) async {
    late ThemeData inherited;

    await tester.pumpWidget(
      MyApp(
        home: Builder(
          builder: (context) {
            inherited = Theme.of(context);
            return const Scaffold(body: Text('a screen'));
          },
        ),
      ),
    );

    expect(find.text('a screen'), findsOneWidget);
    expect(inherited.scaffoldBackgroundColor, AppColors.background,
        reason: 'a screen that sets no theme of its own must still get ours');
    expect(inherited.useMaterial3, isTrue);
  });

  testWidgets('a Scaffold with no colour of its own picks up the background',
      (tester) async {
    // The failure this guards against is invisible in a widget tree and
    // obvious on a phone: one screen a different colour from every other.
    await tester.pumpWidget(
      const MyApp(home: Scaffold(body: SizedBox.shrink())),
    );

    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(Scaffold),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.color, AppColors.background);
  });

  testWidgets('ships without the debug banner', (tester) async {
    await tester.pumpWidget(const MyApp(home: SizedBox.shrink()));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.debugShowCheckedModeBanner, isFalse,
        reason: 'it would sit over the UI in screenshots and demos');
  });
}
