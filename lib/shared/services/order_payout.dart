/// What a seller is actually being paid, as opposed to what they were quoted.
///
/// An order can carry two figures. `finalPayout` is the quote the seller
/// accepted; `inspection.confirmedPayout` is what the agent settled on at the
/// door after seeing the phone. Where both exist the settled one is the real
/// number, and showing the quote instead tells somebody they are getting more
/// money than they are.
///
/// Kept in one place because it is read from several screens — the orders list,
/// the tracking page, the receipt — and every one of them getting it right
/// separately is how one of them ends up wrong.
library;

/// The amount to show, and whether it differs from the quote.
///
/// [wasAdjusted] exists so a screen can say so rather than silently displaying
/// a different number than the seller remembers agreeing to.
({int amount, int quoted, bool wasAdjusted}) payoutOf(Map<String, dynamic> d) {
  final quoted = _intOf(d['finalPayout']) ?? 0;

  final inspection = d['inspection'];
  if (inspection is Map) {
    final settled = _intOf(inspection['confirmedPayout']);
    if (settled != null) {
      return (
        amount: settled,
        quoted: quoted,
        wasAdjusted: settled != quoted,
      );
    }
  }

  return (amount: quoted, quoted: quoted, wasAdjusted: false);
}

/// Reads a number that Firestore may hold as an int, a double or a string.
///
/// The admin console will happily save a price as text into a field the app
/// writes as a number, and a payout that silently reads as zero is worse than
/// one that fails loudly — so a string of digits is accepted rather than
/// discarded.
int? _intOf(Object? raw) {
  if (raw is num) {
    return raw.isFinite ? raw.round() : null;
  }
  if (raw is String) {
    return int.tryParse(raw.trim());
  }
  return null;
}
