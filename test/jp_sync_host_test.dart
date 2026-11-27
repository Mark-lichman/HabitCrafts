// The sync host and the sign-out wipe (plan 2026-11-19, Task 6, End state 7, D8, PIN-8).
//
// The host runs a sync after a non-anonymous sign-in and on app resume, and never for an
// anonymous or signed-out user. On the web, sign-out, account delete, and losing the user when
// nothing is unsynced empty this browser's study record through the store wipe, which also
// clears the sync cursor and the replay flag. A browser record that belongs to another account is wiped before
// it can reach the new account. The profile page's "Signed-in devices" entry opens the
// devices page.
//
// The two operator rulings (Checkpoint 2026-11-20): (a) on the web, a failed last sync with
// answers left to push stops sign-out until the user picks "wait" or "sign out anyway", and
// nothing is wiped without that pick. (b) On the phone, another account signing in over a
// record with a different (or deleted) owner is asked once: keep the record local, upload it
// to the new account, or start fresh. Then the new account syncs. The phone never wipes on
// sign-out.
//
// The four account-switch rulings (Checkpoint 2026-11-21, Task 16): (a) a kept record comes back
// when its owner signs in again on that phone, and a later keep for the same owner adds to the
// earlier kept record, never replaces it. (b) Start fresh and keep local clear the day plans too,
// so the new account receives no old plan. (c) On the web, a study store that will not open at
// Log Out shows a message with "sign out anyway"; the record stays until another account's
// sign-in wipes it. (d) On the web, a session that ends without Log Out keeps a record with
// unsynced answers: the same account's next sign-in pushes them, another account's wipes them.
//
// It runs in Chrome (the Done-when) and on the VM (the gate), so it imports no `dart:io`. The
// web store runs over in-memory browser storage, the remote is `JpRemoteMemory`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:habit_craft/auth/base_auth_user_provider.dart';
import 'package:habit_craft/components/pages/devices_page/devices_page_widget.dart';
import 'package:habit_craft/components/pages/profile_page/profile_page_widget.dart'
    show ProfileDevicesEntry;
import 'package:habit_craft/components/pages/quiet_room_mastery/attempt.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/fsrs.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/item_catalog.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_event.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_remote.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_memory.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_web.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_sync.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_sync_host_service.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/study_export.dart'
    show decodeStudyExport, encodeStudyExport;

/// An auth user with a fixed uid and sign-in state. An anonymous user has a uid but is not
/// logged in (`HabitCraftFirebaseUser.loggedIn`).
class _User extends BaseAuthUser {
  _User(this.id, {this.loggedIn = true});

  final String id;
  @override
  final bool loggedIn;
  @override
  bool get emailVerified => true;
  @override
  AuthUserInfo get authUserInfo => AuthUserInfo(uid: id);
  @override
  Future? delete() => null;
  @override
  Future? updateEmail(String email) => null;
  @override
  Future? updatePassword(String newPassword) => null;
  @override
  Future? sendEmailVerification() => null;
}

/// One grammar item the answers score against. It is built here, not read from the asset
/// catalog, because the Flutter web test server serves no `assets/` folder: a `rootBundle`
/// read never completes in Chrome.
final ItemDef grammarItem = ItemDef(
  id: 'mari.L26.1',
  kind: ItemKind.grammar,
  title: '〜んです',
  prereqLevel: 2,
  lesson: 26,
  probes: const [
    ProbeDef(
        id: 'p0', template: 'choose', text: 'あした テストが ＿＿んです。', answer: 'ある'),
  ],
);

ItemDef? lookup(String itemId) => itemId == grammarItem.id ? grammarItem : null;

const scheduler = FsrsScheduler();
final DateTime t0 = DateTime.utc(2026, 11, 20, 9);

Attempt answer(int minute) {
  final item = grammarItem;
  final p = item.scoredProbes.first;
  return Attempt(
    itemId: item.id,
    probeId: p.id,
    template: p.template,
    production: p.production,
    selfGraded: p.selfGraded,
    atUtc: t0.add(Duration(minutes: minute)),
    localDay: 0,
    grade: Grade.clear,
    rating: fsrsRatingFor(Grade.clear),
    wasDue: true,
    source: Source.review,
    sessionId: 's0',
  );
}

Future<void> record(JpStore store, Attempt a) =>
    store.recordAnswer(a, item: lookup(a.itemId), scheduler: scheduler);

/// A store that is not a `JpStoreMemory`, so it has no wipe. Only [meta] answers: any other
/// call fails the test.
class _NoWipeStore implements JpStore {
  _NoWipeStore({this.owner});

  final String? owner;

  @override
  Future<String?> meta(String key) async =>
      key == kSyncOwnerMetaKey ? owner : null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('_NoWipeStore: ${invocation.memberName}');
}

/// A phone store whose next write of the [failNext] meta key and value throws, one time.
class _FailOnceStore extends JpStoreMemory {
  _FailOnceStore() : super(clock: () => t0);

  /// The meta key and value whose next write throws; null for none.
  (String, String)? failNext;

  @override
  Future<void> putMeta(String key, String value) async {
    if (failNext == (key, value)) {
      failNext = null;
      throw StateError('write failed: $key');
    }
    return super.putMeta(key, value);
  }
}

/// One browser (or phone) under test: its store, the remote of each account, and its host.
class Rig {
  Rig(this.store, {this.isWeb = true, this.ownerChoice}) {
    host = JpSyncHost(
      openStore: () async {
        if (failOpen) throw StateError('missing migration step');
        return store;
      },
      remoteFor: (uid) => remotes.putIfAbsent(uid, JpRemoteMemory.new),
      loadLookup: () async => lookup,
      isWeb: isWeb,
      deviceName: isWeb ? 'Web browser' : 'Android phone',
      clock: () => t0.add(const Duration(hours: 1)),
      onError: (e, _) => errors.add(e),
    );
    if (ownerChoice != null) {
      host.askOwner = (previous) async {
        asked.add(previous);
        return ownerChoice;
      };
    }
  }

