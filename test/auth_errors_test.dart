// What the login screen says when sign-in fails.
//
// The rule these enforce: nothing Firebase wrote ever reaches the seller. Its
// messages are written for developers, and two of them ("INVALID_LOGIN_
// CREDENTIALS", "The SMS quota for this project has been exceeded") both
// confuse the person and describe the backend out loud.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/shared/services/auth_errors.dart';

FirebaseAuthException _err(String code) => FirebaseAuthException(
      code: code,
      message: 'RAW_FIREBASE_TEXT that must never be shown',
    );

void main() {
  group('every message is fit to show someone', () {
    const codes = [
      'invalid-phone-number',
      'missing-phone-number',
      'invalid-verification-code',
      'session-expired',
      'code-expired',
      'invalid-verification-id',
      'too-many-requests',
      'quota-exceeded',
      'user-disabled',
      'account-exists-with-different-credential',
      'credential-already-in-use',
      'operation-not-allowed',
      'network-request-failed',
      'user-cancelled',
    ];

    for (final code in codes) {
      test('$code reads as plain English', () {
        final message = authErrorMessage(_err(code));

        expect(message, isNotEmpty);
        expect(message, isNot(contains('RAW_FIREBASE_TEXT')),
            reason: 'the raw message must never be passed through');
        expect(message, isNot(contains(code)),
            reason: 'the error code is not for the seller to read');
        expect(message, isNot(contains('_')),
            reason: 'underscores mean a machine string escaped');
        expect(message.endsWith('.'), isTrue,
            reason: 'a whole sentence, not a fragment');
      });
    }
  });

  test('an unrecognised code still says something useful', () {
    final message = authErrorMessage(_err('some-code-nobody-planned-for'));
    expect(message, 'Something went wrong signing you in. Please try again.');
  });

  test('a plain exception is never dumped on screen', () {
    // A stack trace on the login screen helps nobody.
    final message = authErrorMessage(StateError('internal: null token at :42'));
    expect(message, isNot(contains('internal')));
    expect(message, isNot(contains('42')));
  });

  group('whose fault it was', () {
    test('a mistyped code is the person to fix', () {
      expect(isUserCorrectable(_err('invalid-verification-code')), isTrue);
      expect(isUserCorrectable(_err('invalid-phone-number')), isTrue);
    });

    test('an outage or a lockout is not', () {
      // Worth separating: the app should not imply someone caused a problem
      // they had no part in.
      expect(isUserCorrectable(_err('network-request-failed')), isFalse);
      expect(isUserCorrectable(_err('too-many-requests')), isFalse);
      expect(isUserCorrectable(_err('user-disabled')), isFalse);
      expect(isUserCorrectable(StateError('x')), isFalse);
    });
  });
}
