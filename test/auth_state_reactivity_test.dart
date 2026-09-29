// Screens that stay mounted across a sign-in must watch it, not sample it.
//
// MainShell keeps every visited tab alive in an AppTabSwitcher rather than
// rebuilding it on switch, so a `catalogAuth.currentUser` read taken once in
// build() goes stale the moment someone signs in or out anywhere else in the
// app (checkout, the Orders tab's own sign-in gate, Profile's own logout) —
// build() never runs again to notice. That was the bug: Profile (and Orders,
// which has the identical shape) kept showing "not signed in" after a
// sign-in that happened somewhere else.
//
// The fix is watching catalogAuth.authStateChanges() instead, the way
// WishlistPage already did. These pages need real Firebase to pump, so —
// matching this repo's own convention in firestore_listener_test.dart — this
// is a source-scan rather than a widget test.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const pagesThatMustReactToAuth = [
    'lib/profile/profile_screen.dart',
    'lib/profile/orders_page.dart',
    'lib/profile/wishlist_page.dart',
  ];

  for (final path in pagesThatMustReactToAuth) {
    test('$path watches authStateChanges() rather than sampling currentUser',
        () {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path should still exist');

      final source = file.readAsStringSync();
      expect(source, contains('catalogAuth.authStateChanges()'),
          reason: 'a tab that stays mounted across sign-in must subscribe '
              'to auth state, not read currentUser once in build()');
    });
  }
}
