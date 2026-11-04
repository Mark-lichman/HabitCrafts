// The study store on the phone: SQLite through `sqflite` (D14). Tests open it through the ffi
// factory of `sqflite_common_ffi` (A5), so the same suite runs here and on `JpStoreMemory`.
//
// Tables (schema version 1):
//   attempts  the append-only answer log: one row per attempt, its JSON plus indexed columns
//   seeds     the append-only seed events (D26): item, due day, time; never an attempt
//   items     per item: the earliest seeded due day and a note
//   srs       per item: the FSRS state, its due day in a column for the due query
//   mastery   per item: the mastery state
//   days      per local day: the plan JSON, the position and whether it is done
//   meta      store-level flags, such as the one-time v2 migration
// Indexes on `srs.dueDay` and `attempts.itemId`. `attempts`, `seeds` and `items.note` are the
// record; `srs`, `mastery` and `items.seedDueDay` are rebuilt from it (JpStore.rebuild).
//
// One transaction per answer: `appendAttempt` writes the attempt, the schedule and the mastery
// state together. A later schema adds a step to [_upgrades]; `onUpgrade` runs the steps after
// the file's version, in order.

import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common/sqlite_api.dart';

import 'attempt.dart';
import 'jp_store.dart';
import 'jp_store_memory.dart';
import 'mastery_rule.dart';
import 'scheduler.dart';

/// The schema version this build writes.
const int kJpStoreSchemaVersion = 1;

/// The database file's name in the app's databases directory.
const String kJpStoreFileName = 'jp_study.db';

/// The schema steps after version 1, keyed by the version they produce. Empty at version 1.
final Map<int, Future<void> Function(Database db)> _upgrades = {};

