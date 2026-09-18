// Layout smoke tests for the account pages that build without Firebase.
//
// SavedAddressesPage and AddEditAddressSheet read catalogAuth / Firestore, so
// they are not covered here — see the coverage note in the batch summary.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/profile/account_pages.dart';
import 'package:french_mobiles/profile/payment_methods_page.dart';

Future<void> _boot(WidgetTester tester, Widget page, {Size? size}) async {
  tester.view.physicalSize = size ?? const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('PaymentMethodsPage shows no invented payout accounts',
      (t) async {
    await _boot(t, const PaymentMethodsPage());

    expect(find.text('Payment methods'), findsOneWidget);
    // The page used to ship two made-up UPI IDs presented as the user's own.
    // In an app that pays people, that invites someone to believe their money
    // is already routed somewhere it is not.
    expect(find.textContaining('@okaxis'), findsNothing);
    expect(find.textContaining('@ybl'), findsNothing);
    expect(find.text('DEFAULT'), findsNothing,
        reason: 'nothing can be the default when nothing is saved');
  });

  testWidgets('PaymentMethodsPage asks a signed-out user to sign in',
      (t) async {
    // No Firebase here, so the page takes its signed-out path.
    await _boot(t, const PaymentMethodsPage());
    expect(find.textContaining('Sign in'), findsOneWidget);
  });

  testWidgets('NotificationPreferencesPage toggles', (t) async {
    await _boot(t, const NotificationPreferencesPage());
    expect(find.byType(Switch), findsNWidgets(4));
    await t.tap(find.byType(Switch).first);
    await t.pump(const Duration(milliseconds: 300));
  });

  testWidgets('PrivacySecurityPage builds', (t) async {
    await _boot(t, const PrivacySecurityPage());
    expect(find.text('Privacy & security'), findsOneWidget);
  });

  testWidgets('HelpCenterPage builds', (t) async {
    await _boot(t, const HelpCenterPage());
    expect(find.text('Help centre'), findsOneWidget);
  });

  testWidgets('AboutUsPage builds', (t) async {
    await _boot(t, const AboutUsPage());
    expect(find.text('TradeIn Express'), findsOneWidget);
  });

  testWidgets('all build narrow', (t) async {
    for (final page in const [
      PaymentMethodsPage(),
      NotificationPreferencesPage(),
      PrivacySecurityPage(),
      HelpCenterPage(),
      AboutUsPage(),
    ]) {
      await _boot(t, page, size: const Size(320, 640));
    }
  });
}
