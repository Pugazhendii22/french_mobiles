import 'package:cloud_firestore/cloud_firestore.dart';

/// One deduction in a quote: what was taken off, and why.
class QuoteLine {
  const QuoteLine({
    required this.category,
    required this.choice,
    required this.percent,
    required this.amount,
  });

  /// The question that produced it, e.g. "Screen condition".
  final String category;

  /// What the seller picked, e.g. "Minor scratches".
  final String choice;

  /// Whole-number percent of the base price, as stored in `deduction_rules`.
  final int percent;

  /// Rupees taken off the base price.
  final int amount;

  Map<String, dynamic> toMap() => {
        'category': category,
        'choice': choice,
        'percent': percent,
        'amount': amount,
      };

  static QuoteLine? fromMap(Object? raw) {
    if (raw is! Map) return null;
    return QuoteLine(
      category: (raw['category'] ?? '').toString(),
      choice: (raw['choice'] ?? '').toString(),
      percent: (raw['percent'] as num?)?.round() ?? 0,
      amount: (raw['amount'] as num?)?.round() ?? 0,
    );
  }
}

/// The arithmetic behind a payout, kept so it can be shown rather than
/// summarised.
///
/// A bare final number is the single biggest source of distrust in this
/// category: when the price at the door differs from the price in the app,
/// a seller with no breakdown has no way to tell a fair adjustment from a
/// bait and switch. Every deduction is therefore itemised, carried into
/// checkout, and written onto the order — so the figure can still be
/// explained after the fact.
class QuoteBreakdown {
  const QuoteBreakdown({
    required this.basePrice,
    required this.lines,
    required this.finalPayout,
    required this.validUntil,
    this.floored = false,
  });

  /// How long a quote stands. A commercial promise, set by the business.
  static const Duration validity = Duration(days: 7);

  final int basePrice;
  final List<QuoteLine> lines;
  final int finalPayout;

  /// When the quote stops being honoured.
  final DateTime validUntil;

  /// Whether the minimum-value floor decided the payout rather than the
  /// deductions did.
  ///
  /// The valuation never pays less than 10% of the base price, so a device
  /// with enough faults to wipe out more than 90% stops at the floor. When
  /// that happens the itemised lines deliberately do **not** sum to the
  /// payout, and saying so is the only honest way to show them.
  final bool floored;

  /// Everything taken off the base price, before the floor.
  int get totalDeducted =>
      lines.fold(0, (running, line) => running + line.amount);

  bool get isExpired => DateTime.now().isAfter(validUntil);

  /// Whole days left, never negative. 0 means it lapses today.
  int get daysRemaining {
    final left = validUntil.difference(DateTime.now());
    return left.isNegative ? 0 : left.inDays;
  }

  /// Builds a quote from the selected options.
  ///
  /// [deductionFor] returns the fraction of the base price a choice costs,
  /// matching how `deduction_rules` stores it.
  factory QuoteBreakdown.from({
    required int basePrice,
    required List<QuoteLine> lines,
    required double totalFraction,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();

    var remaining = 1.0 - totalFraction;
    final floored = remaining < 0.10;
    if (floored) remaining = 0.10;

    return QuoteBreakdown(
      basePrice: basePrice,
      lines: lines,
      finalPayout: (basePrice * remaining).round(),
      validUntil: at.add(validity),
      floored: floored,
    );
  }

  Map<String, dynamic> toMap() => {
        'basePrice': basePrice,
        'lines': [for (final line in lines) line.toMap()],
        'finalPayout': finalPayout,
        'validUntil': Timestamp.fromDate(validUntil),
        'floored': floored,
      };

  /// Reads a breakdown back off an order document.
  ///
  /// Returns null for orders placed before quotes were itemised, so callers
  /// can fall back to showing the payout alone rather than an empty table.
  static QuoteBreakdown? fromMap(Object? raw) {
    if (raw is! Map) return null;

    final validUntil = raw['validUntil'];
    if (validUntil is! Timestamp) return null;

    return QuoteBreakdown(
      basePrice: (raw['basePrice'] as num?)?.round() ?? 0,
      lines: [
        for (final line in (raw['lines'] as List? ?? const []))
          if (QuoteLine.fromMap(line) case final parsed?) parsed,
      ],
      finalPayout: (raw['finalPayout'] as num?)?.round() ?? 0,
      validUntil: validUntil.toDate(),
      floored: raw['floored'] == true,
    );
  }
}
