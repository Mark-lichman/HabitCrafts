// The web study store's snapshot in IndexedDB: database [kJpWebDbName], object store
// [kJpWebObjectStore], one value under [kJpWebSnapshotKey].
//
// A write waits for its transaction to complete, so a resolved write is on disk, and a failed
// one (a full quota, an abort) leaves the old value. No dependency is added for this.
// `package:web` is only a transitive dependency of the Firebase plugins, so the few IndexedDB
// interfaces needed are declared below with `dart:js_interop`, which ships with the SDK, the
// same way mic_level_web.dart declares its Web Audio ones.

import 'dart:async';
import 'dart:js_interop';

import 'jp_web_storage.dart';

const String kJpWebDbName = 'habitcrafts_jp_study';
const String kJpWebObjectStore = 'snapshot';
const String kJpWebSnapshotKey = 'record';

@JS('indexedDB')
external _IdbFactory? get _indexedDB;

extension type _IdbFactory._(JSObject _) implements JSObject {
  external _IdbOpenRequest open(String name, int version);
}

extension type _IdbRequest._(JSObject _) implements JSObject {
  external JSAny? get result;
  external JSAny? get error;
  external set onsuccess(JSFunction? f);
  external set onerror(JSFunction? f);
}

extension type _IdbOpenRequest._(JSObject _) implements _IdbRequest {
  external set onupgradeneeded(JSFunction? f);
}

extension type _IdbDatabase._(JSObject _) implements JSObject {
  external JSObject createObjectStore(String name);
  external _IdbTransaction transaction(String storeName, String mode);
}

extension type _IdbTransaction._(JSObject _) implements JSObject {
  external _IdbObjectStore objectStore(String name);
  external JSAny? get error;
  external set oncomplete(JSFunction? f);
  external set onerror(JSFunction? f);
  external set onabort(JSFunction? f);
}

extension type _IdbObjectStore._(JSObject _) implements JSObject {
  @JS('get')
  external _IdbRequest getValue(JSAny key);
  external _IdbRequest put(JSAny value, JSAny key);
  external _IdbRequest delete(JSAny key);
}

/// The browser's IndexedDB as a [JpWebStorage].
JpWebStorage browserJpWebStorage() => _IdbStorage();

class _IdbStorage implements JpWebStorage {
  Future<_IdbDatabase>? _db;

  /// Opens the database once. A failed open is not kept, so the next call tries again.
  Future<_IdbDatabase> _open() => _db ??= () {
        final factory = _indexedDB;
        if (factory == null) {
          throw UnsupportedError('jp web storage: this browser has no IndexedDB');
        }
        final done = Completer<_IdbDatabase>();
        final req = factory.open(kJpWebDbName, 1);
        req.onupgradeneeded = ((JSAny _) {
          (req.result as _IdbDatabase).createObjectStore(kJpWebObjectStore);
        }).toJS;
        req.onsuccess =
            ((JSAny _) => done.complete(req.result as _IdbDatabase)).toJS;
        req.onerror = ((JSAny _) => done.completeError(
            StateError('jp web storage: open failed: ${req.error}'))).toJS;
        return done.future;
      }()
          .catchError((Object e) {
        _db = null;
        throw e;
      });

  /// Runs [body] in a [mode] transaction and waits for it to complete.
  Future<void> _run(
      String mode, void Function(_IdbObjectStore store) body) async {
    final db = await _open();
    final tx = db.transaction(kJpWebObjectStore, mode);
    final done = Completer<void>();
    tx.oncomplete = ((JSAny _) => done.complete()).toJS;
    tx.onerror = ((JSAny _) {
      if (!done.isCompleted) {
        done.completeError(StateError('jp web storage: ${tx.error}'));
      }
    }).toJS;
    tx.onabort = ((JSAny _) {
      if (!done.isCompleted) {
        done.completeError(StateError('jp web storage: aborted: ${tx.error}'));
      }
    }).toJS;
    body(tx.objectStore(kJpWebObjectStore));
    return done.future;
  }

  @override
  Future<String?> read() async {
    late _IdbRequest req;
    await _run('readonly',
        (store) => req = store.getValue(kJpWebSnapshotKey.toJS));
    final value = req.result.dartify();
    return value is String ? value : null;
  }

  @override
  Future<void> write(String snapshot) => _run('readwrite',
      (store) => store.put(snapshot.toJS, kJpWebSnapshotKey.toJS));

  @override
  Future<void> clear() =>
      _run('readwrite', (store) => store.delete(kJpWebSnapshotKey.toJS));
}
