import 'package:firebase_auth/firebase_auth.dart';

/// The auth seam [ensureCaller] needs: whether any Firebase user exists, and
/// a way to sign in anonymously. Tests pass a fake.
abstract class CallerAuth {
  bool get hasUser;
  Future<void> signInAnonymously();
}

class FirebaseCallerAuth implements CallerAuth {
  const FirebaseCallerAuth();

  @override
  bool get hasUser => FirebaseAuth.instance.currentUser != null;

  @override
  Future<void> signInAnonymously() async {
    await FirebaseAuth.instance.signInAnonymously();
  }
}

/// Makes sure a Firebase user exists before the drill calls the scoring
/// function (PIN-9).
///
/// Returns at once when any user exists, a real one or an earlier anonymous
/// one. Otherwise signs in anonymously in the background. An anonymous user
/// counts as signed out everywhere else: `loggedIn` is false for it, and the
/// Firestore and Storage rules refuse it.
///
/// A failed sign-in throws, so the caller can send the attempt to
/// self-check (PIN-3).
Future<void> ensureCaller(
    {CallerAuth auth = const FirebaseCallerAuth()}) async {
  if (auth.hasUser) return;
  await auth.signInAnonymously();
}
