// The sync host and the sign-out wipe (plan 2026-11-19, Task 6, End state 7, D8, PIN-8).
//
// The host runs a sync after a non-anonymous sign-in and on app resume, and never for an
// anonymous or signed-out user. On the web, sign-out (and losing the user, as account delete
// does) empties this browser's study record through the store wipe, which also clears the sync
// cursor and the replay flag. A browser record that belongs to another account is wiped before
// it can reach the new account. The phone never wipes. The profile page's "Signed-in devices"
// entry opens the devices page.
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
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_remote.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_memory.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_web.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_sync.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_sync_host_service.dart';

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

Future<void> record(JpStore store, Attempt a) => store.recordAnswer(a,
    item: lookup(a.itemId), scheduler: scheduler);

/// One browser (or phone) under test: its store, the remote of each account, and its host.
class Rig {
  Rig(this.store, {this.isWeb = true, this.failures = const []}) {
    host = JpSyncHost(
      openStore: () async => store,
      remoteFor: (uid) => remotes.putIfAbsent(uid, JpRemoteMemory.new),
      loadLookup: () async => lookup,
      isWeb: isWeb,
      deviceName: isWeb ? 'Web browser' : 'Android phone',
      clock: () => t0.add(const Duration(hours: 1)),
      onError: (e, _) => errors.add(e),
    );
  }

  final JpStore store;
  final bool isWeb;
  final List<Object> failures;
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
    test('a non-anonymous sign-in syncs: the answer reaches the remote', () async {
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

    test('app resume syncs again and pulls the other device\'s answer', () async {
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

    test('an offline sync is reported, not thrown, and the next resume catches up',
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
    test('wipes the store, its sync cursor and its replay flag, and keeps the device id',
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

      await rig.host.signOut();

      expect(rig.remote('mark').events, hasLength(1));
      expect(await rig.store.allEvents(), isEmpty);
    });

    test('losing the user from the auth stream (account delete) wipes too',
        () async {
      final rig = Rig(await webStore());
      await record(rig.store, answer(0));
      await rig.host.userChanged(_User('mark'));

      await rig.host.userChanged(null);

      expect(await rig.store.allEvents(), isEmpty);
      expect(await rig.store.meta(kSyncCursorMetaKey), isNull);
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

    test('a record another account left in this browser never reaches the next account',
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

    test('a record owned by another account stays and does not sync', () async {
      final rig = Rig(JpStoreMemory(clock: () => t0), isWeb: false);
      await rig.store.putMeta(kSyncOwnerMetaKey, 'a');
      await record(rig.store, answer(0));

      await rig.host.userChanged(_User('b'));

      expect(rig.remote('b').events, isEmpty);
      expect(await rig.store.allEvents(), hasLength(1));
      expect(await rig.store.meta(kSyncOwnerMetaKey), 'a');
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
