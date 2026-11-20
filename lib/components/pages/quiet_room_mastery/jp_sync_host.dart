// HAND-WRITTEN. Not FlutterFlow output, so S3 has nothing to adopt.
//
// The sync host (plan 2026-11-19, Task 6, D8, PIN-8, End state 7): it decides when the study
// record syncs and when this browser forgets it.
//
//   * A non-anonymous sign-in runs one sync (`JpSync.run`, jp_sync.dart). So does each app
//     resume while that user stays signed in. An anonymous user, or nobody, never syncs: the
//     host opens no remote for them.
//   * The same user reported again (a token refresh) starts nothing new.
//   * Sign-out from the profile page ([JpSyncHost.signOut]) first runs a last sync, so the
//     answers this device has not pushed yet reach the account, then on the web wipes the
//     store. Losing the user from the auth stream (account delete) wipes on the web too, with
//     no last sync. The wipe is the store's own (`JpStoreWeb.wipe`), which also clears the sync
//     cursor and the replay flag, so the next sign-in pulls the whole record. It keeps the
//     device id and the migration flags. The host also removes the browser's `jp.`
//     SharedPreferences keys, so no study data of the last account stays in this browser.
//   * The store keeps the uid it syncs for ([kSyncOwnerMetaKey]). On the web, a record another
//     account left behind (a tab closed before sign-out) is wiped before the first sync, so it
//     never reaches the next account. The phone never wipes: a record owned by another account
//     stays on the phone and does not sync. A record with no owner yet (the phone's history
//     before sync) is claimed by the first signed-in account.
//
// Every step runs one at a time, in the order called, so a wipe never races a sync. A failed
// sync (offline, the rules refused) is reported to [JpSyncHost.onError] and never thrown: the
// phone keeps working offline (PIN-9), and the next sign-in or resume tries again.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/auth/base_auth_user_provider.dart';
import 'drill_recorder.dart' show catalogLookup;
import 'fsrs.dart';
import 'jp_remote.dart';
import 'jp_remote_firestore.dart';
import 'jp_store.dart';
import 'jp_store_memory.dart';
import 'jp_store_sqlite.dart' show sharedJpStore;
import 'jp_sync.dart';
import 'scheduler.dart';

/// The store flag that holds the uid whose record the store syncs. The web wipe clears it.
const String kSyncOwnerMetaKey = 'sync.owner';

/// The prefix of the browser's SharedPreferences study keys the web wipe removes.
const String kJpPrefsPrefix = 'jp.';

/// The plain name the devices page shows for this device.
String jpDeviceName({bool isWeb = kIsWeb, TargetPlatform? platform}) {
  if (isWeb) return 'Web browser';
  return switch (platform ?? defaultTargetPlatform) {
    TargetPlatform.android => 'Android phone',
    TargetPlatform.iOS => 'iPhone',
    _ => 'This device',
  };
}

/// Removes every SharedPreferences key that starts with [kJpPrefsPrefix].
Future<void> clearJpPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  for (final key in prefs.getKeys().toList()) {
    if (key.startsWith(kJpPrefsPrefix)) await prefs.remove(key);
  }
}

JpRemote _firestoreRemote(String uid) =>
    JpRemoteFirestore(firestore: FirebaseFirestore.instance, uid: uid);

void _debugReport(Object error, StackTrace stack) =>
    debugPrint('jp sync: $error');

class JpSyncHost with WidgetsBindingObserver {
  JpSyncHost({
    Future<JpStore> Function()? openStore,
    JpRemote Function(String uid)? remoteFor,
    Future<ItemLookup> Function()? loadLookup,
    this.scheduler = const FsrsScheduler(),
    bool? isWeb,
    String? deviceName,
    DateTime Function()? clock,
    void Function(Object error, StackTrace stack)? onError,
    Future<void> Function()? clearPrefs,
  })  : _openStore = openStore ?? sharedJpStore,
        _remoteFor = remoteFor ?? _firestoreRemote,
        _loadLookup = loadLookup ?? catalogLookup,
        isWeb = isWeb ?? kIsWeb,
        deviceName = deviceName ?? jpDeviceName(isWeb: isWeb ?? kIsWeb),
        _clock = clock,
        onError = onError ?? _debugReport,
        _clearPrefs = clearPrefs ?? clearJpPrefs;

