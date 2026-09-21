// The yes/no questions asked before the physical checklist.
//
// These decide money, and one of them is phrased the other way round — "has
// this phone ever had water damage?" costs the seller when the answer is
// *yes*, where every other question costs on "no". Getting that inversion
// backwards would quietly pay the wrong amount on every order, and would look
// like working software while doing it.
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/models/device_question.dart';

Map<String, dynamic> _raw({
  String question = 'Do the buttons work?',
  String label = 'Buttons Not Working',
  Object percent = 8,
  String deductOn = 'no',
  String help = 'Check the volume keys.',
}) =>
    {
      'question': question,
      'label': label,
      'percent': percent,
      'deduct_on': deductOn,
      'help': help,
    };

void main() {
  group('reading a rule', () {
    test('takes the wording, the fault name and the percent', () {
      final q = DeviceQuestion.fromMap(_raw())!;

      expect(q.question, 'Do the buttons work?');
      expect(q.label, 'Buttons Not Working');
      expect(q.help, 'Check the volume keys.');
      expect(q.percent, 8);
      expect(q.fraction, closeTo(0.08, 1e-9));
    });

    test('accepts a percent stored as a string', () {
      // Firestore holds these as integers, but the admin console will happily
      // save a string into the same field.
      expect(DeviceQuestion.fromMap(_raw(percent: '18'))!.percent, 18);
    });

    test('a percent it cannot read costs nothing rather than crashing', () {
      expect(DeviceQuestion.fromMap(_raw(percent: 'twelve'))!.percent, 0);
    });

    group('is rejected when it could not be shown or charged for', () {
      test('no question text', () {
        expect(DeviceQuestion.fromMap(_raw(question: '  ')), isNull);
      });

      test('no fault name for the receipt', () {
        expect(DeviceQuestion.fromMap(_raw(label: '')), isNull);
      });
    });
  });

  group('which answer costs money', () {
    test('normally "no" is the bad answer', () {
      final q = DeviceQuestion.fromMap(_raw(deductOn: 'no'))!;

      expect(q.deductOnYes, isFalse);
      expect(q.isFaultFor(false), isTrue, reason: '"no" should cost');
      expect(q.isFaultFor(true), isFalse, reason: '"yes" should not');
    });

    test('water damage inverts it — "yes" is the bad answer', () {
      final q = DeviceQuestion.fromMap(_raw(
        question: 'Has this phone ever had water damage?',
        label: 'Water Damage Tripped',
        percent: 25,
        deductOn: 'yes',
      ))!;

      expect(q.deductOnYes, isTrue);
      expect(q.isFaultFor(true), isTrue, reason: 'admitting damage costs');
      expect(q.isFaultFor(false), isFalse);
    });

    test('an unset or unrecognised deduct_on falls back to "no"', () {
      // The safer default: the great majority of questions work this way, and
      // a typo should not turn a working phone into a faulty one.
      expect(DeviceQuestion.fromMap(_raw(deductOn: ''))!.deductOnYes, isFalse);
      expect(DeviceQuestion.fromMap(_raw(deductOn: 'maybe'))!.deductOnYes,
          isFalse);
    });

    test('"YES" is read regardless of case', () {
      expect(
          DeviceQuestion.fromMap(_raw(deductOn: 'YES'))!.deductOnYes, isTrue);
    });
  });

  group('an answer', () {
    test('is a fault only when it is the costly one', () {
      final normal = DeviceQuestion.fromMap(_raw())!;

      expect(
        DeviceAnswer(question: normal, answeredYes: false).isFault,
        isTrue,
      );
      expect(
        DeviceAnswer(question: normal, answeredYes: true).isFault,
        isFalse,
      );
    });

    test('follows the inversion too', () {
      final water = DeviceQuestion.fromMap(_raw(deductOn: 'yes'))!;

      expect(DeviceAnswer(question: water, answeredYes: true).isFault, isTrue);
      expect(
          DeviceAnswer(question: water, answeredYes: false).isFault, isFalse);
    });
  });

  test('the deduction is a fraction of the base price', () {
    final q = DeviceQuestion.fromMap(_raw(percent: 18))!;
    expect((10000 * q.fraction).round(), 1800);
  });
}
