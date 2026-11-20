// The study store on the phone: SQLite through `sqflite` (D14). Tests open it through the ffi
// factory of `sqflite_common_ffi` (A5), so the same suite runs here, on `JpStoreMemory` and
// on `JpStoreWeb`.
//
// Tables (schema version 3; version 1 had all but `discuss` and `events`, version 2 added
// `discuss`, version 3 added `events` and the event columns):
//   attempts  the append-only answer log: one row per attempt, its JSON plus indexed columns,
//             its event id, device id and pushed flag
//   seeds     the append-only seed events (D26): item, due day, time, event id, device id and
//             pushed flag; never an attempt
//   items     per item: the earliest seeded due day and a note
//   srs       per item: the FSRS state, its due day in a column for the due query
//   mastery   per item: the mastery state
//   days      per local day: the plan JSON, the position, whether it is done, and the device
//             and time that built the plan
//   meta      store-level flags, such as the one-time v2 migration and the device id
//   discuss   per item: the Discuss mark (PIN-6), its optional note and when it was set
//   events    the side events (jp_event.dart): note, Discuss, say-it score and last-lesson
//             changes, each with its event time in microseconds, its subject and a pushed flag
// Indexes on `srs.dueDay`, `attempts.itemId`, `events (kind, subject)`, and unique ones on
// `attempts.eventId` and `seeds.eventId`. `attempts`, `seeds` and `events` are the record;
// `items.note` and `discuss` are the latest side event per item; `srs`, `mastery` and
// `items.seedDueDay` are rebuilt from the log (JpStore.rebuild).
//
// One transaction per answer: `appendAttempt` writes the attempt, the schedule and the mastery
// state together. A later schema adds a step to [_upgrades]; `onUpgrade` runs the steps after
// the file's version, in order. Version 3 is the one-time event id migration: it gives every
// existing attempt and seed a legacy event id (a hash of the row content), its time cut to the
// millisecond, and no device id. It gives each note and Discuss mark an event, and leaves them
// all unpushed. It runs once per file, so the ids stay put on every later open. A side event
// with no device id keeps an empty `deviceId` in its row (the column is NOT NULL) and reads back
// as null.
//
// Reads take every column, so a file a test opens below the current version reads with no
// event ids. Writes need version 3.

import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common/sqlite_api.dart';

import 'attempt.dart';
import 'jp_event.dart';
import 'jp_store.dart';
import 'jp_store_web.dart';
import 'mastery_rule.dart';
import 'scheduler.dart';

/// The schema version this build writes.
const int kJpStoreSchemaVersion = 3;

/// The database file's name in the app's databases directory.
const String kJpStoreFileName = 'jp_study.db';

/// The schema steps after version 1, keyed by the version they produce.
final Map<int, Future<void> Function(Database db)> _upgrades = {
  2: _createV2Discuss,
  3: _createV3Events,
};

/// Version 2: the Discuss marks (PIN-6), one row per marked item. Every version 1 row stays.
Future<void> _createV2Discuss(Database db) =>
    db.execute('CREATE TABLE discuss ('
        'itemId TEXT PRIMARY KEY, '
        'note TEXT, '
        'atUtc TEXT NOT NULL)');