  /// The app's host. main.dart feeds it the auth stream and app resumes; the profile page
  /// calls its [signOut].
  static final JpSyncHost instance = JpSyncHost();

  final Future<JpStore> Function() _openStore;
  final JpRemote Function(String uid) _remoteFor;
  final Future<ItemLookup> Function() _loadLookup;
  final Scheduler scheduler;

  /// Whether this is the web build: only the web wipes on sign-out.
  final bool isWeb;
  final String deviceName;
  final DateTime Function()? _clock;

  /// Where a failed step goes. The host never throws one.
  final void Function(Object error, StackTrace stack) onError;
  final Future<void> Function() _clearPrefs;

  /// The signed-in, non-anonymous uid; null when nobody is, or the user is anonymous.
  String? _uid;

  /// The tail of the step chain.
  Future<void> _tail = Future.value();

  /// The uid the host syncs for now.
  String? get uid => _uid;

  /// Starts listening for app resumes.
  void attach() => WidgetsBinding.instance.addObserver(this);

  /// Stops listening for app resumes.
  void detach() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) resume();
  }

  /// The auth stream's latest user. A new non-anonymous user syncs. Losing a signed-in user
  /// wipes the web store. Returns when the steps it queued finish.
  Future<void> userChanged(BaseAuthUser? user) {
    final id = user?.uid;
    final next =
        user != null && user.loggedIn && id != null && id.isNotEmpty ? id : null;
    if (next == _uid) return _tail;
    final previous = _uid;
    _uid = next;
    return _step(() async {
      if (previous != null && isWeb) await _wipe(await _openStore());
      if (next != null) await _sync(next);
    });
  }

  /// An app resume: syncs when a non-anonymous user is signed in.
  Future<void> resume() {
    final id = _uid;
    if (id == null) return _tail;
    return _step(() => _sync(id));
  }

  /// Sign-out, called before the auth sign-out: a last sync pushes what this device has not,
  /// then the web store is wiped. A failed last sync does not stop the wipe.
  Future<void> signOut() {
    final id = _uid;
    _uid = null;
    return _step(() async {
      if (id != null) {
        try {
          await _run(id, await _openStore());
        } catch (e, s) {
          onError(e, s);
        }
      }
      if (isWeb) await _wipe(await _openStore());
    });
  }

  Future<void> _step(Future<void> Function() step) {
    final run = _tail.then((_) => step()).catchError(onError);
    _tail = run;
    return run;
  }

  /// One sync for [id], unless the user changed while it waited its turn.
  Future<void> _sync(String id) async {
    if (_uid != id) return;
    final store = await _openStore();
    final owner = await store.meta(kSyncOwnerMetaKey);
    if (owner != null && owner.isNotEmpty && owner != id) {
      // Another account's record. The phone keeps it and does not sync it.
      if (!isWeb) return;
      await _wipe(store);
    }
    await _run(id, store);
  }

  Future<void> _run(String id, JpStore store) async {
    if (await store.meta(kSyncOwnerMetaKey) != id) {
      await store.putMeta(kSyncOwnerMetaKey, id);
    }
    await JpSync(
      store: store,
      remote: _remoteFor(id),
      lookup: await _loadLookup(),
      scheduler: scheduler,
      deviceName: deviceName,
      clock: _clock,
    ).run();
  }

  /// The web wipe: the store's own wipe, then the browser's `jp.` keys.
  Future<void> _wipe(JpStore store) async {
    if (store is JpStoreMemory) await store.wipe();
    await _clearPrefs();
  }
}
