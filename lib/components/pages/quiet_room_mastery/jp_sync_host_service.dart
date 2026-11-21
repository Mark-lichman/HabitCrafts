// HAND-WRITTEN. Not FlutterFlow output, so S3 has nothing to adopt.
//
// The file name must not end in `host.dart`. The plan names it `jp_sync_host.dart`, but the
// Flutter web test server serves its own test runner for any URL that contains
// `host.dart.js` (flutter_tools `flutter_web_platform.dart`). A library compiled to
// `jp_sync_host.dart.js` then never loads, and every Chrome test that reaches it hangs.
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
//     store. If that last sync fails and answers are still unpushed, sign-out stops and asks
//     the user to wait or sign out anyway (operator ruling a, Checkpoint 2026-11-20). Nothing
//     is wiped without "sign out anyway". Losing the user from the auth stream (account
//     delete) wipes on the web with no last sync: the account's record is gone anyway. The
//     wipe is the store's own (`JpStoreWeb.wipe`), which also clears the sync cursor and the
//     replay flag, so the next sign-in pulls the whole record. It keeps the device id and the
//     migration flags. The host also removes the browser's `jp.` SharedPreferences keys, so
//     no study data of the last account stays in this browser.
//   * The store keeps the uid it syncs for ([kSyncOwnerMetaKey]). On the web, a record another
//     account left behind (a tab closed before sign-out) is wiped before the first sync, so it
//     never reaches the next account. A record with no owner yet (the phone's history before
//     sync) is claimed by the first signed-in account.
//   * The phone never wipes on sign-out. If another account signs in over a record with a
//     different owner (a deleted owner looks the same: its uid never signs in again), the
//     phone asks once ([JpSyncHost.askOwner], operator ruling b): keep the record local,
//     upload it to the new account, or start fresh. Then the new account syncs.
//       - keep local: the whole record stays on the phone as a study export under
//         [kKeptRecordMetaPrefix] plus the old owner's uid, and is never sent. The working
//         record empties, so the new account's record replays alone. The export stays in the
//         store under that key. No screen reads it yet.
//       - upload: every event goes to the new account, the ones the old owner already holds
//         too, then the record is the new account's. The sync cursor (the old owner's server
//         time) is cleared, so the first pull reads the new account's whole record.
//       - start fresh: the working record empties, then the new account's record is pulled.
//     The pick holds for the session, so a resume never asks again. The record becomes the new
//     account's only once the pick's work is done, so a pick the network cut short finishes on
//     the next resume. No answer (the dialog never shown) changes nothing and syncs nothing
//     until the next sign-in.
//
// Every step runs one at a time, in the order called, so a wipe never races a sync. A failed
// sync (offline, the rules refused) is reported to [JpSyncHost.onError] and never thrown: the
// phone keeps working offline (PIN-9), and the next sign-in or resume tries again.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import 'study_export.dart' show encodeStudyExport;

/// The store flag that holds the uid whose record the store syncs. The web wipe clears it.
const String kSyncOwnerMetaKey = 'sync.owner';

/// The store flag prefix of a record kept on the phone ("keep local"): the prefix plus the old
/// owner's uid holds that record as a study export (study_export.dart).
const String kKeptRecordMetaPrefix = 'sync.kept.';

/// The prefix of the browser's SharedPreferences study keys the web wipe removes.
const String kJpPrefsPrefix = 'jp.';

/// What the phone does with a record another account owns (operator ruling b).
enum JpOwnerChoice { keepLocal, upload, startFresh }

/// The unsynced sign-out dialog (operator ruling a).
const String kUnsyncedTitle = 'Some answers are not synced yet';
const String kUnsyncedBody =
    'This browser could not reach your account. If you sign out now, the answers it has not '
    'synced are lost.';
const String kUnsyncedWait = 'Wait';
const String kUnsyncedSignOutAnyway = 'Sign out anyway';

/// The other-account dialog (operator ruling b).
const String kOwnerTitle = 'This phone has another account\'s study record';
const String kOwnerBody =
    'The study record on this phone belongs to another account. Choose what to do with it. '
    'Start fresh removes it from this phone, and any answers it never synced to the other '
    'account are lost.';
const String kOwnerKeepLocal = 'Keep it on this phone';
const String kOwnerUpload = 'Upload it to this account';
const String kOwnerStartFresh = 'Start fresh';

/// Asks whether to sign out with answers still unsynced. True means "sign out anyway".
Future<bool> confirmUnsyncedSignOut(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text(kUnsyncedTitle),
        content: const Text(kUnsyncedBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(kUnsyncedWait)),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(kUnsyncedSignOutAnyway)),
        ],
      ),
    ) ??
    false;