Future<void> _createV1(Database db) async {
  final batch = db.batch()
    ..execute('CREATE TABLE attempts ('
        'id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'itemId TEXT NOT NULL, '
        'atUtc TEXT NOT NULL, '
        'localDay INTEGER NOT NULL, '
        'json TEXT NOT NULL)')
    ..execute('CREATE INDEX attempts_itemId ON attempts (itemId)')
    ..execute('CREATE TABLE seeds ('
        'id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'itemId TEXT NOT NULL, '
        'dueDay INTEGER NOT NULL, '
        'atUtc TEXT NOT NULL)')
    ..execute('CREATE TABLE items ('
        'itemId TEXT PRIMARY KEY, '
        'seedDueDay INTEGER, '
        'note TEXT)')
    ..execute('CREATE TABLE srs ('
        'itemId TEXT PRIMARY KEY, '
        'dueDay INTEGER NOT NULL, '
        'json TEXT NOT NULL)')
    ..execute('CREATE INDEX srs_dueDay ON srs (dueDay)')
    ..execute('CREATE TABLE mastery ('
        'itemId TEXT PRIMARY KEY, '
        'status TEXT NOT NULL, '
        'json TEXT NOT NULL)')
    ..execute('CREATE TABLE days ('
        'day INTEGER PRIMARY KEY, '
        'plan TEXT NOT NULL, '
        'position INTEGER NOT NULL, '
        'completed INTEGER NOT NULL)')
    ..execute('CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
  await batch.commit(noResult: true);
}

/// Opens the platform's store: SQLite on the phone, memory on web (A4).
///
/// Each call opens a new store. The app opens one per run and shares it; two stores on web
/// do not see each other, and two on the phone do not serialize answers.
Future<JpStore> openJpStore({bool isWeb = kIsWeb}) async {
  if (isWeb) return JpStoreMemory();
  return JpStoreSqlite.open();
}

Future<JpStore>? _shared;

/// The app's one store, opened on first use and shared by every screen that writes an
/// answer, so their answers run on one write chain. A failed open is not cached: the next
/// call tries again.
Future<JpStore> sharedJpStore() => _shared ??= openJpStore().then(
      (store) => store,
      onError: (Object e, StackTrace s) {
        _shared = null;
        Error.throwWithStackTrace(e, s);
      },
    );

/// Replaces the shared store, for widget tests that cannot open SQLite. Null forgets it.
@visibleForTesting
void debugSetSharedJpStore(JpStore? store) =>
    _shared = store == null ? null : Future.value(store);

/// Runs the steps in [upgrades] that take a file at [from] to [to], in order. Throws a
/// [StateError], inside the open's transaction, when a step is missing.
Future<void> _upgrade(Database db, int from, int to,
    Map<int, Future<void> Function(Database db)> upgrades) async {
  for (var v = from + 1; v <= to; v++) {
    final step = upgrades[v];
    if (step == null) {
      throw StateError('jp store: no upgrade step to version $v');
    }
    await step(db);
  }
}

class JpStoreSqlite extends JpStore {
  JpStoreSqlite._(this._db);

  final Database _db;

  /// Opens (creating or upgrading) the store at [path], by default [kJpStoreFileName] in the
  /// app's databases directory, through [factory], by default sqflite's platform factory.
  ///
  /// [version] and [upgrades] are test seams: the build always opens at
  /// [kJpStoreSchemaVersion] with the registered steps.
  static Future<JpStoreSqlite> open({
    DatabaseFactory? factory,
    String? path,
    int version = kJpStoreSchemaVersion,
    Map<int, Future<void> Function(Database db)>? upgrades,
  }) async {
    final f = factory ?? sqflite.databaseFactory;
    final p = path ?? '${await f.getDatabasesPath()}/$kJpStoreFileName';
    final steps = upgrades ?? _upgrades;
    final db = await f.openDatabase(
      p,
      options: OpenDatabaseOptions(
        version: version,
        // An in-memory path must not hand back an earlier store's database.
        singleInstance: p != inMemoryDatabasePath,
        onCreate: (db, version) async {
          await _createV1(db);
          await _upgrade(db, 1, version, steps);
        },
        onUpgrade: (db, from, to) => _upgrade(db, from, to, steps),
      ),
    );
    return JpStoreSqlite._(db);
  }

  /// The schema version of the open file.
  Future<int> schemaVersion() => _db.getVersion();

  // --- the log ---------------------------------------------------------------

  @override
  Future<Attempt> appendAttempt(Attempt attempt,
      {SrsState? srs, MasteryState? mastery}) async {
    checkAnswerStates(attempt, mastery);
    return _db.transaction((txn) async {
      final id = await _insertAttempt(txn, attempt);
      if (srs != null) await _putSrs(txn, attempt.itemId, srs);
      if (mastery != null) await _putMastery(txn, mastery);
      return attemptWithId(attempt, id);
    });
  }

  Future<int> _insertAttempt(DatabaseExecutor db, Attempt attempt) {
    final json = attempt.toJson()..remove('id');
    return db.insert('attempts', {
      'itemId': attempt.itemId,
      'atUtc': attempt.atUtc.toUtc().toIso8601String(),
      'localDay': attempt.localDay,
      'json': jsonEncode(json),
    });
  }

  /// The item's row, created empty when missing. Plain SQL, no upsert: the platform SQLite on
  /// older Android predates `ON CONFLICT ... DO UPDATE` (3.24).
  Future<void> _ensureItem(DatabaseExecutor db, String itemId) =>
      db.insert('items', {'itemId': itemId},
          conflictAlgorithm: ConflictAlgorithm.ignore);

  Future<void> _insertSeed(DatabaseExecutor db, SeedEvent seed) async {
    await db.insert('seeds', {
      'itemId': seed.itemId,
      'dueDay': seed.dueDay,
      'atUtc': seed.atUtc.toUtc().toIso8601String(),
    });
    // The earliest seeded due day wins.
    await _ensureItem(db, seed.itemId);
    await db.rawUpdate(
        'UPDATE items SET seedDueDay = ? WHERE itemId = ? '
        'AND (seedDueDay IS NULL OR seedDueDay > ?)',
        [seed.dueDay, seed.itemId, seed.dueDay]);
  }

  @override
  Future<void> appendSeeds(Iterable<SeedEvent> seeds) =>
      _db.transaction((txn) async {
        for (final s in seeds) {
          await _insertSeed(txn, s);
        }
      });

  @override
  Future<List<Attempt>> attempts({String? itemId}) async {
    final rows = await _db.query('attempts',
        columns: ['id', 'json'],
        where: itemId == null ? null : 'itemId = ?',
        whereArgs: itemId == null ? null : [itemId],
        orderBy: 'id');
    return [
      for (final r in rows)
        Attempt.fromJson({
          ...jsonDecode(r['json'] as String) as Map<String, dynamic>,
          'id': r['id'] as int,
        })
    ];
  }

  @override
  Future<List<SeedEvent>> seeds() async {
    final rows = await _db.query('seeds', orderBy: 'id');
    return [
      for (final r in rows)
        SeedEvent(
          id: r['id'] as int,
          itemId: r['itemId'] as String,
          dueDay: r['dueDay'] as int,
          atUtc: DateTime.parse(r['atUtc'] as String).toUtc(),
        )
    ];
  }

  // --- the derived states ----------------------------------------------------

  Future<void> _putSrs(DatabaseExecutor db, String itemId, SrsState s) =>
      db.insert(
          'srs',
          {
            'itemId': itemId,
            'dueDay': s.dueDay,
            'json': jsonEncode(s.toJson()),
          },
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> _putMastery(DatabaseExecutor db, MasteryState m) => db.insert(
      'mastery',
      {
        'itemId': m.itemId,
        'status': m.status.name,
        'json': jsonEncode(m.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<SrsState?> srs(String itemId) async {
    final rows = await _db.query('srs',
        columns: ['json'], where: 'itemId = ?', whereArgs: [itemId]);
    if (rows.isEmpty) return null;
    return SrsState.fromJson(
        jsonDecode(rows.first['json'] as String) as Map<String, dynamic>);
  }

  @override
  Future<void> putSrs(String itemId, SrsState state) =>
      _putSrs(_db, itemId, state);

  @override
  Future<Map<String, SrsState>> allSrs() async {
    final rows = await _db.query('srs', columns: ['itemId', 'json']);
    return {
      for (final r in rows)
        r['itemId'] as String: SrsState.fromJson(
            jsonDecode(r['json'] as String) as Map<String, dynamic>)
    };
  }

  @override
  Future<MasteryState?> mastery(String itemId) async {
    final rows = await _db.query('mastery',
        columns: ['json'], where: 'itemId = ?', whereArgs: [itemId]);
    if (rows.isEmpty) return null;
    return MasteryState.fromJson(
        jsonDecode(rows.first['json'] as String) as Map<String, dynamic>);
  }

  @override
  Future<void> putMastery(MasteryState state) => _putMastery(_db, state);

  @override
  Future<Map<String, MasteryState>> allMastery() async {
    final rows = await _db.query('mastery', columns: ['itemId', 'json']);
    return {
      for (final r in rows)
        r['itemId'] as String: MasteryState.fromJson(
            jsonDecode(r['json'] as String) as Map<String, dynamic>)
    };
  }

  @override
  Future<ItemRecord?> item(String itemId) async {
    final rows = await _db.query('items',
        where: 'itemId = ? AND (seedDueDay IS NOT NULL OR note IS NOT NULL)',
        whereArgs: [itemId]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return ItemRecord(
        itemId: itemId,
        seedDueDay: r['seedDueDay'] as int?,
        note: r['note'] as String?);
  }

  @override
  Future<void> setNote(String itemId, String? note) =>
      _db.transaction((txn) async {
        await _ensureItem(txn, itemId);
        await txn.update('items', {'note': note},
            where: 'itemId = ?', whereArgs: [itemId]);
      });

  @override
  Future<Map<String, String>> notes() async {
    final rows = await _db.query('items',
        columns: ['itemId', 'note'], where: 'note IS NOT NULL');
    return {for (final r in rows) r['itemId'] as String: r['note'] as String};
  }

  /// Stateful items by their FSRS due day, seeded items without a state by the seed's.
  static const String _dueSql = 'SELECT itemId, dueDay, 0 AS seeded FROM srs '
      'UNION ALL '
      'SELECT itemId, seedDueDay AS dueDay, 1 AS seeded FROM items '
      'WHERE seedDueDay IS NOT NULL '
      'AND itemId NOT IN (SELECT itemId FROM srs)';

  @override
  Future<List<DueItem>> dueOnOrBefore(int day) async {
    final rows =
        await _db.rawQuery('SELECT * FROM ($_dueSql) WHERE dueDay <= ?', [day]);
    return sortDue([
      for (final r in rows)
        DueItem(
            itemId: r['itemId'] as String,
            dueDay: r['dueDay'] as int,
            seeded: r['seeded'] == 1)
    ]);
  }

  @override
  Future<Map<int, int>> loadByDay() async {
    final rows = await _db.rawQuery(
        'SELECT dueDay, COUNT(*) AS n FROM ($_dueSql) GROUP BY dueDay');
    return {for (final r in rows) r['dueDay'] as int: r['n'] as int};
  }

  // --- the days --------------------------------------------------------------

  @override
  Future<DayRecord?> day(int day) async {
    final rows = await _db.query('days', where: 'day = ?', whereArgs: [day]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return DayRecord(
      day: r['day'] as int,
      plan: r['plan'] as String,
      position: r['position'] as int,
      completed: r['completed'] == 1,
    );
  }

  @override
  Future<void> putDay(DayRecord record) => _db.insert(
      'days',
      {
        'day': record.day,
        'plan': record.plan,
        'position': record.position,
        'completed': record.completed ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<int?> lastDay() async {
    final rows = await _db.rawQuery('SELECT MAX(day) AS d FROM days');
    return rows.first['d'] as int?;
  }

  // --- bookkeeping -----------------------------------------------------------

  @override
  Future<String?> meta(String key) async {
    final rows = await _db.query('meta', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  @override
  Future<void> putMeta(String key, String value) =>
      _db.insert('meta', {'key': key, 'value': value},
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> _writeDerived(Transaction txn, ReplayResult result) async {
    await txn.delete('srs');
    await txn.delete('mastery');
    await txn.update('items', {'seedDueDay': null});
    for (final e in result.srs.entries) {
      await _putSrs(txn, e.key, e.value);
    }
    for (final m in result.mastery.values) {
      await _putMastery(txn, m);
    }
    for (final e in result.seedDue.entries) {
      await _ensureItem(txn, e.key);
      await txn.update('items', {'seedDueDay': e.value},
          where: 'itemId = ?', whereArgs: [e.key]);
    }
    await txn.delete('items', where: 'seedDueDay IS NULL AND note IS NULL');
  }

  Future<void> _writeLog(Transaction txn, StudyLog log) async {
    for (final t in const ['attempts', 'seeds', 'items']) {
      await txn.delete(t);
    }
    // Restart the row ids, so an imported log keeps its numbering.
    await txn.execute(
        "DELETE FROM sqlite_sequence WHERE name IN ('attempts', 'seeds')");
    for (final a in log.attempts) {
      await _insertAttempt(txn, a);
    }
    for (final s in log.seeds) {
      await txn.insert('seeds', {
        'itemId': s.itemId,
        'dueDay': s.dueDay,
        'atUtc': s.atUtc.toUtc().toIso8601String(),
      });
    }
    for (final e in log.notes.entries) {
      await txn.insert('items', {'itemId': e.key, 'note': e.value});
    }
  }

  @override
  Future<void> replaceDerived(ReplayResult result) =>
      _db.transaction((txn) => _writeDerived(txn, result));

  /// One transaction: a throw in either write rolls back both.
  @override
  Future<void> replaceAll(StudyLog log, ReplayResult result) =>
      _db.transaction((txn) async {
        await _writeLog(txn, log);
        await _writeDerived(txn, result);
      });

  @override
  Future<void> close() => _db.close();
}
