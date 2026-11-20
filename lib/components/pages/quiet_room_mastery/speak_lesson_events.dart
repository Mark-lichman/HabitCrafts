// HAND-WRITTEN. Not FlutterFlow output, so S3 has nothing to adopt.
//
// The say-it score log and the last grammar lesson, in the study store (plan 2026-11-19,
// Task 13, D16, PIN-16). Both used to live in SharedPreferences (`jp.speak.scores` and
// `jp.grammar.lastLesson`), so they stayed on one device. Now each change is a store event that
// syncs like every other:
//   * a say-it score is a `speak_score` event whose body is the score log's own entry
//     (`SpeakAttempt.toJson`). A self-mark is a second event with the marked entry, later than
//     the first. The log shows one entry per attempt (one sentence at one moment): the entry of
//     its latest event, so the later event time wins (`SpeakScoreLog` in
//     quiet_room_speak_widget.dart);
//   * the last lesson is a `last_lesson` event whose `lessonId` is the lesson number in decimal.
//     The last lesson shown is the latest event by event time (`JpStore.lastLesson`).
//
// The one-time import (`importSpeakAndLessonPrefs`) moves the two old values into the store.
// It runs before the first read on each store, and a store meta flag, written last, records it.
// The two keys stay in place, as the v2 migration leaves its keys (study_export.dart), and
// nothing writes them again.
//   * Each readable score becomes a `speak_score` event at the attempt's own time. An entry this
//     build cannot read, or one with no real time (before 2000), is skipped, as the v2 migration
//     skips it.
//   * The old last lesson kept no time. It becomes a `last_lesson` event at the Unix epoch
//     (`kLegacyLastLessonAtUtc`), so a lesson opened on any device after it wins. A store that
//     already holds a last lesson (one synced from another device) keeps it and skips the old
//     value.
//   * A score log that is present but unreadable (not a string, not JSON or not a list) is
//     reported to FlutterError, never read as empty in silence (S4), and the flag is still set.
// Every imported event takes a legacy id of its content (`legacyEventId`), so a run cut short
// before the flag skips what it already wrote, and two devices that import one value share one
// event. Callers on one store share one run in flight, so two first reads never write one id
// twice.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../quiet_room_grammar/quiet_room_speak_widget.dart'
    show SpeakAttempt, SpeakScoreLog;
import 'jp_event.dart';
import 'jp_store.dart';
import 'seed_confirm_widget.dart' show kLastGrammarLessonKey;

/// The store flag set once the two SharedPreferences values are imported.
const String kSpeakLessonImportFlag = 'migration.speakLesson';

/// The event time of the imported last lesson, whose own time was never kept: the Unix epoch,
/// the same unknown time a legacy note takes (`kLegacyNoteAtUtc`).
final DateTime kLegacyLastLessonAtUtc = DateTime.utc(1970);

/// The import run in flight on each store, so callers that overlap share it.
final Expando<Future<int>> _importsInFlight = Expando('speakLessonImport');

/// Imports `jp.speak.scores` and `jp.grammar.lastLesson` from [prefs] into [store], once per
/// store (see the file comment). [prefs] null reads the device's own. Returns the number of
/// events written; zero once the flag is set. A call made while another runs on [store] waits
/// for that run and returns its count.
Future<int> importSpeakAndLessonPrefs(JpStore store,
    {SharedPreferences? prefs}) async {
  final pending = _importsInFlight[store];
  if (pending != null) return pending;
  final run = _importOnce(store, prefs);
  _importsInFlight[store] = run;
  try {
    return await run;
  } finally {
    if (identical(_importsInFlight[store], run)) _importsInFlight[store] = null;
  }
}

Future<int> _importOnce(JpStore store, SharedPreferences? prefs) async {
  if (await store.meta(kSpeakLessonImportFlag) != null) return 0;
  final p = prefs ?? await SharedPreferences.getInstance();
  final held = await store.sideEvents();
  final heldIds = {for (final e in held) e.eventId};
  final device = await store.deviceId();
  var written = 0;

  Future<void> write(JpEvent e) async {
    if (!heldIds.add(e.eventId)) return;
    await store.writeSideEvent(e);
    written++;
  }

  final rawLog = p.get(SpeakScoreLog.prefsKey);
  final entries = rawLog == null ? const <Object?>[] : _decodeList(rawLog);
  if (entries == null) {
    FlutterError.reportError(FlutterErrorDetails(
        exception: FormatException(
            'unreadable ${SpeakScoreLog.prefsKey}', '${rawLog.runtimeType}'),
        library: 'speak lesson events',
        context: ErrorDescription('while importing the old say-it score log')));
  }
  for (final raw in entries ?? const <Object?>[]) {
    final a = SpeakAttempt.fromJson(raw);
    if (a == null || a.at.year < 2000) continue;
    final at = a.at.toUtc();
    await write(JpEvent(
      eventId: legacyEventId(JpEventKind.speakScore,
          [at.toIso8601String(), a.sentence, a.selfMark]),
      deviceId: device,
      atUtc: at,
      kind: JpEventKind.speakScore,
      body: a.toJson(),
    ));
  }

  final lesson = p.get(kLastGrammarLessonKey);
  if (lesson is int && resolveLastLesson(held) == null) {
    final lessonId = '$lesson';
    await write(JpEvent(
      eventId: legacyEventId(JpEventKind.lastLesson, [lessonId]),
      deviceId: device,
      atUtc: kLegacyLastLessonAtUtc,
      kind: JpEventKind.lastLesson,
      body: {'lessonId': lessonId},
    ));
  }

  await store.putMeta(
      kSpeakLessonImportFlag, store.clock().toUtc().toIso8601String());
  return written;
}

/// Runs the one-time import for the last-lesson helpers and reports a failure to FlutterError
/// (S4) in place of throwing it. The import is best effort: the old lesson lands at the Unix
/// epoch, so it loses to any real last_lesson event in either order, and a later run that finds
/// one held skips it.
Future<void> _importForLastLesson(
    JpStore store, SharedPreferences? prefs) async {
  try {
    await importSpeakAndLessonPrefs(store, prefs: prefs);
  } catch (e, st) {
    FlutterError.reportError(FlutterErrorDetails(
        exception: e,
        stack: st,
        library: 'speak lesson events',
        context: ErrorDescription('while importing the old last lesson')));
  }
}

/// The last grammar lesson opened, by the latest event time, after the one-time import; null
/// before the first or when the latest names no lesson number. A failed import is reported and
/// the store is still read.
Future<int?> readLastGrammarLesson(JpStore store,
    {SharedPreferences? prefs}) async {
  await _importForLastLesson(store, prefs);
  final id = await store.lastLesson();
  return id == null ? null : int.tryParse(id);
}

/// Records [lesson] as the last grammar lesson opened, at the store's clock. The store moves the
/// event past the latest one, so the lesson just opened shows here at once. A failed import is
/// reported and the lesson is still written.
Future<void> rememberLastGrammarLesson(JpStore store, int lesson,
    {SharedPreferences? prefs}) async {
  await _importForLastLesson(store, prefs);
  await store.setLastLesson('$lesson', atUtc: store.clock().toUtc());
}

/// The score log's entries, or null when [raw] is not a string, not JSON or not a list (as
/// study_export.dart reads it).
List<Object?>? _decodeList(Object raw) {
  if (raw is! String) return null;
  try {
    final v = jsonDecode(raw);
    return v is List ? v : null;
  } catch (_) {
    return null;
  }
}
