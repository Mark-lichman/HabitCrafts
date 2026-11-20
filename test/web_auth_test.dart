// Web sign-in, staying signed in and password reset (End states 7 and 8,
// PIN-8). Firebase is faked: the manager takes its auth, profile and
// analytics through constructor seams, so the same file runs in Chrome
// (`--platform chrome`) and on the VM.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_craft/auth/firebase_auth/firebase_auth_manager.dart';
import 'package:habit_craft/auth/firebase_auth/firebase_user_provider.dart';

class _FakeUser implements User {
  _FakeUser(this.uid, {this.isAnonymous = false, this.email});

  @override
  final String uid;
  @override
  final bool isAnonymous;
  @override
  final String? email;
  @override
  String? get displayName => null;
  @override
  String? get photoURL => null;
  @override
  String? get phoneNumber => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCredential implements UserCredential {
  _FakeCredential(this.user);

  @override
  final User? user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records each call the manager makes. Any call it does not expect, such as
/// a link of the anonymous user, throws through [noSuchMethod].
class _FakeAuth implements FirebaseAuth {
  _FakeAuth({this.current, this.signInUser, this.error});

  User? current;
  final User? signInUser;
  final FirebaseAuthException? error;
  final calls = <String>[];
  AuthProvider? popupProvider;
  Persistence? persistence;
  String? resetEmail;

  @override
  User? get currentUser => current;

  UserCredential _signIn() {
    if (error != null) throw error!;
    current = signInUser;
    return _FakeCredential(signInUser);
  }

  @override
  Future<UserCredential> signInWithPopup(AuthProvider provider) async {
    calls.add('popup');
    popupProvider = provider;
    return _signIn();
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword(
      {required String email, required String password}) async {
    calls.add('email:$email');
    return _signIn();
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword(
      {required String email, required String password}) async {
    calls.add('create:$email');
    return _signIn();
  }

  @override
  Future<void> setPersistence(Persistence persistence) async {
    calls.add('persistence');
    this.persistence = persistence;
  }

  @override
  Future<void> sendPasswordResetEmail(
      {required String email, ActionCodeSettings? actionCodeSettings}) async {
    calls.add('reset');
    if (error != null) throw error!;
    resetEmail = email;
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    current = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Harness {
  _Harness(this.auth, {bool isWeb = true}) {
    manager = FirebaseAuthManager(
      auth: () => auth,
      createUser: (user) async => profiles.add(user.uid),
      logAuthEvent: (user, method) => authEvents.add(method),
      logEvent: events.add,
      isWeb: isWeb,
    );
  }

  final _FakeAuth auth;
  final profiles = <String>[];
  final authEvents = <String>[];
  final events = <String>[];
  late final FirebaseAuthManager manager;
}

/// Pumps a page and returns a context that has a [ScaffoldMessenger].
Future<BuildContext> _context(WidgetTester tester) async {
  late BuildContext ctx;
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })),
  ));
  return ctx;
}

void main() {
  group('Google sign-in on the web', () {
    testWidgets('opens the Google popup and reaches the account uid',
        (tester) async {
      final ctx = await _context(tester);
      final h = _Harness(_FakeAuth(
        current: _FakeUser('anon-uid', isAnonymous: true),
        signInUser: _FakeUser('phone-uid', email: 'mark@example.com'),
      ));

      final user = await h.manager.signInWithGoogle(ctx);

      expect(user?.uid, 'phone-uid');
      expect(user?.loggedIn, isTrue);
      expect(h.auth.popupProvider, isA<GoogleAuthProvider>());
      // The popup opens first, so the browser still sees the user's tap.
      expect(h.auth.calls.first, 'popup');
      // The account is the Google account's own uid, never a link onto the
      // anonymous speaking-drill user.
      expect(h.profiles, ['phone-uid']);
      expect(h.authEvents, ['GOOGLE']);
    });

    testWidgets('a closed popup returns null with no error shown',
        (tester) async {
      final ctx = await _context(tester);
      final h = _Harness(_FakeAuth(
          error: FirebaseAuthException(code: 'popup-closed-by-user')));

      final user = await h.manager.signInWithGoogle(ctx);
      await tester.pump();

      expect(user, isNull);
      expect(h.profiles, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a blocked popup tells the user to allow pop-ups',
        (tester) async {
      final ctx = await _context(tester);
      final h = _Harness(
          _FakeAuth(error: FirebaseAuthException(code: 'popup-blocked')));

      final user = await h.manager.signInWithGoogle(ctx);
      await tester.pump();

      expect(user, isNull);
      expect(find.textContaining('Allow pop-ups'), findsOneWidget);
    });
  });

  group('email sign-in', () {
    testWidgets('reaches the account uid and replaces an anonymous user',
        (tester) async {
      final ctx = await _context(tester);
      final h = _Harness(_FakeAuth(
        current: _FakeUser('anon-uid', isAnonymous: true),
        signInUser: _FakeUser('phone-uid', email: 'mark@example.com'),
      ));

      final user =
          await h.manager.signInWithEmail(ctx, ' mark@example.com ', 'pw');

      expect(user?.uid, 'phone-uid');
      expect(user?.loggedIn, isTrue);
      expect(h.auth.calls.first, 'email:mark@example.com');
      expect(h.profiles, ['phone-uid']);
      expect(h.authEvents, ['EMAIL']);
    });

    testWidgets('a wrong password shows an error and returns null',
        (tester) async {
      final ctx = await _context(tester);
      final h = _Harness(_FakeAuth(
          error: FirebaseAuthException(code: 'INVALID_LOGIN_CREDENTIALS')));

      final user = await h.manager.signInWithEmail(ctx, 'a@b.c', 'bad');
      await tester.pump();

      expect(user, isNull);
      expect(find.textContaining('credential is incorrect'), findsOneWidget);
    });

    testWidgets('an error with no message still shows its code',
        (tester) async {
      final ctx = await _context(tester);
      final h = _Harness(_FakeAuth(
          error: FirebaseAuthException(code: 'network-request-failed')));

      final user = await h.manager.signInWithEmail(ctx, 'a@b.c', 'pw');
      await tester.pump();

      expect(user, isNull);
      expect(find.textContaining('network-request-failed'), findsOneWidget);
    });
  });

  group('staying signed in', () {
    testWidgets('a web sign-in keeps the session in IndexedDB', (tester) async {
      final ctx = await _context(tester);
      final h = _Harness(_FakeAuth(signInUser: _FakeUser('phone-uid')));

      await h.manager.signInWithEmail(ctx, 'a@b.c', 'pw');

      expect(h.auth.persistence, Persistence.INDEXED_DB);
    });

    testWidgets('a reload restores the same signed-in user', (tester) async {
      final ctx = await _context(tester);
      final auth = _FakeAuth(signInUser: _FakeUser('phone-uid'));
      await _Harness(auth).manager.signInWithEmail(ctx, 'a@b.c', 'pw');

      // A reload builds a new manager over the same persisted auth state.
      final restored = HabitCraftFirebaseUser(auth.currentUser);

      expect(restored.uid, 'phone-uid');
      expect(restored.loggedIn, isTrue);
    });

    testWidgets('the phone never sets persistence, a web-only call',
        (tester) async {
      final ctx = await _context(tester);
      final h =
          _Harness(_FakeAuth(signInUser: _FakeUser('phone-uid')), isWeb: false);

      await h.manager.signInWithEmail(ctx, 'a@b.c', 'pw');

      expect(h.auth.calls, isNot(contains('persistence')));
    });

    testWidgets('sign-out signs this browser out', (tester) async {
      final auth = _FakeAuth(current: _FakeUser('phone-uid'));
      final h = _Harness(auth);

      await h.manager.signOut();

      expect(auth.calls, ['signOut']);
      expect(auth.currentUser, isNull);
      expect(h.events, ['SIGN_OUT']);
    });
  });

  group('password reset', () {
    testWidgets('sends the reset email and confirms it', (tester) async {
      final ctx = await _context(tester);
      final h = _Harness(_FakeAuth());

      await h.manager.resetPassword(email: ' mark@example.com ', context: ctx);
      await tester.pump();

      expect(h.auth.resetEmail, 'mark@example.com');
      expect(find.text('Password reset email sent'), findsOneWidget);
    });

    testWidgets('a failed request shows the error, not the confirmation',
        (tester) async {
      final ctx = await _context(tester);
      final h = _Harness(
          _FakeAuth(error: FirebaseAuthException(code: 'invalid-email')));

      await h.manager.resetPassword(email: 'nope', context: ctx);
      await tester.pump();

      expect(find.textContaining('invalid-email'), findsOneWidget);
      expect(find.text('Password reset email sent'), findsNothing);
    });
  });
}
