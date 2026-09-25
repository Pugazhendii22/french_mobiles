// The short code a seller reads out over the phone.
//
// Its whole job is surviving being spoken and handwritten, so the tests here
// are mostly about what the alphabet must never contain: a character that
// turns into a different one when someone says it aloud sends an agent to the
// wrong order.
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/shared/services/order_reference.dart';

void main() {
  group('displayReference', () {
    test('prefers the reference when the order has one', () {
      expect(displayReference('1mdVJnUOEVh6YJw3KOBC', 'FM-4K7P2A'), 'FM-4K7P2A');
    });

    test('falls back to the tail of the document ID', () {
      // Orders placed before references existed still have to be referred to.
      // The tail, not the head: Firestore IDs generated close together share
      // their leading characters, so the front is the least distinctive part.
      expect(displayReference('1mdVJnUOEVh6YJw3KOBC', null), 'W3KOBC');
      expect(displayReference('1mdVJnUOEVh6YJw3KOBC', ''), 'W3KOBC');
      expect(displayReference('1mdVJnUOEVh6YJw3KOBC', '   '), 'W3KOBC');
    });

    test('a short ID is used whole rather than crashing', () {
      expect(displayReference('abc', null), 'ABC');
    });
  });
}
