// Where the web study store (jp_store_web.dart) keeps its snapshot between loads: one string.
//
// [browserJpWebStorage] is IndexedDB in the browser (jp_web_storage_idb.dart). Conditional
// export rather than a `kIsWeb` branch, because `dart:js_interop` does not exist off the web
// and would fail to compile; off the web it throws (jp_web_storage_stub.dart). Tests pass a
// [MemoryJpWebStorage], and a second open over the same one is a reload or a second tab.
//
// [JpWebStorage.exclusive] is the lock across tabs. In the browser it is the Web Locks API
// (`navigator.locks`), which every open tab of one site shares.

export 'jp_web_storage_stub.dart'
    if (dart.library.js_interop) 'jp_web_storage_idb.dart'
    show browserJpWebStorage;

/// One saved string that outlives the page.
abstract class JpWebStorage {
  /// The saved snapshot, or null when nothing is saved.
  Future<String?> read();

  /// Replaces the saved snapshot with [snapshot] in one step: a failed write keeps the old one.
  Future<void> write(String snapshot);

  /// Forgets the saved snapshot.
  Future<void> clear();

  /// Runs [body] while no other holder of this storage runs one: every open tab of the site
  /// in the browser, every store over the same object in tests. The web store reads, changes
  /// and saves the snapshot inside it, so two tabs never save over each other.
  Future<T> exclusive<T>(Future<T> Function() body);
}

/// A [JpWebStorage] in memory: the browser stand-in for tests. Two stores over one object are
/// two tabs over one browser storage.
class MemoryJpWebStorage implements JpWebStorage {
  /// The saved snapshot; null when nothing is saved.
  String? snapshot;

  /// The tail of the [exclusive] chain.
  Future<void> _tail = Future.value();

  @override
  Future<String?> read() async => snapshot;

  @override
  Future<void> write(String snapshot) async => this.snapshot = snapshot;

  @override
  Future<void> clear() async => snapshot = null;

  @override
  Future<T> exclusive<T>(Future<T> Function() body) {
    final run = _tail.then((_) => body());
    _tail = run.then((_) {}, onError: (Object _) {});
    return run;
  }
}