/// Asks what to do with a record another account owns.
Future<JpOwnerChoice?> askOwnerChoice(BuildContext context) =>
    showDialog<JpOwnerChoice>(
      context: context,
      barrierDismissible: false,
      // The system back button would pop with null, which skips sync for the whole session
      // and tells the user nothing, so only a pick closes this dialog. The unsynced dialog
      // needs no such guard: its null answer maps to "Wait", the safe choice.
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text(kOwnerTitle),
          content: const Text(kOwnerBody),
          actions: [
            for (final (label, choice) in const [
              (kOwnerKeepLocal, JpOwnerChoice.keepLocal),
              (kOwnerUpload, JpOwnerChoice.upload),
              (kOwnerStartFresh, JpOwnerChoice.startFresh),
            ])
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, choice),
                  child: Text(label)),
          ],
        ),
      ),
    );

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
    this.askOwner,
  })  : _openStore = openStore ?? sharedJpStore,
        _remoteFor = remoteFor ?? _firestoreRemote,
        _loadLookup = loadLookup ?? catalogLookup,
        isWeb = isWeb ?? kIsWeb,
        deviceName = deviceName ?? jpDeviceName(isWeb: isWeb ?? kIsWeb),
        _clock = clock,
        onError = onError ?? _debugReport,
        _clearPrefs = clearPrefs ?? clearJpPrefs;

  /// The app's host. main.dart feeds it the auth stream and app resumes and sets its
  /// [askOwner]; the profile page calls its [signOut].
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

  /// Asks the phone's user what to do with a record the old owner (the argument) holds. Null,
  /// or a null answer, means no pick: nothing changes and nothing syncs.
  Future<JpOwnerChoice?> Function(String previousOwner)? askOwner;

  /// The signed-in, non-anonymous uid; null when nobody is, or the user is anonymous.
  String? _uid;

  /// The pick made for the signed-in uid this session; null for none yet.
  JpOwnerChoice? _choice;

  /// Whether the signed-in uid was asked this session and gave no pick.
  bool _declined = false;

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
    _setUid(next);
    return _step(() async {
      if (previous != null && isWeb) await _wipe(await _openStore());
      if (next != null) await _sync(next, ask: true);
    });
  }

  /// An app resume: syncs when a non-anonymous user is signed in.
  Future<void> resume() {
    final id = _uid;
    if (id == null) return _tail;
    return _step(() => _sync(id, ask: false));
  }

  /// Sign-out, called before the auth sign-out: a last sync pushes what this device has not,
  /// then the web store is wiped. Returns whether the caller may sign out.
  ///
  /// On the web, a failed last sync that leaves answers unpushed calls [signOutAnyway]
  /// (operator ruling a). False, or no [signOutAnyway], stops sign-out: nothing is wiped and
  /// the user stays signed in here, so the next resume syncs again. The phone wipes nothing,
  /// so a failed last sync never stops it. A store that will not open is reported: the phone
  /// signs out anyway, and the web stops sign-out because it cannot wipe.
  Future<bool> signOut({Future<bool> Function()? signOutAnyway}) {
    final id = _uid;
    final result = Completer<bool>();
    _step(() async {
      try {
        final JpStore store;
        try {
          store = await _openStore();
        } catch (e, s) {
          onError(e, s);
          if (!isWeb) {
            if (_uid == id) _setUid(null);
            result.complete(true);
          }
          return;
        }
        // The last sync runs unless another account owns the record. A record with no owner
        // yet (a sign-in sync that failed before it claimed the record) is claimable, as in
        // [_sync], so its unpushed answers still get the ruling (a) ask.
        if (id != null && _claimable(await store.meta(kSyncOwnerMetaKey), id)) {
          try {
            await _run(id, store);
          } catch (e, s) {
            onError(e, s);
            if (isWeb && (await store.unpushedEvents()).isNotEmpty) {
              final anyway = signOutAnyway != null && await signOutAnyway();
              if (!anyway) {
                result.complete(false);
                return;
              }
            }
          }
        }
        if (_uid == id) _setUid(null);
        if (isWeb) await _wipe(store);
        result.complete(true);
      } finally {
        if (!result.isCompleted) result.complete(false);
      }
    });
    return result.future;
  }

  /// Whether [id] may sync a record whose store owner is [owner]: no owner yet, or [id] itself.
  static bool _claimable(String? owner, String id) =>
      owner == null || owner.isEmpty || owner == id;

  void _setUid(String? id) {
    _uid = id;
    _choice = null;
    _declined = false;
  }

  Future<void> _step(Future<void> Function() step) {
    final run = _tail.then((_) => step()).catchError(onError);
    _tail = run;
    return run;
  }

  /// One sync for [id], unless the user changed while it waited its turn. [ask] is true on a
  /// sign-in, the one time the phone may ask about another account's record.
  Future<void> _sync(String id, {required bool ask}) async {
    if (_uid != id) return;
    final store = await _openStore();
    final owner = await store.meta(kSyncOwnerMetaKey);
    if (owner != null && !_claimable(owner, id)) {
      if (isWeb) {
        await _wipe(store);
      } else if (!await _takeOver(id, owner, store, ask: ask)) {
        return;
      }
    }
    await _run(id, store);
  }

  /// The phone's pick for a record [owner] holds, now signed in as [id]. Returns whether the
  /// record is now [id]'s and may sync.
  Future<bool> _takeOver(String id, String owner, JpStore store,
      {required bool ask}) async {
    var choice = _choice;
    if (choice == null) {
      if (_declined || !ask || askOwner == null) return false;
      choice = await askOwner!(owner);
      if (_uid != id) return false;
      if (choice == null) {
        _declined = true;
        return false;
      }
      _choice = choice;
    }
    switch (choice) {
      case JpOwnerChoice.upload:
        await _remoteFor(id).pushEvents(await store.allEvents());
        // The cursor is the old owner's server time: the new account's pull starts over.
        await store.putMeta(kSyncCursorMetaKey, '');
      case JpOwnerChoice.keepLocal:
        final kept = encodeStudyExport(await store.exportLog(),
            exportedAt: (_clock ?? DateTime.now)().toUtc());
        await store.putMeta(kKeptRecordMetaPrefix + owner, kept);
        await _empty(store);
      case JpOwnerChoice.startFresh:
        await _empty(store);
    }
    await store.putMeta(kSyncOwnerMetaKey, id);
    return true;
  }

  /// Empties the phone's working record through the store's import: the log, the side
  /// events and the derived states go, and the sync cursor with them. The replay flag is
  /// cleared too, so the next sync pulls the whole record and replays only what it pulls.
  Future<void> _empty(JpStore store) async {
    await store.importLog(const StudyLog(), await _loadLookup(), scheduler);
    await store.putMeta(kSyncReplayPendingMetaKey, '0');
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
