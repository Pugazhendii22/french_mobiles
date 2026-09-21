// Turning a measured battery health figure into a deduction band.
//
// This decides up to 35% of a payout from a number the phone reported, so the
// edges matter: 80 must not land in "70-79", and 69 must fall through to
// "below 70". The bands are Firestore text that the shop can reword at any
// time, which is exactly why this reads the numbers rather than trusting the
// order they happen to be in.
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/shared/services/battery_band.dart';

/// The bands as they actually stand in deduction_rules today.
const _live = [
  '95-100%+ Battery Health',
  '90-95% Battery Health',
  '70-79% Battery Health',
  'Below 70% Health',
  'Not Charging / Swollen',
];

void main() {
  group('against the live bands', () {
    test('a healthy battery lands in the top band', () {
      expect(batteryBandFor(100, _live), 0);
      expect(batteryBandFor(97, _live), 0);
      expect(batteryBandFor(95, _live), 0, reason: 'ranges are inclusive');
    });

    test('a slightly worn one lands in the second', () {
      expect(batteryBandFor(92, _live), 1);
      expect(batteryBandFor(90, _live), 1);
    });

    test('a worn one lands in the third', () {
      expect(batteryBandFor(79, _live), 2);
      expect(batteryBandFor(70, _live), 2);
    });

    test('a bad one falls through to "below"', () {
      expect(batteryBandFor(69, _live), 3);
      expect(batteryBandFor(41, _live), 3);
      expect(batteryBandFor(1, _live), 3);
    });

    test('never picks "Not Charging / Swollen" from a percentage alone', () {
      // That band describes a physical fault, not a number. Reaching it by
      // arithmetic would apply a 35% deduction to a battery that merely
      // reported a low figure.
      for (var health = 1; health <= 100; health++) {
        expect(batteryBandFor(health, _live), isNot(4),
            reason: '$health% should never be read as swollen');
      }
    });

    test('a gap between bands is left for the seller to fill', () {
      // 80-89 is missing from the live list. Silently rounding into the
      // neighbouring band would move money on a guess.
      expect(batteryBandFor(85, _live), isNull);
    });
  });

  group('reading the labels', () {
    test('survives being reordered', () {
      final reversed = _live.reversed.toList();
      final index = batteryBandFor(75, reversed)!;
      expect(reversed[index], '70-79% Battery Health');
    });

    test('handles a range written the other way round', () {
      expect(batteryBandFor(97, ['100-95% Battery Health']), 0);
    });

    test('reads "under" as well as "below"', () {
      expect(batteryBandFor(50, ['Under 70% Health']), 0);
      expect(batteryBandFor(80, ['Under 70% Health']), isNull);
    });

    test('a bare number is a floor', () {
      expect(batteryBandFor(96, ['95%+ Battery Health']), 0);
      expect(batteryBandFor(94, ['95%+ Battery Health']), isNull);
    });

    test('ignores a label with no numbers in it at all', () {
      expect(batteryBandFor(50, ['Not Charging / Swollen']), isNull);
    });

    test('no bands means no choice made', () {
      expect(batteryBandFor(88, const []), isNull);
    });
  });

  group('estimating capacity from charge cycles', () {
    test('a new battery is full', () {
      expect(estimatedHealthFromCycles(0), 100);
    });

    test('follows the 80%-at-500-cycles line manufacturers quote', () {
      expect(estimatedHealthFromCycles(500), 80);
      expect(estimatedHealthFromCycles(250), 90);
    });

    test('keeps falling past 500', () {
      expect(estimatedHealthFromCycles(800), 68);
      expect(estimatedHealthFromCycles(1000), 60);
    });

    test('never goes below 1% or above 100%', () {
      expect(estimatedHealthFromCycles(99999), greaterThanOrEqualTo(1));
      expect(estimatedHealthFromCycles(-5), 100);
    });

    test('a worn battery lands in a worse band than a fresh one', () {
      final fresh = batteryBandFor(estimatedHealthFromCycles(50), _live)!;
      final worn = batteryBandFor(estimatedHealthFromCycles(900), _live)!;
      expect(worn, greaterThan(fresh),
          reason: 'the bands run best-first, so more wear means a later one');
    });

    test('a mid-life battery falls in the gap and prefills nothing', () {
      // 400 cycles estimates 84%, and the live bands jump from 90-95 to
      // 70-79. Better to leave it to the seller than to round a payout.
      expect(estimatedHealthFromCycles(400), 84);
      expect(batteryBandFor(84, _live), isNull);
    });
  });
}
