// A study store file as a build before event ids wrote it (plan 2026-11-19, Task 1). Shared by
// test/jp_store_test.dart and test/jp_event_test.dart.

import 'dart:convert';

import 'package:habit_craft/components/pages/quiet_room_mastery/attempt.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/mastery_rule.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/scheduler.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Writes rows into the file at [path] as a build before event ids wrote them: raw SQL against
/// the version 1 and 2 tables, with no event column. The store cannot write such a file
/// itself, because its writes need the event columns of version 3. [discuss] needs a file at
/// version 2.
Future<void> writeOldRows(
  String path, {
  List<Attempt> attempts = const [],
  Map<String, SrsState> srs = const {},
  List<MasteryState> mastery = const [],
  List<SeedEvent> seeds = const [],
  Map<String, String> notes = const {},
  List<DiscussMark> discuss = const [],
  List<DayRecord> days = const [],
}) async {
  final db = await databaseFactoryFfi.openDatabase(path);
  try {
    Future<void> ensureItem(String itemId) =>
        db.insert('items', {'itemId': itemId},
            conflictAlgorithm: ConflictAlgorithm.ignore);
    for (final a in attempts) {
      await db.insert('attempts', {
        'itemId': a.itemId,
        'atUtc': a.atUtc.toUtc().toIso8601String(),
        'localDay': a.localDay,
        'json': jsonEncode(a.toJson()
          ..remove('id')
          ..remove('eventId')
          ..remove('deviceId')),
      });
    }
    for (final e in srs.entries) {
      await db.insert('srs', {
        'itemId': e.key,
        'dueDay': e.value.dueDay,
        'json': jsonEncode(e.value.toJson()),
      });
    }
    for (final m in mastery) {
      await db.insert('mastery', {
        'itemId': m.itemId,
        'status': m.status.name,
        'json': jsonEncode(m.toJson()),
      });
    }
    for (final s in seeds) {
      await db.insert('seeds', {
        'itemId': s.itemId,
        'dueDay': s.dueDay,
        'atUtc': s.atUtc.toUtc().toIso8601String(),
      });
      await ensureItem(s.itemId);
      await db.rawUpdate(
          'UPDATE items SET seedDueDay = ? WHERE itemId = ? '
          'AND (seedDueDay IS NULL OR seedDueDay > ?)',
          [s.dueDay, s.itemId, s.dueDay]);
    }
    for (final n in notes.entries) {
      await ensureItem(n.key);
      await db.update('items', {'note': n.value},
          where: 'itemId = ?', whereArgs: [n.key]);
    }
    for (final m in discuss) {
      await db.insert('discuss', {
        'itemId': m.itemId,
        'note': m.note,
        'atUtc': m.atUtc.toUtc().toIso8601String(),
      });
    }
    for (final d in days) {
      await db.insert('days', {
        'day': d.day,
        'plan': d.plan,
        'position': d.position,
        'completed': d.completed ? 1 : 0,
      });
    }
  } finally {
    await db.close();
  }
}
