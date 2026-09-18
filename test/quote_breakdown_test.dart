// The arithmetic behind a payout.
//
// This is the number a seller is held to, and the one they will compare
// against the offer at their door. If the itemised lines and the final figure
// can disagree, the breakdown is worse than useless — it becomes evidence
// that the app is wrong.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/models/quote_breakdown.dart';

QuoteLine _line(String category, int percent, int amount) => QuoteLine(
      category: category,
      choice: 'some choice',
      percent: percent,
      amount: amount,
    );

void main() {
  group('the sums add up', () {
    test('no deductions pays the full base price', () {
      final quote = QuoteBreakdown.from(
        basePrice: 50000,
        lines: const [],
        totalFraction: 0,
      );

      expect(quote.finalPayout, 50000);
      expect(quote.totalDeducted, 0);
      expect(quote.floored, isFalse);
    });

    test('the lines account for the whole gap to the payout', () {
      // 30% + 10% of 50000 = 15000 + 5000.
      final quote = QuoteBreakdown.from(
        basePrice: 50000,
        lines: [
          _line('Screen condition', 30, 15000),
          _line('Battery health', 10, 5000),
        ],
        totalFraction: 0.40,
      );

      expect(quote.finalPayout, 30000);
      expect(quote.totalDeducted, 20000);
      expect(quote.basePrice - quote.totalDeducted, quote.finalPayout,
          reason: 'a table that does not add up reads as a mistake');
    });

    test('rounding never leaves the payout above the base price', () {
      final quote = QuoteBreakdown.from(
        basePrice: 9999,
        lines: [_line('Screen condition', 33, 3300)],
        totalFraction: 0.33,
      );

      expect(quote.finalPayout, lessThan(quote.basePrice));
    });
  });

  group('the minimum-value floor', () {
    // Deductions past 90% cannot take the payout below a tenth of the base
    // price, so the lines stop matching the total. The quote has to say so.
    final quote = QuoteBreakdown.from(
      basePrice: 50000,
      lines: [
        _line('Screen condition', 60, 30000),
        _line('Functionality fault', 45, 22500),
      ],
      totalFraction: 1.05,
    );

    test('pays the floor rather than nothing or a negative', () {
      expect(quote.finalPayout, 5000);
    });

    test('is flagged, because the lines no longer sum to the payout', () {
      expect(quote.floored, isTrue);
      expect(quote.basePrice - quote.totalDeducted, isNot(quote.finalPayout),
          reason: 'this mismatch is exactly why the flag has to exist');
    });

    test('is not flagged when deductions stop just short of the floor', () {
      final near = QuoteBreakdown.from(
        basePrice: 50000,
        lines: [_line('Screen condition', 89, 44500)],
        totalFraction: 0.89,
      );

      expect(near.floored, isFalse);
      expect(near.finalPayout, 5500);
    });
  });

  group('validity', () {
    test('runs seven days from when the quote was made', () {
      final made = DateTime(2026, 9, 18, 10, 0);
      final quote = QuoteBreakdown.from(
        basePrice: 10000,
        lines: const [],
        totalFraction: 0,
        now: made,
      );

      expect(quote.validUntil, DateTime(2026, 9, 25, 10, 0));
      expect(QuoteBreakdown.validity, const Duration(days: 7));
    });

    test('a fresh quote has not expired and reports days left', () {
      final quote = QuoteBreakdown.from(
        basePrice: 10000,
        lines: const [],
        totalFraction: 0,
      );

      expect(quote.isExpired, isFalse);
      expect(quote.daysRemaining, 6,
          reason: 'six whole days plus a part-day remain immediately after '
              'a seven-day quote is made');
    });

    test('a lapsed quote is expired and never reports negative days', () {
      final quote = QuoteBreakdown(
        basePrice: 10000,
        lines: const [],
        finalPayout: 10000,
        validUntil: DateTime.now().subtract(const Duration(days: 3)),
      );

      expect(quote.isExpired, isTrue);
      expect(quote.daysRemaining, 0);
    });
  });

  group('round trip through Firestore', () {
    test('survives being written and read back', () {
      final original = QuoteBreakdown.from(
        basePrice: 50000,
        lines: [
          _line('Screen condition', 30, 15000),
          _line('Accessories', 5, 2500),
        ],
        totalFraction: 0.35,
        now: DateTime(2026, 9, 18, 10),
      );

      final restored = QuoteBreakdown.fromMap(original.toMap());

      expect(restored, isNotNull);
      expect(restored!.basePrice, original.basePrice);
      expect(restored.finalPayout, original.finalPayout);
      expect(restored.validUntil, original.validUntil);
      expect(restored.lines, hasLength(2));
      expect(restored.lines.first.category, 'Screen condition');
      expect(restored.lines.first.amount, 15000);
      expect(restored.lines.first.percent, 30);
    });

    test('an order placed before quotes were itemised reads as null', () {
      expect(QuoteBreakdown.fromMap(null), isNull);
      expect(QuoteBreakdown.fromMap(<String, dynamic>{}), isNull,
          reason: 'older orders have no quote; callers fall back to the '
              'payout alone rather than rendering an empty table');
    });

    test('a malformed line is dropped rather than crashing the order', () {
      final restored = QuoteBreakdown.fromMap({
        'basePrice': 1000,
        'finalPayout': 900,
        'validUntil': Timestamp.fromDate(DateTime(2026, 9, 25)),
        'lines': ['nonsense', null],
      });

      expect(restored, isNotNull);
      expect(restored!.lines, isEmpty);
    });
  });
}
