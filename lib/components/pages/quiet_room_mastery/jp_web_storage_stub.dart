// Off the web there is no browser storage: the phone keeps its record in SQLite
// (jp_store_sqlite.dart), and tests pass a `MemoryJpWebStorage`.

import 'jp_web_storage.dart';

/// Throws off the web.
JpWebStorage browserJpWebStorage() =>
    throw UnsupportedError('jp web storage: IndexedDB exists only on the web');