/// Version 3: global event ids (plan 2026-11-19, Task 1). Adds the event columns and the side
/// event table, then gives every existing row its legacy id ([LegacyEventIds]), once: a hash of
/// the row content, so the same old rows restored on another device get the same ids, and no
/// device id, so they are the same events there byte for byte. Each attempt, seed and Discuss
/// time is cut to the millisecond, because a web DateTime keeps no finer time (operator ruling,
/// Checkpoint 2026-11-20). The days take this store's device id as their builder. A note
/// becomes a note event at [kLegacyNoteAtUtc] (its own time was never kept); a Discuss mark
/// becomes an event at the time it was set. Every version 2 row stays, and every event starts
/// unpushed.
Future<void> _createV3Events(Database db) async {
  for (final table in const ['attempts', 'seeds']) {
    await db.execute('ALTER TABLE $table ADD COLUMN eventId TEXT');
    await db.execute('ALTER TABLE $table ADD COLUMN deviceId TEXT');
    await db.execute(
        'ALTER TABLE $table ADD COLUMN pushed INTEGER NOT NULL DEFAULT 0');
  }
  await db.execute('ALTER TABLE days ADD COLUMN deviceId TEXT');
  await db.execute('ALTER TABLE days ADD COLUMN builtAtUtc TEXT');
  await db.execute('CREATE TABLE events ('
      'eventId TEXT PRIMARY KEY, '
      'deviceId TEXT NOT NULL, '
      'atUs INTEGER NOT NULL, '
      'atUtc TEXT NOT NULL, '
      'kind TEXT NOT NULL, '
      'subject TEXT, '
      'body TEXT NOT NULL, '
      'pushed INTEGER NOT NULL DEFAULT 0)');
  await db.execute('CREATE INDEX events_subject ON events (kind, subject)');

  final kept =
      await db.query('meta', where: 'key = ?', whereArgs: [kDeviceIdMetaKey]);
  final device = kept.isEmpty ? newEventId() : kept.first['value'] as String;
  if (kept.isEmpty) {
    await db.insert('meta', {'key': kDeviceIdMetaKey, 'value': device});
  }
  // Legacy ids from the row content, in append order (operator ruling, Checkpoint 2026-11-19).
  // Each time is cut to the millisecond, in its column and in the attempt's JSON, so the web
  // derives the same events byte for byte (operator ruling, Checkpoint 2026-11-20).
  final legacy = LegacyEventIds();
  for (final r in await db.query('attempts', orderBy: 'id')) {
    final json = jsonDecode(r['json'] as String) as Map<String, dynamic>;
    final a = legacyAttempt(Attempt.fromJson(json));
    final at = a.atUtc.toIso8601String();
    await db.update(
        'attempts',
        {
          'eventId': legacy.attempt(a),
          'atUtc': at,
          'json': jsonEncode({...json, 'atUtc': at}),
        },
        where: 'id = ?',
        whereArgs: [r['id']]);
  }
  for (final r in await db.query('seeds', orderBy: 'id')) {
    final s = legacySeed(SeedEvent(
        itemId: r['itemId'] as String,
        dueDay: r['dueDay'] as int,
        atUtc: DateTime.parse(r['atUtc'] as String).toUtc()));
    await db.update('seeds',
        {'eventId': legacy.seed(s), 'atUtc': s.atUtc.toIso8601String()},
        where: 'id = ?', whereArgs: [r['id']]);
  }
  for (final table in const ['attempts', 'seeds']) {
    await db
        .execute('CREATE UNIQUE INDEX ${table}_eventId ON $table (eventId)');
  }
  await db.update('days', {'deviceId': device});
  for (final r in await db.query('items',
      columns: ['itemId', 'note'],
      where: 'note IS NOT NULL',
      orderBy: 'itemId')) {
    final itemId = r['itemId'] as String, note = r['note'] as String;
    await _insertEvent(
        db,
        noteEvent(itemId, note,
            eventId: legacy.note(itemId, note),
            deviceId: null,
            atUtc: kLegacyNoteAtUtc),
        pushed: false);
  }
  for (final r in await db.query('discuss', orderBy: 'itemId')) {
    final mark = legacyMark(DiscussMark(
        itemId: r['itemId'] as String,
        note: r['note'] as String?,
        atUtc: DateTime.parse(r['atUtc'] as String).toUtc()));
    await db.update('discuss', {'atUtc': mark.atUtc.toIso8601String()},
        where: 'itemId = ?', whereArgs: [mark.itemId]);
    await _insertEvent(
        db,
        discussEvent(mark.itemId,
            note: mark.note,
            eventId: legacy.discuss(mark),
            deviceId: null,
            atUtc: mark.atUtc),
        pushed: false);
  }
}

