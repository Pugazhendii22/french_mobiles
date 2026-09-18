// Firestore listeners must outlive a frame.
//
// A stream created inside build() is a brand new listener on every rebuild,
// and every new listener bills a fresh read of every document it matches.
// Five pages did this: the profile header re-read the user document, the
// orders list re-read every order, the saved-addresses list re-read every
// address, the tracker re-read its order on each status change, and the
// payment methods list re-read every payout account.
//
// The pages that do this all need Firebase, so the listeners cannot be
// counted in a widget test. What can be checked is the shape of the mistake:
// a `stream:` argument that builds its own snapshots() call, rather than
// referring to something held for the page's lifetime.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A `stream:` argument that calls .snapshots() inline.
final _inlineStream = RegExp(r'stream:\s*[^,;]*?\.snapshots\(\)', dotAll: true);

/// Firestore reads that would be repeated per frame.
final _dartFiles = Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

void main() {
  test('no StreamBuilder builds its own snapshots() inline', () {
    final offenders = <String>[];

    for (final file in _dartFiles) {
      final source = file.readAsStringSync();
      for (final match in _inlineStream.allMatches(source)) {
        offenders.add('${file.path}: ${match.group(0)!.split('\n').first}');
      }
    }

    expect(offenders, isEmpty,
        reason: 'hold the stream in a field or a cached getter instead — '
            'this is billed reads, not just bandwidth:\n'
            '${offenders.join('\n')}');
  });

  test('the files that had the problem are still being checked', () {
    // Guards the guard: if these are renamed or moved, the scan above would
    // quietly pass over nothing at all.
    final paths = _dartFiles.map((f) => f.path).toSet();

    for (final expected in [
      'lib/profile/profile_screen.dart',
      'lib/profile/orders_page.dart',
      'lib/profile/account_pages.dart',
      'lib/profile/payment_methods_page.dart',
      'lib/screens/order_tracking_page.dart',
    ]) {
      expect(paths, contains(expected));
    }
  });

  test('the scan would notice an inline stream', () {
    // The regex is the whole test, so it is worth proving it matches the
    // thing it is looking for.
    const bad = '''
      StreamBuilder(
        stream: catalogFirestore.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) => const SizedBox(),
      )
    ''';
    const good = '''
      StreamBuilder(
        stream: _profileStream,
        builder: (context, snapshot) => const SizedBox(),
      )
    ''';

    expect(_inlineStream.hasMatch(bad), isTrue);
    expect(_inlineStream.hasMatch(good), isFalse);
  });
}
