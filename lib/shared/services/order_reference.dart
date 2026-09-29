/// How an order is referred to when a person has to say it out loud.
///
/// Generating the reference lived here once. It moved to `functions/index.js`,
/// because checking a candidate was free meant querying every order, and
/// security rules rightly refuse that — a seller may read their own orders, not
/// search the collection. The server can both check and write; the client
/// cannot look. This file keeps only the reading half.
library;

/// What to show: the reference when the order has one, else part of its ID.
///
/// Two kinds of order arrive here without a reference — those placed before
/// references existed, and one placed seconds ago whose function has not
/// written it yet. Both still have to be referred to somehow.
String displayReference(String orderId, String? reference) {
  final trimmed = reference?.trim();
  if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  // The tail rather than the head: Firestore IDs generated close together
  // share their leading characters, so the front is the least distinctive
  // part of one.
  final tail =
      orderId.length > 6 ? orderId.substring(orderId.length - 6) : orderId;
  return tail.toUpperCase();
}
