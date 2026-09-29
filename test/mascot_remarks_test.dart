// What the mascot says, and when.
//
// Pure functions over a clock, so the awkward moments — 2am, a Sunday — can
// be tested without waiting for one.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/shared/widgets/mascot_remarks.dart';

List<String> _at(
  DateTime when, {
  Duration walked = Duration.zero,
  int thrown = 0,
  int bumps = 0,
}) =>
    MascotRemarks.candidates(
      now: when,
      walked: walked,
      thrown: thrown,
      bumps: bumps,
    );

bool _mentions(List<String> lines, String word) =>
    lines.any((l) => l.toLowerCase().contains(word.toLowerCase()));

void main() {
  group('the time of day', () {
    test('knows it is the middle of the night', () {
      // A Wednesday, 2am.
      final lines = _at(DateTime(2026, 9, 16, 2));
      expect(_mentions(lines, '2am'), isTrue);
      expect(_mentions(lines, 'asleep'), isTrue);
    });

    test('counts 11pm as night rather than evening', () {
      expect(_mentions(_at(DateTime(2026, 9, 16, 23)), 'also awake'), isTrue);
    });

    test('says something else entirely in the afternoon', () {
      final lines = _at(DateTime(2026, 9, 16, 14));
      expect(_mentions(lines, 'afternoon'), isTrue);
      expect(_mentions(lines, 'asleep'), isFalse);
    });
  });

  group('the day of the week', () {
    test('Saturday is for people whose legs stop', () {
      // 19 September 2026 is a Saturday.
      final saturday = DateTime(2026, 9, 19, 13);
      expect(saturday.weekday, DateTime.saturday);
      expect(_mentions(_at(saturday), 'Saturday'), isTrue);
      expect(_mentions(_at(saturday), 'weekend'), isTrue);
    });

    test('Sunday gets its own complaint', () {
      final sunday = DateTime(2026, 9, 20, 13);
      expect(sunday.weekday, DateTime.sunday);
      expect(_mentions(_at(sunday), 'Sunday'), isTrue);
    });

    test('a Wednesday does not claim to be the weekend', () {
      final lines = _at(DateTime(2026, 9, 16, 13));
      expect(_mentions(lines, 'weekend'), isFalse);
      expect(_mentions(lines, 'Saturday'), isFalse);
      expect(_mentions(lines, 'Sunday'), isFalse);
    });

    test('Monday and Friday each get a line', () {
      expect(_mentions(_at(DateTime(2026, 9, 21, 9)), 'Monday'), isTrue);
      expect(_mentions(_at(DateTime(2026, 9, 18, 18)), 'Friday'), isTrue);
    });
  });

  group('how long it has been walking', () {
    final noon = DateTime(2026, 9, 16, 12);

    test('says nothing about it in the first couple of minutes', () {
      expect(
          _mentions(_at(noon, walked: const Duration(seconds: 40)),
              'been walking for'),
          isFalse);
    });

    test('brings it up once it has been a while', () {
      final lines = _at(noon, walked: const Duration(minutes: 6));
      expect(_mentions(lines, 'walking for 6 minutes'), isTrue);
    });

    test('gets more put upon after ten', () {
      expect(
          _mentions(_at(noon, walked: const Duration(minutes: 12)), 'no map'),
          isTrue);
    });
  });

  group('how it has been treated', () {
    final noon = DateTime(2026, 9, 16, 12);

    test('the first throw is singular', () {
      final lines = _at(noon, thrown: 1);
      expect(_mentions(lines, 'You threw me'), isTrue);
      expect(_mentions(lines, 'times you have thrown'), isFalse);
    });

    test('after that it keeps count', () {
      expect(
          _mentions(_at(noon, thrown: 4), '4 times you have thrown'), isTrue);
    });

    test('mentions the wall once it has met it a few times', () {
      expect(_mentions(_at(noon, bumps: 3), 'hit that wall 3 times'), isTrue);
    });

    test('says nothing about walls it has not hit', () {
      expect(_mentions(_at(noon, bumps: 0), 'wall'), isFalse);
    });
  });

  test('always has something useful to fall back on', () {
    // Even a dull Wednesday lunchtime with nothing to complain about.
    final lines = _at(DateTime(2026, 9, 16, 12));
    expect(lines, containsAll(MascotRemarks.advice));
  });

  group('picking one', () {
    final noon = DateTime(2026, 9, 16, 12);

    test('never repeats the line it just said', () {
      final random = Random(1);
      var previous = MascotRemarks.pick(
        now: noon,
        walked: Duration.zero,
        thrown: 0,
        bumps: 0,
        random: random,
      );

      for (var i = 0; i < 60; i++) {
        final next = MascotRemarks.pick(
          now: noon,
          walked: Duration.zero,
          thrown: 0,
          bumps: 0,
          random: random,
          previous: previous,
        );
        expect(next, isNot(previous));
        previous = next;
      }
    });

    test('only ever says things it had on the list', () {
      final all = _at(noon);
      for (var seed = 0; seed < 20; seed++) {
        expect(
          all,
          contains(MascotRemarks.pick(
            now: noon,
            walked: Duration.zero,
            thrown: 0,
            bumps: 0,
            random: Random(seed),
          )),
        );
      }
    });
  });

  test('tells the time the way a person would', () {
    expect(MascotRemarks.clockOf(DateTime(2026, 1, 1, 0)), '12am');
    expect(MascotRemarks.clockOf(DateTime(2026, 1, 1, 2)), '2am');
    expect(MascotRemarks.clockOf(DateTime(2026, 1, 1, 12)), '12pm');
    expect(MascotRemarks.clockOf(DateTime(2026, 1, 1, 23)), '11pm');
  });
}