  final JpStore store;
  final bool isWeb;

  /// Whether opening the store throws, as a store with a missing migration step does.
  bool failOpen = false;

  /// What the phone's user picks when it asks about another account's record.
  final JpOwnerChoice? ownerChoice;

  /// The previous owner of each ask, in order.
  final List<String> asked = [];
  final Map<String, JpRemoteMemory> remotes = {};
  final List<Object> errors = [];
  late final JpSyncHost host;

  JpRemoteMemory remote(String uid) =>
      remotes.putIfAbsent(uid, JpRemoteMemory.new);
}

Future<JpStoreWeb> webStore() =>
    JpStoreWeb.open(storage: MemoryJpWebStorage(), clock: () => t0);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('when it syncs', () {
    test('a non-anonymous sign-in syncs: the answer reaches the remote',
        () async {
      final rig = Rig(await webStore());
      await record(rig.store, answer(0));

      await rig.host.userChanged(_User('mark'));

      final remote = rig.remote('mark');
      expect(remote.events, hasLength(1));
      expect(await rig.store.unpushedEvents(), isEmpty);
      expect((await remote.devices()).single.name, 'Web browser');
      expect(await rig.store.meta(kSyncOwnerMetaKey), 'mark');
      expect(rig.errors, isEmpty);
    });

    test('an anonymous user never syncs, on sign-in or on resume', () async {
      final rig = Rig(await webStore());
      await record(rig.store, answer(0));

      await rig.host.userChanged(_User('anon', loggedIn: false));
      await rig.host.resume();

      expect(rig.remotes, isEmpty, reason: 'no remote was opened');
      expect(await rig.store.unpushedEvents(), hasLength(1));
      expect(await rig.store.meta(kSyncOwnerMetaKey), isNull);
    });

    test('nobody signed in never syncs', () async {
      final rig = Rig(await webStore());
      await record(rig.store, answer(0));

      await rig.host.userChanged(null);
      await rig.host.resume();

      expect(rig.remotes, isEmpty);
      expect(await rig.store.unpushedEvents(), hasLength(1));
    });

    test('app resume syncs again and pulls the other device\'s answer',
        () async {
      final rig = Rig(await webStore());
      await rig.host.userChanged(_User('mark'));
      expect(await rig.store.allEvents(), isEmpty);

      // The phone answers and syncs to the same account.
      final phone = JpStoreMemory(clock: () => t0);
      await record(phone, answer(5));
      await JpSync(
              store: phone,
              remote: rig.remote('mark'),
              lookup: lookup,
              scheduler: scheduler,
              deviceName: 'Android phone')
          .run();

      await rig.host.resume();

      expect(await rig.store.allEvents(), hasLength(1));
      expect(await rig.store.allSrs(), await phone.allSrs());
      expect(await rig.store.allMastery(), await phone.allMastery());
    });

    test('the same user again (a token refresh) does not start another sync',
        () async {
      final rig = Rig(await webStore());
      await rig.host.userChanged(_User('mark'));
      final first = (await rig.remote('mark').devices()).single;

      await record(rig.store, answer(1));
      await rig.host.userChanged(_User('mark'));

      expect(await rig.store.unpushedEvents(), hasLength(1));
      expect((await rig.remote('mark').devices()).single, first);
    });

    test(
        'an offline sync is reported, not thrown, and the next resume catches up',
        () async {
      final rig = Rig(await webStore());
      rig.remote('mark').online = false;
      await record(rig.store, answer(0));

      await rig.host.userChanged(_User('mark'));
      expect(rig.errors.single, isA<JpRemoteUnavailable>());
      expect(await rig.store.unpushedEvents(), hasLength(1));

      rig.remote('mark').online = true;
      await rig.host.resume();
      expect(rig.remote('mark').events, hasLength(1));
      expect(await rig.store.unpushedEvents(), isEmpty);
    });
  });

  group('sign-out on the web', () {
    test(
        'wipes the store, its sync cursor and its replay flag, and keeps the device id',
        () async {
      SharedPreferences.setMockInitialValues({
        'jp.selfcheck.g1': 'can_use_it',
        'jp.vocab.lastLesson': 4,
        'ff_theme': 'light',
      });
      final rig = Rig(await webStore());
      final device = await rig.store.deviceId();
      await record(rig.store, answer(0));
      await rig.host.userChanged(_User('mark'));
      await rig.store.putMeta(kSyncReplayPendingMetaKey, '1');
      expect(await rig.store.meta(kSyncCursorMetaKey), isNotNull);

      await rig.host.signOut();

      expect(await rig.store.allEvents(), isEmpty);
      expect(await rig.store.allSrs(), isEmpty);
      expect(await rig.store.allMastery(), isEmpty);
      expect(await rig.store.meta(kSyncCursorMetaKey), isNull);
      expect(await rig.store.meta(kSyncReplayPendingMetaKey), isNull);
      expect(await rig.store.meta(kSyncOwnerMetaKey), isNull);
      expect(await rig.store.deviceId(), device);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), {'ff_theme'},
          reason: 'the browser\'s jp. study keys go, the rest stay');
      expect(rig.errors, isEmpty);
    });

    test('pushes the answers not yet synced before it wipes', () async {
      final rig = Rig(await webStore());
      await rig.host.userChanged(_User('mark'));
      await record(rig.store, answer(2));

      expect(await rig.host.signOut(), isTrue);

      expect(rig.remote('mark').events, hasLength(1));
      expect(await rig.store.allEvents(), isEmpty);
    });

    group('when the last sync fails (operator ruling a)', () {
      Future<Rig> offlineWithAnAnswer() async {
        final rig = Rig(await webStore());
        await rig.host.userChanged(_User('mark'));
        await record(rig.store, answer(2));
        rig.remote('mark').online = false;
        return rig;
      }

      test('sign-out stops and asks, and "wait" wipes nothing', () async {
        final rig = await offlineWithAnAnswer();
        var asks = 0;

        final signedOut = await rig.host.signOut(signOutAnyway: () async {
          asks++;
          return false;
        });

        expect(signedOut, isFalse);
        expect(asks, 1);
        expect(await rig.store.allEvents(), hasLength(1));
        expect(await rig.store.unpushedEvents(), hasLength(1));
        expect(await rig.store.meta(kSyncOwnerMetaKey), 'mark');
        expect(rig.host.uid, 'mark', reason: 'still signed in, so it syncs on');

        // Back online, the next resume pushes the answer.
        rig.remote('mark').online = true;
        await rig.host.resume();
        expect(rig.remote('mark').events, hasLength(1));
      });

      test('no answer to the ask counts as "wait"', () async {
        final rig = await offlineWithAnAnswer();

        expect(await rig.host.signOut(), isFalse);

        expect(await rig.store.allEvents(), hasLength(1));
      });

      test('"sign out anyway" wipes', () async {
        final rig = await offlineWithAnAnswer();

        final signedOut =
            await rig.host.signOut(signOutAnyway: () async => true);

        expect(signedOut, isTrue);
        expect(await rig.store.allEvents(), isEmpty);
        expect(await rig.store.meta(kSyncCursorMetaKey), isNull);
        expect(rig.host.uid, isNull);
      });

      test('a failed sync with nothing left to push signs out without asking',
          () async {
        final rig = Rig(await webStore());
        await record(rig.store, answer(0));
        await rig.host.userChanged(_User('mark'));
        rig.remote('mark').online = false;
        var asks = 0;

        final signedOut = await rig.host.signOut(signOutAnyway: () async {
          asks++;
          return false;
        });

        expect(signedOut, isTrue);
        expect(asks, 0);
        expect(await rig.store.allEvents(), isEmpty);
      });

      test(
          'a record with no owner yet still asks: the sign-in sync failed early',
          () async {
        final rig = Rig(await webStore());
        rig.failOpen = true;
        await rig.host.userChanged(_User('mark'));
        rig.failOpen = false;
        expect(await rig.store.meta(kSyncOwnerMetaKey), isNull);
        await record(rig.store, answer(2));
        rig.remote('mark').online = false;

        final signedOut =
            await rig.host.signOut(signOutAnyway: () async => false);

        expect(signedOut, isFalse);
        expect(await rig.store.unpushedEvents(), hasLength(1));
        expect(rig.host.uid, 'mark');
      });

      test('an empty owner counts as no owner', () async {
        final rig = Rig(await webStore());
        rig.failOpen = true;
        await rig.host.userChanged(_User('mark'));
        rig.failOpen = false;
        await rig.store.putMeta(kSyncOwnerMetaKey, '');
        await record(rig.store, answer(2));
        rig.remote('mark').online = false;

        expect(
            await rig.host.signOut(signOutAnyway: () async => false), isFalse);
        expect(await rig.store.unpushedEvents(), hasLength(1));
      });
    });

    test('a record with no owner yet is pushed by the last sync', () async {
      final rig = Rig(await webStore());
      rig.failOpen = true;
      await rig.host.userChanged(_User('mark'));
      rig.failOpen = false;
      await record(rig.store, answer(2));

      expect(await rig.host.signOut(), isTrue);

      expect(rig.remote('mark').events, hasLength(1));
      expect(await rig.store.allEvents(), isEmpty);
    });

    test(
        'losing the user from the auth stream (account delete) wipes a record '
        'with nothing unsynced', () async {
      final rig = Rig(await webStore());
      await record(rig.store, answer(0));
      await rig.host.userChanged(_User('mark'));

      await rig.host.userChanged(null);

      expect(await rig.store.allEvents(), isEmpty);
      expect(await rig.store.meta(kSyncCursorMetaKey), isNull);
    });

    group('a session that ends without Log Out (operator ruling d)', () {
      /// A browser signed in as mark, with one answer the remote never received.
      Future<Rig> unsyncedAnswer() async {
        final rig = Rig(await webStore());
        await rig.host.userChanged(_User('mark'));
        rig.remote('mark').online = false;
        await record(rig.store, answer(2));
        return rig;
      }

      test('keeps a record with unsynced answers', () async {
        final rig = await unsyncedAnswer();

        await rig.host.userChanged(null);

        expect(await rig.store.unpushedEvents(), hasLength(1));
        expect(await rig.store.meta(kSyncOwnerMetaKey), 'mark');
        expect(rig.host.uid, isNull);
        expect(rig.errors, isEmpty);
      });

      test('the same account\'s next sign-in pushes the kept answers',
          () async {
        final rig = await unsyncedAnswer();
        await rig.host.userChanged(null);
        rig.remote('mark').online = true;

        await rig.host.userChanged(_User('mark'));

        expect(rig.remote('mark').events, hasLength(1));
        expect(await rig.store.unpushedEvents(), isEmpty);
      });

      test('another account\'s sign-in wipes the kept answers', () async {
        final rig = await unsyncedAnswer();
        await rig.host.userChanged(null);

        await rig.host.userChanged(_User('other'));

        expect(rig.remote('other').events, isEmpty);
        expect(await rig.store.allEvents(), isEmpty);
        expect(await rig.store.meta(kSyncOwnerMetaKey), 'other');
        expect(rig.remote('mark').events, isEmpty);
      });

      test(
          'a kept record with no owner yet takes the lost account as owner, so '
          'another account cannot claim it', () async {
        final rig = Rig(await webStore());
        rig.failOpen = true;
        await rig.host.userChanged(_User('mark'));
        rig.failOpen = false;
        await record(rig.store, answer(2));
        expect(await rig.store.meta(kSyncOwnerMetaKey), isNull);

        await rig.host.userChanged(null);
        expect(await rig.store.meta(kSyncOwnerMetaKey), 'mark');
        await rig.host.userChanged(_User('other'));

        expect(rig.remote('other').events, isEmpty);
        expect(await rig.store.allEvents(), isEmpty);
      });
    });

    group('account delete', () {
      /// A browser signed in as mark, one answer unsynced, and a `jp.` key set.
      Future<Rig> unsyncedAnswer() async {
        SharedPreferences.setMockInitialValues({'jp.vocab.lastLesson': 4});
        final rig = Rig(await webStore());
        await rig.host.userChanged(_User('mark'));
        rig.remote('mark').online = false;
        await record(rig.store, answer(2));
        expect(await rig.store.unpushedEvents(), hasLength(1));
        return rig;
      }

      Future<void> expectWiped(Rig rig) async {
        expect(await rig.store.allEvents(), isEmpty);
        expect(await rig.store.unpushedEvents(), isEmpty);
        expect(await rig.store.meta(kSyncOwnerMetaKey), isNull);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getKeys().where((k) => k.startsWith('jp.')), isEmpty);
        expect(rig.errors, isEmpty);
      }

      test(
          'wipes a record with unsynced answers after the auth stream loses '
          'the user', () async {
        final rig = await unsyncedAnswer();
        await rig.host.userChanged(null);
        expect(await rig.store.unpushedEvents(), hasLength(1),
            reason: 'losing the user alone keeps them (ruling d)');

        await rig.host.forget();

        await expectWiped(rig);
      });

      test('wipes them before the auth stream reports the loss too', () async {
        final rig = await unsyncedAnswer();

        await rig.host.forget();
        await rig.host.userChanged(null);

        await expectWiped(rig);
        expect(rig.host.uid, isNull);
      });

      test('the phone keeps its record', () async {
        final rig = Rig(JpStoreMemory(clock: () => t0), isWeb: false);
        await rig.host.userChanged(_User('mark'));
        rig.remote('mark').online = false;
        await record(rig.store, answer(2));

        await rig.host.forget();
        await rig.host.userChanged(null);

        expect(await rig.store.unpushedEvents(), hasLength(1));
        expect(rig.errors, isEmpty);
      });

      test('a web store with no wipe is reported, never thrown', () async {
        final rig = Rig(_NoWipeStore());

        await rig.host.forget();

        expect(rig.errors.single, isA<StateError>());
      });
    });

    test('no sync runs after the wipe, even on resume', () async {
      final rig = Rig(await webStore());
      await rig.host.userChanged(_User('mark'));
      await rig.host.signOut();
      final devices = await rig.remote('mark').devices();

      await rig.host.resume();

      expect(await rig.remote('mark').devices(), devices);
      expect(await rig.store.allEvents(), isEmpty);
    });

    test(
        'a record another account left in this browser never reaches the next account',
        () async {
      final store = await webStore();
      // Account A studied here, then the tab closed before any sign-out.
      final before = Rig(store);
      await record(store, answer(0));
      await before.host.userChanged(_User('a'));
      expect(await store.meta(kSyncOwnerMetaKey), 'a');

      // A reload signs in as B.
      final after = Rig(store);
      await after.host.userChanged(_User('b'));

      expect(after.remote('b').events, isEmpty);
      expect(await store.allEvents(), isEmpty);
      expect(await store.meta(kSyncOwnerMetaKey), 'b');
    });
  });

  group('on the phone', () {
    test('sign-out keeps the record', () async {
      final rig = Rig(JpStoreMemory(clock: () => t0), isWeb: false);
      await record(rig.store, answer(0));
      await rig.host.userChanged(_User('mark'));

      await rig.host.signOut();
      await rig.host.userChanged(null);

      expect(await rig.store.allEvents(), hasLength(1));
      expect(await rig.store.meta(kSyncCursorMetaKey), isNotNull);
    });

    test('a failed last sync never stops sign-out, because nothing is wiped',
        () async {
      final rig = Rig(JpStoreMemory(clock: () => t0), isWeb: false);
      await rig.host.userChanged(_User('mark'));
      await record(rig.store, answer(0));
      rig.remote('mark').online = false;
      var asks = 0;

      final signedOut = await rig.host.signOut(signOutAnyway: () async {
        asks++;
        return false;
      });

      expect(signedOut, isTrue);
      expect(asks, 0);
      expect(await rig.store.unpushedEvents(), hasLength(1));
    });

    group('another account signs in (operator ruling b)', () {
      /// A phone whose record account A synced, its answer on A's remote, then one more
      /// answer A never pushed.
      Future<Rig> phoneOfA(JpOwnerChoice? choice, {JpStore? store}) async {
        final rig = Rig(store ?? JpStoreMemory(clock: () => t0),
            isWeb: false, ownerChoice: choice);
        await record(rig.store, answer(0));
        await rig.host.userChanged(_User('a'));
        await rig.host.signOut();
        await rig.host.userChanged(null);
        await record(rig.store, answer(1));
        expect(rig.remote('a').events, hasLength(1));
        return rig;
      }

      /// Account B's own answer, synced from B's other device.
      Future<void> bAnsweredElsewhere(Rig rig) async {
        final other = JpStoreMemory(clock: () => t0);
        await record(other, answer(9));
        await JpSync(
                store: other,
                remote: rig.remote('b'),
                lookup: lookup,
                scheduler: scheduler,
                deviceName: 'Web browser')
            .run();
      }

      test('"upload" puts the whole record on the new account, then it syncs',
          () async {
        final rig = await phoneOfA(JpOwnerChoice.upload);
        await bAnsweredElsewhere(rig);

        await rig.host.userChanged(_User('b'));

        expect(rig.asked, ['a']);
        expect(rig.remote('b').events, hasLength(3),
            reason: 'both of A\'s answers, the pushed one too, plus B\'s own');
        expect(await rig.store.allEvents(), hasLength(3));
        expect(await rig.store.meta(kSyncOwnerMetaKey), 'b');
        expect(rig.remote('a').events, hasLength(1), reason: 'A is untouched');
        expect(rig.errors, isEmpty);
      });

      test('"start fresh" empties the record, then the new account syncs',
          () async {
        final rig = await phoneOfA(JpOwnerChoice.startFresh);
        await bAnsweredElsewhere(rig);

        await rig.host.userChanged(_User('b'));

        expect(rig.asked, ['a']);
        expect(rig.remote('b').events, hasLength(1), reason: 'only B\'s own');
        final events = await rig.store.allEvents();
        expect(events, hasLength(1));
        expect(events.single.eventId, rig.remote('b').events.single.eventId);
        expect(await rig.store.meta(kSyncOwnerMetaKey), 'b');
        expect(await rig.store.meta('${kKeptRecordMetaPrefix}a'), isNull);
        expect(rig.errors, isEmpty);
      });

      test(
          '"keep it local" keeps A\'s record on the phone, unsent, and B syncs',
          () async {
        final rig = await phoneOfA(JpOwnerChoice.keepLocal);
        final before = await rig.store.exportLog();
        await bAnsweredElsewhere(rig);

        await rig.host.userChanged(_User('b'));

        expect(rig.asked, ['a']);
        expect(rig.remote('b').events, hasLength(1), reason: 'none of A\'s');
        expect(rig.remote('a').events, hasLength(1),
            reason: 'A\'s unpushed answer is not sent to A either');
        expect(await rig.store.allEvents(), hasLength(1));
        expect(await rig.store.meta(kSyncOwnerMetaKey), 'b');

        // A's whole record stays on the phone as a study export, both answers in it.
        final kept = await rig.store.meta('${kKeptRecordMetaPrefix}a');
        expect(kept, isNotNull);
        final log = decodeStudyExport(kept!);
        expect([for (final a in log.attempts) a.eventId],
            [for (final a in before.attempts) a.eventId]);
        expect(log.attempts, hasLength(2));
        expect(rig.errors, isEmpty);
      });

      // "Keep it local" cut short after the record emptied: the write named here throws one
      // time, so the pick finishes on the next resume, on an empty record.
      for (final (name, failing) in const [
        ('the owner write', (kSyncOwnerMetaKey, 'b')),
        ('the replay flag write', (kSyncReplayPendingMetaKey, '0')),
      ]) {
        test(
            '"keep it local" cut short at $name keeps A\'s export on the retry',
            () async {
          final store = _FailOnceStore();
          final rig = await phoneOfA(JpOwnerChoice.keepLocal, store: store);
          final before = await store.exportLog();
          await bAnsweredElsewhere(rig);
          store.failNext = failing;

          await rig.host.userChanged(_User('b'));
          expect(rig.errors.single, isA<StateError>());
          expect(store.failNext, isNull, reason: 'the write was reached');
          expect(await store.meta(kSyncOwnerMetaKey), 'a',
              reason: 'the record is not B\'s until the pick\'s work lands');
          expect(await store.allEvents(), isEmpty);

          await rig.host.resume();

          final log = decodeStudyExport(
              (await store.meta('${kKeptRecordMetaPrefix}a'))!);
          expect(log.attempts, hasLength(2));
          expect([for (final a in log.attempts) a.eventId],
              [for (final a in before.attempts) a.eventId]);
          expect(rig.asked, ['a']);
          expect(rig.errors, hasLength(1));
          expect(await store.meta(kSyncOwnerMetaKey), 'b');
          expect(await store.allEvents(), hasLength(1),
              reason: 'only B\'s own');
          expect(rig.remote('b').events, hasLength(1), reason: 'none of A\'s');
        });
      }

      test('"keep it local" on an empty record writes no export', () async {
        final rig = Rig(JpStoreMemory(clock: () => t0),
            isWeb: false, ownerChoice: JpOwnerChoice.keepLocal);
        await rig.host.userChanged(_User('a'));
        await rig.host.signOut();
        await rig.host.userChanged(null);

        await rig.host.userChanged(_User('b'));

        expect(rig.asked, ['a']);
        expect(await rig.store.meta('${kKeptRecordMetaPrefix}a'), isNull);
        expect(await rig.store.meta(kSyncOwnerMetaKey), 'b');
        expect(rig.errors, isEmpty);
      });

      List<String> ids(Iterable<JpEvent> events) =>
          [for (final e in events) e.eventId];

      group('a kept record (Checkpoint 2026-11-21, ruling a)', () {
        test(
            'comes back when the old owner signs in again, and its unsynced '
            'answer reaches the old owner', () async {
          final rig = await phoneOfA(JpOwnerChoice.keepLocal);
          final aIds = ids(await rig.store.allEvents());
          await bAnsweredElsewhere(rig);
          await rig.host.userChanged(_User('b'));
          final bIds = ids(await rig.store.allEvents());
          await rig.host.signOut();
          await rig.host.userChanged(null);

          await rig.host.userChanged(_User('a'));

          expect(rig.asked, ['a', 'b']);
          expect(ids(await rig.store.allEvents())..sort(), [...aIds]..sort(),
              reason: 'A\'s record is back, B\'s is kept apart under B');
          expect(await rig.store.allSrs(), isNotEmpty,
              reason: 'the restored record is replayed');
          expect(ids(rig.remote('a').events)..sort(), [...aIds]..sort(),
              reason: 'A\'s unpushed answer reaches A, and none of B\'s');
          expect(await rig.store.unpushedEvents(), isEmpty);
          expect(await rig.store.meta('${kKeptRecordMetaPrefix}a'), isEmpty,
              reason: 'the kept record is used up');
          final keptB = decodeStudyExport(
              (await rig.store.meta('${kKeptRecordMetaPrefix}b'))!);
          expect([for (final a in keptB.attempts) a.eventId], bIds);
          expect(await rig.store.meta(kSyncOwnerMetaKey), 'a');
          expect(rig.errors, isEmpty);
        });

        test(
            'comes back on top of a record uploaded to the old owner, '
            'nothing lost', () async {
          final rig = await phoneOfA(JpOwnerChoice.keepLocal);
          final aIds = ids(await rig.store.allEvents());
          await rig.host.userChanged(_User('b'));
          await record(rig.store, answer(5));
          final bIds = ids(await rig.store.unpushedEvents());
          await rig.host.signOut();
          await rig.host.userChanged(null);
          rig.host.askOwner = (previous) async {
            rig.asked.add(previous);
            return JpOwnerChoice.upload;
          };

          await rig.host.userChanged(_User('a'));

          final all = [...aIds, ...bIds]..sort();
          expect(ids(await rig.store.allEvents())..sort(), all);
          expect(ids(rig.remote('a').events)..sort(), all);
          expect(await rig.store.unpushedEvents(), isEmpty);
        });

        test(
            'a later keep for the same owner adds to the earlier kept record, '
            'never replaces it', () async {
          final rig = await phoneOfA(JpOwnerChoice.keepLocal);
          final earlierStore = JpStoreMemory(clock: () => t0);
          await record(earlierStore, answer(7));
          final earlier = await earlierStore.exportLog();
          await rig.store.putMeta('${kKeptRecordMetaPrefix}a',
              encodeStudyExport(earlier, exportedAt: t0));
          final later = await rig.store.exportLog();

          await rig.host.userChanged(_User('b'));

          final kept = decodeStudyExport(
              (await rig.store.meta('${kKeptRecordMetaPrefix}a'))!);
          expect(
              [for (final a in kept.attempts) a.eventId]..sort(),
              [
                for (final a in [...earlier.attempts, ...later.attempts])
                  a.eventId
              ]..sort());
          expect(kept.attempts, hasLength(3));
          expect(rig.errors, isEmpty);
        });

        // A pick cut short at the owner write finishes on the next resume. B answered in
        // between, so the retry must not empty the record again nor keep B's answer as A's.
        for (final choice in [
          JpOwnerChoice.keepLocal,
          JpOwnerChoice.startFresh
        ]) {
          test('a $choice retried after B answered keeps B\'s answer as B\'s',
              () async {
            final store = _FailOnceStore();
            final rig = await phoneOfA(choice, store: store);
            final before = ids(await store.allEvents());
            store.failNext = (kSyncOwnerMetaKey, 'b');
            await rig.host.userChanged(_User('b'));
            expect(rig.errors.single, isA<StateError>());
            await record(store, answer(4));
            final bAnswer = ids(await store.unpushedEvents()).single;

            await rig.host.resume();

            expect(ids(await store.allEvents()), [bAnswer]);
            expect(ids(rig.remote('b').events), [bAnswer]);
            expect(rig.asked, ['a']);
            final kept = await store.meta('${kKeptRecordMetaPrefix}a');
            if (choice == JpOwnerChoice.keepLocal) {
              expect([
                for (final a in decodeStudyExport(kept!).attempts) a.eventId
              ], before);
            } else {
              expect(kept, isNull);
            }
          });
        }
      });

      group('the day plans (Checkpoint 2026-11-21, ruling b)', () {
        for (final choice in [
          JpOwnerChoice.startFresh,
          JpOwnerChoice.keepLocal
        ]) {
          test('$choice clears them, so the new account receives no old plan',
              () async {
            final rig = await phoneOfA(choice);
            await rig.store.putDay(const DayRecord(
                day: 5, plan: '{"entries":["a"]}', position: 1));

            await rig.host.userChanged(_User('b'));

            expect(await rig.store.lastDay(), isNull);
            expect(await rig.store.day(5), isNull);
            expect(await rig.remote('b').day(5), isNull);
            expect(rig.errors, isEmpty);
          });
        }

        test('upload keeps them: the record is the new account\'s', () async {
          final rig = await phoneOfA(JpOwnerChoice.upload);
          await rig.store.putDay(
              const DayRecord(day: 5, plan: '{"entries":["a"]}', position: 1));

          await rig.host.userChanged(_User('b'));

          expect(await rig.store.lastDay(), 5);
          expect((await rig.remote('b').day(5))?.plan, '{"entries":["a"]}');
        });
      });

      test(
          'a record holds something with any one of its parts, and nothing empty',
          () {
        const item = 'mari.L26.1';
        expect(studyLogHoldsRecord(const StudyLog()), isFalse);
        expect(studyLogHoldsRecord(StudyLog(attempts: [answer(0)])), isTrue);
        expect(
            studyLogHoldsRecord(StudyLog(
                seeds: [SeedEvent(itemId: item, dueDay: 1, atUtc: t0)])),
            isTrue);
        expect(
            studyLogHoldsRecord(const StudyLog(notes: {item: 'ask'})), isTrue);
        expect(
            studyLogHoldsRecord(StudyLog(
                discuss: {item: DiscussMark(itemId: item, atUtc: t0)})),
            isTrue);
        expect(
            studyLogHoldsRecord(StudyLog(events: [
              JpEvent(
                  eventId: 'e1',
                  atUtc: t0,
                  kind: JpEventKind.lastLesson,
                  body: const {'lesson': 26})
            ])),
            isTrue);
      });

      test('asks once: a resume after the choice syncs without asking',
          () async {
        final rig = await phoneOfA(JpOwnerChoice.upload);
        await rig.host.userChanged(_User('b'));
        await record(rig.store, answer(3));

        await rig.host.resume();

        expect(rig.asked, ['a']);
        expect(rig.remote('b').events, hasLength(3));
      });

      test('a deleted owner asks the same way', () async {
        // Account A was deleted: its remote is gone, and its uid never signs in again.
        final rig = await phoneOfA(JpOwnerChoice.startFresh);
        rig.remotes.remove('a');

        await rig.host.userChanged(_User('b'));

        expect(rig.asked, ['a']);
        expect(await rig.store.allEvents(), isEmpty);
        expect(await rig.store.meta(kSyncOwnerMetaKey), 'b');
        expect(rig.remotes.containsKey('a'), isFalse);
      });

      test(
          'no answer changes nothing, syncs nothing, and does not ask again '
          'on resume', () async {
        final rig = await phoneOfA(null);
        var asks = 0;
        rig.host.askOwner = (_) async {
          asks++;
          return null;
        };

        await rig.host.userChanged(_User('b'));
        await rig.host.resume();

        expect(asks, 1);
        expect(rig.remotes.containsKey('b'), isFalse);
        expect(await rig.store.allEvents(), hasLength(2));
        expect(await rig.store.meta(kSyncOwnerMetaKey), 'a');
      });

      test('the owner coming back syncs as before, with no ask', () async {
        final rig = await phoneOfA(JpOwnerChoice.startFresh);

        await rig.host.userChanged(_User('a'));

        expect(rig.asked, isEmpty);
        expect(rig.remote('a').events, hasLength(2));
      });

      test('an upload cut short by the network asks no more and finishes later',
          () async {
        final rig = await phoneOfA(JpOwnerChoice.upload);
        rig.remote('b').online = false;

        await rig.host.userChanged(_User('b'));
        expect(rig.errors.single, isA<JpRemoteUnavailable>());
        expect(await rig.store.meta(kSyncOwnerMetaKey), 'a',
            reason: 'the record is not B\'s until the upload lands');

        rig.remote('b').online = true;
        await rig.host.resume();

        expect(rig.asked, ['a']);
        expect(rig.remote('b').events, hasLength(2));
        expect(await rig.store.meta(kSyncOwnerMetaKey), 'b');
      });

      test('sign-out never uploads a record the phone did not take', () async {
        final rig = await phoneOfA(null);

        await rig.host.userChanged(_User('b'));
        await rig.host.signOut();

        expect(rig.remotes.containsKey('b'), isFalse);
        expect(await rig.store.meta(kSyncOwnerMetaKey), 'a');
      });
    });
  });

  group('a study store that will not open at sign-out', () {
    test('the phone reports it and signs out, because it wipes nothing',
        () async {
      final rig = Rig(JpStoreMemory(clock: () => t0), isWeb: false);
      await rig.host.userChanged(_User('mark'));
      rig.failOpen = true;

      expect(await rig.host.signOut(), isTrue);
      expect(rig.host.uid, isNull);
      expect(rig.errors.single, isA<StateError>());
    });

    test('the phone signs out with nobody signed in too', () async {
      final rig = Rig(JpStoreMemory(clock: () => t0), isWeb: false)
        ..failOpen = true;

      expect(await rig.host.signOut(), isTrue);
      expect(rig.errors.single, isA<StateError>());
    });

    test('the web reports it and stops sign-out, because it cannot wipe',
        () async {
      final rig = Rig(await webStore());
      await rig.host.userChanged(_User('mark'));
      rig.failOpen = true;

      expect(await rig.host.signOut(), isFalse);
      expect(rig.host.uid, 'mark');
      expect(rig.errors.single, isA<StateError>());
    });

    group('the web asks to sign out anyway (operator ruling c)', () {
      Future<Rig> unopenable() async {
        final rig = Rig(await webStore());
        await rig.host.userChanged(_User('mark'));
        await record(rig.store, answer(2));
        rig.failOpen = true;
        return rig;
      }

      test('"stay signed in" keeps the user signed in', () async {
        final rig = await unopenable();
        var asks = 0;

        final signedOut = await rig.host.signOut(signOutWithoutStore: () async {
          asks++;
          return false;
        });

        expect(signedOut, isFalse);
        expect(asks, 1);
        expect(rig.host.uid, 'mark');
      });

      test(
          '"sign out anyway" signs out and leaves the record for the next '
          'sign-in', () async {
        final rig = await unopenable();

        final signedOut =
            await rig.host.signOut(signOutWithoutStore: () async => true);

        expect(signedOut, isTrue);
        expect(rig.host.uid, isNull);
        rig.failOpen = false;
        // The auth sign-out that follows reports no user: nothing more happens.
        await rig.host.userChanged(null);
        expect(await rig.store.allEvents(), hasLength(1));
        expect(await rig.store.meta(kSyncOwnerMetaKey), 'mark');
      });

      test('another account\'s next sign-in wipes the record left behind',
          () async {
        final rig = await unopenable();
        await rig.host.signOut(signOutWithoutStore: () async => true);
        rig.failOpen = false;
        await rig.host.userChanged(null);

        await rig.host.userChanged(_User('other'));

        expect(await rig.store.allEvents(), isEmpty);
        expect(rig.remote('other').events, isEmpty);
      });

      test('the phone never asks: it signs out because it wipes nothing',
          () async {
        final rig = Rig(JpStoreMemory(clock: () => t0), isWeb: false);
        await rig.host.userChanged(_User('mark'));
        rig.failOpen = true;
        var asks = 0;

        expect(
            await rig.host.signOut(signOutWithoutStore: () async {
              asks++;
              return false;
            }),
            isTrue);
        expect(asks, 0);
      });
    });
  });

  group('a web store with no wipe', () {
    bool isNoWipe(Object e) =>
        e is StateError && e.message == 'jp web wipe: store has no wipe';

    test('sign-out with nobody signed in stops and keeps the jp. keys',
        () async {
      SharedPreferences.setMockInitialValues({'jp.vocab.lastLesson': 4});
      final rig = Rig(_NoWipeStore());

      expect(await rig.host.signOut(), isFalse);
      expect(rig.errors.single, predicate(isNoWipe));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('jp.vocab.lastLesson'), 4);
    });

    test(
        'another account\'s record never syncs, and sign-out stops and keeps the uid',
        () async {
      final rig = Rig(_NoWipeStore(owner: 'other'));

      await rig.host.userChanged(_User('mark'));
      expect(rig.remotes, isEmpty, reason: 'the failed wipe stops the sync');
      expect(rig.host.uid, 'mark');

      expect(await rig.host.signOut(), isFalse);
      expect(rig.host.uid, 'mark',
          reason:
              'the user stays signed in here, so the next resume syncs again');
      expect(rig.errors, hasLength(2));
      expect(rig.errors.every(isNoWipe), isTrue);
    });

    test('the phone never wipes, so a store with no wipe signs out', () async {
      final rig = Rig(_NoWipeStore(), isWeb: false);

      expect(await rig.host.signOut(), isTrue);
      expect(rig.errors, isEmpty);
    });
  });

  group('the dialogs', () {
    testWidgets('the unsynced sign-out dialog: wait or sign out anyway',
        (tester) async {
      bool? result;
      await tester.pumpWidget(MaterialApp(
          home: Builder(
              builder: (context) => TextButton(
                  onPressed: () async =>
                      result = await confirmUnsyncedSignOut(context),
                  child: const Text('go')))));

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text(kUnsyncedTitle), findsOneWidget);
      await tester.tap(find.text(kUnsyncedWait));
      await tester.pumpAndSettle();
      expect(result, isFalse);

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(kUnsyncedSignOutAnyway));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets(
        'the store-unavailable sign-out dialog: stay signed in or sign out '
        'anyway', (tester) async {
      bool? result;
      await tester.pumpWidget(MaterialApp(
          home: Builder(
              builder: (context) => TextButton(
                  onPressed: () async =>
                      result = await confirmStoreUnavailableSignOut(context),
                  child: const Text('go')))));

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text(kNoStoreTitle), findsOneWidget);
      expect(find.text(kNoStoreBody), findsOneWidget);
      await tester.tap(find.text(kNoStoreStay));
      await tester.pumpAndSettle();
      expect(result, isFalse);

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(kUnsyncedSignOutAnyway));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    for (final (label, choice) in [
      (kOwnerKeepLocal, JpOwnerChoice.keepLocal),
      (kOwnerUpload, JpOwnerChoice.upload),
      (kOwnerStartFresh, JpOwnerChoice.startFresh),
    ]) {
      testWidgets('the other-account dialog returns $choice', (tester) async {
        JpOwnerChoice? result;
        await tester.pumpWidget(MaterialApp(
            home: Builder(
                builder: (context) => TextButton(
                    onPressed: () async =>
                        result = await askOwnerChoice(context),
                    child: const Text('go')))));

        await tester.tap(find.text('go'));
        await tester.pumpAndSettle();
        expect(find.text(kOwnerTitle), findsOneWidget);
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();

        expect(result, choice);
      });
    }

    testWidgets(
        'the other-account dialog ignores the back button and names '
        'what "start fresh" loses', (tester) async {
      var closed = false;
      JpOwnerChoice? result;
      await tester.pumpWidget(MaterialApp(
          home: Builder(
              builder: (context) => TextButton(
                  onPressed: () async {
                    result = await askOwnerChoice(context);
                    closed = true;
                  },
                  child: const Text('go')))));

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.textContaining('removes it from this phone'), findsOneWidget);
      expect(find.textContaining('never synced'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(kOwnerTitle), findsOneWidget);
      expect(closed, isFalse);

      await tester.tap(find.text(kOwnerStartFresh));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(result, JpOwnerChoice.startFresh);
    });
  });

  group('jpDeviceName', () {
    test('names the browser and the phone plainly', () {
      expect(jpDeviceName(isWeb: true, platform: TargetPlatform.android),
          'Web browser');
      expect(jpDeviceName(isWeb: false, platform: TargetPlatform.android),
          'Android phone');
      expect(
          jpDeviceName(isWeb: false, platform: TargetPlatform.iOS), 'iPhone');
    });
  });

  group('the profile page entry', () {
    testWidgets('"Signed-in devices" opens the devices page', (tester) async {
      final router = GoRouter(routes: [
        GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: ProfileDevicesEntry())),
        GoRoute(
            name: DevicesPageWidget.routeName,
            path: DevicesPageWidget.routePath,
            builder: (_, __) => const Scaffold(body: Text('devices page'))),
      ]);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text(kDevicesTitle), findsOneWidget);
      await tester.tap(find.text(kDevicesTitle));
      await tester.pumpAndSettle();

      expect(find.text('devices page'), findsOneWidget);
    });
  });
}
