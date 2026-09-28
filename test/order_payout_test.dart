// Which of an order's two money figures a screen should show.
//
// This exists because getting it backwards is a specific, nasty failure: the
// "Payment sent" notification said the quoted ₹20,000 when the inspector had
// already settled at ₹12,000. Telling somebody they are being paid more than
// they are is worse than saying nothing, and they find out at the bank.
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/shared/services/order_payout.dart';

void main() {
  group('before anyone has inspected it', () {
    test('the quote is the amount', () {
      final p = payoutOf({'finalPayout': 20000});
      expect(p.amount, 20000);
      expect(p.quoted, 20000);
      expect(p.wasAdjusted, isFalse);
    });

    test('a missing payout reads as zero rather than throwing', () {
      expect(payoutOf({}).amount, 0);
    });
  });

  group('once an agent has been', () {
    test('the settled amount wins over the quote', () {
      final p = payoutOf({
        'finalPayout': 20000,
        'inspection': {'confirmedPayout': 12000},
      });
      expect(p.amount, 12000, reason: 'this is what actually gets paid');
      expect(p.quoted, 20000, reason: 'kept, so a screen can show both');
      expect(p.wasAdjusted, isTrue);
    });

    test('confirming the quote is not an adjustment', () {
      final p = payoutOf({
        'finalPayout': 20000,
        'inspection': {'confirmedPayout': 20000},
      });
      expect(p.amount, 20000);
      expect(p.wasAdjusted, isFalse,
          reason: 'nothing changed, so nothing should be announced as changed');
    });

    test('an agent may settle higher than the quote', () {
      // Rare but legitimate — a phone in better condition than declared. The
      // rules allow it and nothing here should quietly cap it.
      final p = payoutOf({
        'finalPayout': 10000,
        'inspection': {'confirmedPayout': 11000},
      });
      expect(p.amount, 11000);
      expect(p.wasAdjusted, isTrue);
    });

    test('a settled amount of zero is respected, not treated as missing', () {
      // A phone that turned out to be worthless still has to report zero
      // rather than falling back to the quote and promising money.
      final p = payoutOf({
        'finalPayout': 20000,
        'inspection': {'confirmedPayout': 0},
      });
      expect(p.amount, 0);
      expect(p.wasAdjusted, isTrue);
    });

    test('an inspection with no amount falls back to the quote', () {
      // A partially written record must not read as "we are paying you zero".
      final p = payoutOf({
        'finalPayout': 20000,
        'inspection': {'reason': 'Noted but not priced'},
      });
      expect(p.amount, 20000);
      expect(p.wasAdjusted, isFalse);
    });
  });

  group('values Firestore might actually hold', () {
    test('a double is rounded', () {
      expect(payoutOf({'finalPayout': 19999.6}).amount, 20000);
    });

    test('a numeric string is read', () {
      // The admin console will save text into a field the app writes as a
      // number, and a payout silently reading as zero is worse than loud.
      expect(payoutOf({'finalPayout': '15000'}).amount, 15000);
      expect(
        payoutOf({
          'finalPayout': 20000,
          'inspection': {'confirmedPayout': '12000'},
        }).amount,
        12000,
      );
    });

    test('unreadable text does not become a wrong number', () {
      expect(payoutOf({'finalPayout': 'twenty thousand'}).amount, 0);
    });

    test('infinity and NaN are refused', () {
      expect(payoutOf({'finalPayout': double.infinity}).amount, 0);
      expect(payoutOf({'finalPayout': double.nan}).amount, 0);
    });

    test('an inspection field of the wrong shape is ignored', () {
      expect(payoutOf({'finalPayout': 20000, 'inspection': 'yes'}).amount,
          20000);
    });
  });
}
