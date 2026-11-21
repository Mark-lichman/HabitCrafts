import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

final _googleSignIn = GoogleSignIn(scopes: ['profile', 'email']);

/// Signs in with Google. [auth] and [isWeb] are seams for tests.
///
/// On the web the Firebase popup signs in, so the uid is the Google account's
/// own uid, the same one the phone reaches. The popup call must come before
/// any `await`: a browser blocks a popup that does not open in the user's tap.
Future<UserCredential?> googleSignInFunc({
  FirebaseAuth? auth,
  bool isWeb = kIsWeb,
}) async {
  final firebaseAuth = auth ?? FirebaseAuth.instance;
  if (isWeb) {
    return firebaseAuth.signInWithPopup(GoogleAuthProvider());
  }

  await signOutWithGoogle().catchError((_) => null);
  final googleAuth = await (await _googleSignIn.signIn())?.authentication;
  if (googleAuth == null) {
    return null;
  }
  final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken, accessToken: googleAuth.accessToken);
  return firebaseAuth.signInWithCredential(credential);
}

Future signOutWithGoogle() => _googleSignIn.signOut();
