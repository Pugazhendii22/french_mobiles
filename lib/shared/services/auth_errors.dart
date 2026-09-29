import 'package:firebase_auth/firebase_auth.dart';

/// Turns a sign-in failure into something a seller can act on.
///
/// Firebase's own messages are written for developers — "The SMS quota for
/// this project has been exceeded", "INVALID_LOGIN_CREDENTIALS" — and showing
/// them raw does two bad things at once: it tells the person nothing they can
/// use, and it leaks how the backend is put together. Every message here says
/// what went wrong *and* what to do about it, because an error that offers no
/// next step just strands people on the login screen.
String authErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      // --- phone number itself ---
      case 'invalid-phone-number':
        return 'That phone number does not look right. Check the digits and '
            'try again.';
      case 'missing-phone-number':
        return 'Enter your phone number first.';

      // --- the code ---
      case 'invalid-verification-code':
        return 'That code is not right. Check the message and type it again.';
      case 'session-expired':
      case 'code-expired':
        return 'That code has expired. Tap resend to get a new one.';
      case 'invalid-verification-id':
        return 'That code belongs to an older request. Tap resend and use the '
            'newest message.';

      // --- rate limiting, which is the one people hit most ---
      case 'too-many-requests':
        return 'Too many attempts. Wait a few minutes before trying again.';
      case 'quota-exceeded':
        return 'We cannot send any more codes right now. Try again later, or '
            'sign in with Google instead.';

      // --- account state ---
      case 'user-disabled':
        return 'This account has been disabled. Contact support if you think '
            'that is a mistake.';
      case 'account-exists-with-different-credential':
      case 'credential-already-in-use':
        return 'This number is already linked to another sign-in method. Try '
            'signing in with Google.';
      case 'operation-not-allowed':
        return 'That way of signing in is not available at the moment. Try '
            'the other option.';

      // --- connectivity ---
      case 'network-request-failed':
        return 'No connection. Check your internet and try again.';
      case 'web-context-cancelled':
      case 'user-cancelled':
        return 'Sign-in was cancelled.';
    }
  }

  // Anything unrecognised. Deliberately vague rather than dumping the
  // exception: a stack trace on the login screen helps nobody, and the real
  // detail is in the logs where it belongs.
  return 'Something went wrong signing you in. Please try again.';
}

/// Whether this failure is the person's own doing, or ours.
///
/// Used to decide tone: a mistyped code deserves a nudge, a backend outage
/// deserves an apology, and telling them apart stops the app blaming someone
/// for a problem they did not cause.
bool isUserCorrectable(Object error) {
  if (error is! FirebaseAuthException) return false;
  return const {
    'invalid-phone-number',
    'missing-phone-number',
    'invalid-verification-code',
    'session-expired',
    'code-expired',
    'invalid-verification-id',
  }.contains(error.code);
}