/// Writes one side event row; a legacy event's device id is written empty.
Future<void> _insertEvent(DatabaseExecutor db, JpEvent e,
        {required bool pushed}) =>
    db.insert('events', {
      'eventId': e.eventId,
      'deviceId': e.deviceId ?? '',
      'atUs': e.atUtc.microsecondsSinceEpoch,
      'atUtc': e.atUtc.toIso8601String(),
      'kind': e.kind.wire,
      'subject': e.subject,
      'body': jsonEncode(e.body),
      'pushed': pushed ? 1 : 0,
    });

JpEvent _eventOf(Map<String, Object?> r) => JpEvent(
      eventId: r['eventId'] as String,
      deviceId: switch (r['deviceId']) {
        final String d when d.isNotEmpty => d,
        _ => null
      },
      atUtc: DateTime.parse(r['atUtc'] as String),
      kind: JpEventKind.fromWire(r['kind']),
      body: jsonDecode(r['body'] as String) as Map<String, dynamic>,
    );

/// The ids in [ids], in runs short enough for SQLite's bound-parameter limit.
Iterable<List<String>> _chunks(List<String> ids) sync* {
  const size = 500;
  for (var i = 0; i < ids.length; i += size) {
    yield ids.sublist(i, i + size > ids.length ? ids.length : i + size);
  }
}

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

/// Opens the platform's store: SQLite on the phone, and on web a store that keeps the record
/// in the browser across reloads ([JpStoreWeb], A4).
///
/// Each call opens a new store. The app opens one per run through [sharedJpStore]. Two stores
/// on web (two tabs) share one lock and re-read before each write, so neither saves over the
/// other; two on the phone do not serialize answers.
/// [webStorage] is a test seam for the web store's browser storage; the app passes nothing and
/// the web store uses IndexedDB.
Future<JpStore> openJpStore(
    {bool isWeb = kIsWeb, JpWebStorage? webStorage}) async {
  if (isWeb) return JpStoreWeb.open(storage: webStorage);
  return JpStoreSqlite.open();
}

Future<JpStore>? _sharedStore;

/// The one store of the run: opened on first use and kept. Every screen that reads or writes
/// answers without an injected store goes through here (the practice, grammar, lesson and
/// drill screens and the study record page), so the phone holds one SQLite handle and web
/// holds one web store. A failed open is not kept, so the next call tries again. Each
/// caller reports its own failed open.
///
/// [open] is a seam for the retry test; the app passes nothing and opens the platform's store.
Future<JpStore> sharedJpStore(
        {Future<JpStore> Function() open = openJpStore}) =>
    _sharedStore ??= open().catchError((Object e) {
      _sharedStore = null;
      throw e;
    });

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

/// Replaces the store [sharedJpStore] hands out, for widget tests that cannot open SQLite.
/// Null forgets it. It replaces the cached store; the [open] parameter of sharedJpStore only
/// swaps how a missing store is opened.
@visibleForTesting
void debugSetSharedJpStore(JpStore? store) =>
    _sharedStore = store == null ? null : Future.value(store);

class JpStoreSqlite extends JpStore {
  JpStoreSqlite._(this._db, {super.clock});

  final Database _db;

