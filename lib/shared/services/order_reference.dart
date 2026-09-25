import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

/// A short, speakable reference for an order, like `FM-4K7P2A`.
///
/// Firestore's own IDs — `1mdVJnUOEVh6YJw3KOBC` — are fine for code and
/// useless for people. A seller ringing up about a pickup cannot read one out,
/// and an agent cannot take it down without mistakes, so orders carry a second
/// identifier meant for humans.
///
/// The alphabet is Crockford's base32: the digits and letters minus `I`, `L`,
/// `O` and `U`. The first three are dropped because they are indistinguishable
/// from `1` and `0` when spoken or handwritten — the exact failure this is
/// supposed to prevent — and `U` because removing it stops the generator
/// spelling anything unfortunate.
const String _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

/// How long the random part is.
///
/// Six characters is 32^6, a little over a billion. That is not enough on its
/// own — at a hundred thousand orders the birthday paradox makes a collision
/// near-certain, not rare — which is why [reserveOrderReference] checks rather
/// than trusting the odds.
const int _length = 6;

final Random _random = Random.secure();

String _candidate() {
  final buffer = StringBuffer('FM-');
  for (var i = 0; i < _length; i++) {
    buffer.write(_alphabet[_random.nextInt(_alphabet.length)]);
  }
  return buffer.toString();
}

/// Returns a reference no existing order is using.
///
/// Checks each candidate against the collection before handing it back. Six
/// characters collide often enough at scale to matter, and two sellers quoting
/// the same reference is precisely the confusion this exists to remove.
///
/// Gives up after [attempts] tries and returns null rather than blocking the
/// order: a sale must not fail because a cosmetic identifier could not be
/// minted. Callers place the order regardless and fall back to the document
/// ID, which is always unique.
Future<String?> reserveOrderReference(
  CollectionReference<Map<String, dynamic>> orders, {
  int attempts = 5,
}) async {
  for (var i = 0; i < attempts; i++) {
    final candidate = _candidate();
    try {
      final taken = await orders
          .where('reference', isEqualTo: candidate)
          .limit(1)
          .get();
      if (taken.docs.isEmpty) return candidate;
    } catch (_) {
      // Offline, or rules refused the read. Not worth failing the order over.
      return null;
    }
  }
  return null;
}

/// What to show the seller: the reference when there is one, else the raw ID.
///
/// Orders placed before references existed have none, and they still have to
/// be referred to somehow.
String displayReference(String orderId, String? reference) {
  final trimmed = reference?.trim();
  if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  // The tail is more distinctive than the head: Firestore IDs share leading
  // characters when generated close together.
  final tail = orderId.length > 6
      ? orderId.substring(orderId.length - 6)
      : orderId;
  return tail.toUpperCase();
}
