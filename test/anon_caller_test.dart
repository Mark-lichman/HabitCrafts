// The anonymous caller (PIN-9): the speaking drill may need a Firebase
// sign-in to call the scoring function, but an anonymous user must stay
// signed out for every screen, the router and the rules.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_craft/auth/firebase_auth/firebase_user_provider.dart';
import 'package:habit_craft/components/pages/quiet_room_practice/anon_caller.dart';

class _FakeCallerAuth implements CallerAuth {
  _FakeCallerAuth({required this.hasUser, this.error});

  @override
  bool hasUser;
  final Object? error;
  int signIns = 0;

  @override
  Future<void> signInAnonymously() async {
    signIns++;
    if (error != null) throw error!;
    hasUser = true;
  }
}

class _FakeUser implements User {
  _FakeUser({required this.isAnonymous});

  @override
  final bool isAnonymous;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('ensureCaller', () {
    test('returns at once when a user exists, with no sign-in', () async {
      final auth = _FakeCallerAuth(hasUser: true);
      await ensureCaller(auth: auth);
      expect(auth.signIns, 0);
    });

    test('signs in anonymously when no user exists', () async {
      final auth = _FakeCallerAuth(hasUser: false);
      await ensureCaller(auth: auth);
      expect(auth.signIns, 1);
      expect(auth.hasUser, isTrue);
    });

    test('a second call after the sign-in does not sign in again', () async {
      final auth = _FakeCallerAuth(hasUser: false);
      await ensureCaller(auth: auth);
      await ensureCaller(auth: auth);
      expect(auth.signIns, 1);
    });

    test('a failed sign-in reaches the caller, so it can self-check', () async {
      final auth = _FakeCallerAuth(hasUser: false, error: StateError('off'));
      await expectLater(ensureCaller(auth: auth), throwsStateError);
    });
  });

  group('loggedIn', () {
    test('is false for an anonymous user', () {
      final user = HabitCraftFirebaseUser(_FakeUser(isAnonymous: true));
      expect(user.loggedIn, isFalse);
    });

    test('is true for a real (non-anonymous) user', () {
      final user = HabitCraftFirebaseUser(_FakeUser(isAnonymous: false));
      expect(user.loggedIn, isTrue);
    });

    test('is false with no user', () {
      expect(HabitCraftFirebaseUser(null).loggedIn, isFalse);
    });
  });
}