  /// Opens (creating or upgrading) the store at [path], by default [kJpStoreFileName] in the
  /// app's databases directory, through [factory], by default sqflite's platform factory.
  ///
  /// [version], [upgrades] and [clock] are test seams: the build always opens at
  /// [kJpStoreSchemaVersion] with the registered steps and the system clock.
  static Future<JpStoreSqlite> open({
    DatabaseFactory? factory,
    String? path,
    int version = kJpStoreSchemaVersion,
    Map<int, Future<void> Function(Database db)>? upgrades,
    DateTime Function()? clock,
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
    return JpStoreSqlite._(db, clock: clock);
  }

  /// The schema version of the open file.
  Future<int> schemaVersion() => _db.getVersion();

  // --- the log ---------------------------------------------------------------

  @override
  Future<Attempt> appendAttempt(Attempt attempt,
      {SrsState? srs, MasteryState? mastery}) async {
    checkAnswerStates(attempt, mastery);
    // Stamped before the transaction: the device id read goes through `_db`.
    final stamped = await stampAttempt(attempt);
    return _db.transaction((txn) async {
      final id = await _insertAttempt(txn, stamped);
      if (srs != null) await _putSrs(txn, attempt.itemId, srs);
      if (mastery != null) await _putMastery(txn, mastery);
      return attemptWithId(stamped, id);
    });
  }

  /// The event id and device id live in their own columns, not in the JSON.
  Future<int> _insertAttempt(DatabaseExecutor db, Attempt attempt,
      {bool pushed = false}) {
    final json = attempt.toJson()
      ..remove('id')
      ..remove('eventId')
      ..remove('deviceId');
    return db.insert('attempts', {
      'itemId': attempt.itemId,
      'atUtc': attempt.atUtc.toUtc().toIso8601String(),
      'localDay': attempt.localDay,
      'json': jsonEncode(json),
      'eventId': attempt.eventId,
      'deviceId': attempt.deviceId,
      'pushed': pushed ? 1 : 0,
    });
  }

  Attempt _attemptOf(Map<String, Object?> r) => Attempt.fromJson({
        ...jsonDecode(r['json'] as String) as Map<String, dynamic>,
        'id': r['id'] as int,
        if (r['eventId'] != null) 'eventId': r['eventId'],
        if (r['deviceId'] != null) 'deviceId': r['deviceId'],
      });

  SeedEvent _seedOf(Map<String, Object?> r) => SeedEvent(
        id: r['id'] as int,
        itemId: r['itemId'] as String,
        dueDay: r['dueDay'] as int,
        atUtc: DateTime.parse(r['atUtc'] as String).toUtc(),
        eventId: r['eventId'] as String?,
        deviceId: r['deviceId'] as String?,
      );

  /// The item's row, created empty when missing. Plain SQL, no upsert: the platform SQLite on
  /// older Android predates `ON CONFLICT ... DO UPDATE` (3.24).
  Future<void> _ensureItem(DatabaseExecutor db, String itemId) =>
      db.insert('items', {'itemId': itemId},
          conflictAlgorithm: ConflictAlgorithm.ignore);

  Future<void> _insertSeedRow(DatabaseExecutor db, SeedEvent seed,
          {bool pushed = false}) =>
      db.insert('seeds', {
        'itemId': seed.itemId,
        'dueDay': seed.dueDay,
        'atUtc': seed.atUtc.toUtc().toIso8601String(),
        'eventId': seed.eventId,
        'deviceId': seed.deviceId,
        'pushed': pushed ? 1 : 0,
      });

  Future<void> _insertSeed(DatabaseExecutor db, SeedEvent seed,
      {bool pushed = false}) async {
    await _insertSeedRow(db, seed, pushed: pushed);
    // The earliest seeded due day wins.
    await _ensureItem(db, seed.itemId);
    await db.rawUpdate(
        'UPDATE items SET seedDueDay = ? WHERE itemId = ? '
        'AND (seedDueDay IS NULL OR seedDueDay > ?)',
        [seed.dueDay, seed.itemId, seed.dueDay]);
  }

  @override
  Future<void> appendSeeds(Iterable<SeedEvent> seeds) async {
    final stamped = [for (final s in seeds) await stampSeed(s)];
    await _db.transaction((txn) async {
      for (final s in stamped) {
        await _insertSeed(txn, s);
      }
    });
  }

  @override
  Future<List<Attempt>> attempts({String? itemId}) async {
    final rows = await _db.query('attempts',
        where: itemId == null ? null : 'itemId = ?',
        whereArgs: itemId == null ? null : [itemId],
        orderBy: 'id');
    return [for (final r in rows) _attemptOf(r)];
  }

  @override
  Future<List<SeedEvent>> seeds() async {
    final rows = await _db.query('seeds', orderBy: 'id');
    return [for (final r in rows) _seedOf(r)];
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
  Future<Map<String, String>> notes() async {
    final rows = await _db.query('items',
        columns: ['itemId', 'note'], where: 'note IS NOT NULL');
    return {for (final r in rows) r['itemId'] as String: r['note'] as String};
  }

  Future<void> _insertDiscuss(DatabaseExecutor db, DiscussMark mark,
          {ConflictAlgorithm? conflictAlgorithm}) =>
      db.insert(
          'discuss',
          {
            'itemId': mark.itemId,
            'note': mark.note,
            'atUtc': mark.atUtc.toUtc().toIso8601String(),
          },
          conflictAlgorithm: conflictAlgorithm);

  DiscussMark _discussOf(Map<String, Object?> r) => DiscussMark(
      itemId: r['itemId'] as String,
      note: r['note'] as String?,
      atUtc: DateTime.parse(r['atUtc'] as String).toUtc());

  @override
  Future<DiscussMark?> discuss(String itemId) async {
    final rows =
        await _db.query('discuss', where: 'itemId = ?', whereArgs: [itemId]);
    return rows.isEmpty ? null : _discussOf(rows.first);
  }

  @override
  Future<Map<String, DiscussMark>> discussMarks() async {
    final rows = await _db.query('discuss', orderBy: 'itemId');
    return {for (final r in rows) r['itemId'] as String: _discussOf(r)};
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
    final built = r['builtAtUtc'] as String?;
    return DayRecord(
      day: r['day'] as int,
      plan: r['plan'] as String,
      position: r['position'] as int,
      completed: r['completed'] == 1,
      deviceId: r['deviceId'] as String?,
      builtAtUtc: built == null ? null : DateTime.parse(built).toUtc(),
    );
  }

  @override
  Future<void> putDay(DayRecord record) async {
    final stamped = await stampDay(record);
    await _db.insert(
        'days',
        {
          'day': stamped.day,
          'plan': stamped.plan,
          'position': stamped.position,
          'completed': stamped.completed ? 1 : 0,
          'deviceId': stamped.deviceId,
          'builtAtUtc': stamped.builtAtUtc?.toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

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

  /// The ids of every pushed event (or one appended from a remote).
  Future<Set<String>> _pushedIds(DatabaseExecutor db) async => {
        for (final r in await db
            .rawQuery('SELECT eventId FROM attempts WHERE pushed = 1 '
                'UNION ALL SELECT eventId FROM seeds WHERE pushed = 1 '
                'UNION ALL SELECT eventId FROM events WHERE pushed = 1'))
          if (r['eventId'] != null) r['eventId'] as String
      };

  /// Writes a prepared log ([prepareLog]). An event pushed before stays pushed.
  Future<void> _writeLog(Transaction txn, StudyLog log) async {
    final pushed = await _pushedIds(txn);
    for (final t in const ['attempts', 'seeds', 'items', 'discuss', 'events']) {
      await txn.delete(t);
    }
    // Restart the row ids, so an imported log keeps its numbering.
    await txn.execute(
        "DELETE FROM sqlite_sequence WHERE name IN ('attempts', 'seeds')");
    for (final a in log.attempts) {
      await _insertAttempt(txn, a, pushed: pushed.contains(a.eventId));
    }
    for (final s in log.seeds) {
      await _insertSeedRow(txn, s, pushed: pushed.contains(s.eventId));
    }
    for (final e in log.events) {
      await _insertEvent(txn, e, pushed: pushed.contains(e.eventId));
    }
    for (final e in log.notes.entries) {
      await txn.insert('items', {'itemId': e.key, 'note': e.value});
    }
    for (final m in log.discuss.values) {
      await _insertDiscuss(txn, m);
    }
  }

  @override
  Future<void> replaceDerived(ReplayResult result) =>
      _db.transaction((txn) => _writeDerived(txn, result));

  /// One transaction: a throw in either write rolls back both. The log is prepared before
  /// the transaction, because prepareLog reads the held rows through _db.
  @override
  Future<void> replaceAll(StudyLog log, ReplayResult result) async {
    final prepared = await prepareLog(log);
    await _db.transaction((txn) async {
      await _writeLog(txn, prepared);
      await _writeDerived(txn, result);
    });
  }

  // --- side events and sync ----------------------------------------------------

  /// Moves the note or Discuss mark of [event]'s item to the latest event for that item. The
  /// latest is picked in Dart by [resolveNotes] or [resolveDiscuss], so it follows
  /// [compareEvents] at the millisecond, never the microsecond `atUs` column.
  Future<void> _refresh(DatabaseExecutor db, JpEvent event) async {
    final id = event.subject;
    if (id == null) return;
    if (event.kind != JpEventKind.note && event.kind != JpEventKind.discuss) {
      return;
    }
    final rows = await db.query('events',
        where: 'kind = ? AND subject = ?', whereArgs: [event.kind.wire, id]);
    if (rows.isEmpty) return;
    final held = [for (final r in rows) _eventOf(r)];
    if (event.kind == JpEventKind.note) {
      await _ensureItem(db, id);
      await db.update('items', {'note': resolveNotes(held)[id]},
          where: 'itemId = ?', whereArgs: [id]);
    } else {
      await db.delete('discuss', where: 'itemId = ?', whereArgs: [id]);
      final mark = resolveDiscuss(held)[id];
      if (mark != null) await _insertDiscuss(db, mark);
    }
  }

  @override
  Future<List<JpEvent>> sideEvents() async => [
        for (final r in await _db.query('events')) _eventOf(r)
      ]..sort(compareEvents);

  /// One `WHERE kind = ?` query, on the `events (kind, subject)` index: no other kind's row is
  /// read or decoded (#204).
  @override
  Future<List<JpEvent>> eventsOfKind(JpEventKind kind) async => [
        for (final r in await _db
            .query('events', where: 'kind = ?', whereArgs: [kind.wire]))
          _eventOf(r)
      ]..sort(compareEvents);

  @override
  Future<void> writeSideEvent(JpEvent event) => _db.transaction((txn) async {
        await _insertEvent(txn, event, pushed: false);
        await _refresh(txn, event);
      });

  @override
  Future<List<JpEvent>> unpushedEvents() async {
    final out = <JpEvent>[
      for (final r in await _db.query('attempts',
          where: 'pushed = 0 AND eventId IS NOT NULL', orderBy: 'id'))
        attemptEvent(_attemptOf(r)),
      for (final r in await _db.query('seeds',
          where: 'pushed = 0 AND eventId IS NOT NULL', orderBy: 'id'))
        seedEvent(_seedOf(r)),
      for (final r in await _db.query('events', where: 'pushed = 0'))
        _eventOf(r),
    ];
    return out..sort(compareEvents);
  }

  @override
  Future<void> markPushed(Iterable<String> eventIds) {
    final ids = eventIds.toSet().toList();
    return _db.transaction((txn) async {
      for (final chunk in _chunks(ids)) {
        final marks = List.filled(chunk.length, '?').join(', ');
        for (final t in const ['attempts', 'seeds', 'events']) {
          await txn.rawUpdate(
              'UPDATE $t SET pushed = 1 WHERE eventId IN ($marks)', chunk);
        }
      }
    });
  }

  @override
  Future<List<JpEvent>> writeRemoteEvents(List<JpEvent> events) =>
      _db.transaction((txn) async {
        final added = <JpEvent>[];
        for (final e in events) {
          final held = await txn.rawQuery(
              'SELECT 1 FROM attempts WHERE eventId = ? '
              'UNION ALL SELECT 1 FROM seeds WHERE eventId = ? '
              'UNION ALL SELECT 1 FROM events WHERE eventId = ? LIMIT 1',
              [e.eventId, e.eventId, e.eventId]);
          if (held.isNotEmpty) continue;
          switch (e.kind) {
            case JpEventKind.attempt:
              await _insertAttempt(txn, attemptOfEvent(e), pushed: true);
            case JpEventKind.seed:
              await _insertSeed(txn, seedOfEvent(e), pushed: true);
            case JpEventKind.note:
            case JpEventKind.discuss:
            case JpEventKind.speakScore:
            case JpEventKind.lastLesson:
              await _insertEvent(txn, e, pushed: true);
              await _refresh(txn, e);
          }
          added.add(e);
        }
        return added;
      });

  @override
  Future<void> close() => _db.close();
}
