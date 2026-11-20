// Where the web study store (jp_store_web.dart) keeps its snapshot between loads: one string.
//
// [browserJpWebStorage] is IndexedDB in the browser (jp_web_storage_idb.dart). Conditional
// export rather than a `kIsWeb` branch, because `dart:js_interop` does not exist off the web
// and would fail to compile; off the web it throws (jp_web_storage_stub.dart). Tests pass a
// [MemoryJpWebStorage], and a second open over the same one is a reload.

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
}

/// A [JpWebStorage] in memory: the browser stand-in for tests.
class MemoryJpWebStorage implements JpWebStorage {
  /// The saved snapshot; null when nothing is saved.
  String? snapshot;

  @override
  Future<String?> read() async => snapshot;

  @override
  Future<void> write(String snapshot) async => this.snapshot = snapshot;

  @override
  Future<void> clear() async => snapshot = null;
}
