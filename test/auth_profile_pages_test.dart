// Layout smoke tests for the screens in this batch that can be built without a
// configured Firebase app.
//
// edit_profile, profile_screen, orders_page and wishlist_page all read
// catalogAuth during initState or build, which throws [core/no-app] in the
// test environment, so they are not covered here. See the note in the batch
// summary.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/profile/support_page.dart';
import 'package:french_mobiles/screens/login_page.dart';

Future<void> _boot(WidgetTester tester, Widget page, {Size? size}) async {
  tester.view.physicalSize = size ?? const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('LoginPage', () {
    testWidgets('builds the phone step', (t) async {
      await _boot(t, const LoginPage());
      expect(find.text('Sign in to continue'), findsOneWidget);
      expect(find.text('Send code'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('builds narrow', (t) async {
      await _boot(t, const LoginPage(), size: const Size(320, 640));
    });
  });

  group('SupportPage', () {
    testWidgets('builds with the first FAQ expanded', (t) async {
      await _boot(t, const SupportPage());
      expect(find.text('Help & support'), findsOneWidget);
      expect(find.textContaining('price algorithm'), findsOneWidget);
    });

    testWidgets('collapses and expands an FAQ', (t) async {
      await _boot(t, const SupportPage());
      await t.tap(find.text('Is it safe to trade in my old phone?'));
      await t.pumpAndSettle();
      expect(find.textContaining('factory data wipe'), findsOneWidget);
    });

    testWidgets('builds narrow', (t) async {
      await _boot(t, const SupportPage(), size: const Size(320, 640));
    });
  });
}
