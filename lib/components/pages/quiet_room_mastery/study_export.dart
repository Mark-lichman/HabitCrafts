// The study record in and out: the JSON Lines export, its import through the replay, and the
// one-time import of the v2 study keys (Task 8).
//
// Export format, one JSON object per line:
//   line 1   the header: {"format": "habitcrafts.jp.study", "version": 3, "exportedAtUtc",
//            "attempts": n, "seeds": n, "notes": n, "discuss": n, "events": n}
//   then     {"type": "seed", ...SeedEvent}, {"type": "attempt", ...Attempt}, the note lines,
//            the discuss lines, then {"type": "speak_score" | "last_lesson", "eventId",
//            "deviceId", "atUtc", "body"}: seeds first, each log kind in log order, the notes
//            and then the Discuss lines by item id and event order, the last two kinds by event
//            order, so the same record exports the same bytes from either store.
// Version 3 (plan 2026-11-19, Task 1) carries the global event ids and event times: every seed
// and attempt line has its `eventId` and `deviceId`, and every note or Discuss change is its own
// line with its `eventId`, `deviceId` and `atUtc`. A note line with `"note": null` clears the
// note; a discuss line with `"cleared": true` clears the mark. The header counts lines, and
// `events` counts the say-it score and last-lesson lines.
// Version 2 (the Discuss marks) and version 1 (before them, no `discuss` count and no discuss
// lines) carry no event ids; this build still reads both, and the store gives each event an id
// when it imports them (End state 8 of plan 2026-11-02). An older build refuses version 3.
// Reading it back replaces the store's log, notes and marks and rebuilds every state from the
// log (JpStore.importLog), so an export is also a backup and the input for fitting FSRS
// offline (A1). A Discuss mark never reaches the replay (PIN-6).
//
// The v2 migration reads two SharedPreferences keys and leaves both in place for one release:
//   * `jp.selfcheck.<pointId>`: `review_needed` marks the point due today (a seed event, no
//     attempt); `can_use_it` is kept as the item's note and schedules nothing;
//   * `jp.speak.scores`: each spoken attempt becomes a Say-it attempt on the grammar point whose
//     sentence it was. Say-it never counts toward mastery and never moves the schedule (D4).
// It runs once per store: a flag in the store's meta records it, written last. A run the app
// cut short before the flag runs again on the next launch: a Say-it attempt it already logged
// (same point, probe, instant and source) is skipped, so the history is never logged twice.
// A `jp.speak.scores` blob this build cannot read counts as skipped and still sets the flag.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../quiet_room_grammar/quiet_room_speak_widget.dart'
    show SpeakAttempt, SpeakScoreLog, lessonSentences;
import '../quiet_room_practice/speech_service.dart' show Judgement;
import 'attempt.dart';
import 'item_catalog.dart' show kSayItTemplate;
import 'jp_event.dart';
import 'jp_store.dart';
import 'local_day.dart';
import 'scheduler.dart';

/// The export header's `format`.
const String kStudyExportFormat = 'habitcrafts.jp.study';

/// The export format version this build writes. It reads this version and every earlier one.
/// Version 2 added the Discuss marks; version 3 the event ids and event times.
const int kStudyExportVersion = 3;

/// The side event kinds written as their own line types after the Discuss lines.
const Set<JpEventKind> _plainEventKinds = {
  JpEventKind.speakScore,
  JpEventKind.lastLesson,
};

/// One line per note or Discuss change in [log], by item id and then event order. An item
/// with a note or mark and no event (a log built by hand) gets one line with no event fields.
List<Map<String, dynamic>> _changeLines(StudyLog log, JpEventKind kind) {
  final lines = <({String itemId, int order, Map<String, dynamic> json})>[];
  final named = <String>{};
  final events = [...log.events]..sort(compareEvents);
  for (var i = 0; i < events.length; i++) {
    final e = events[i];
    if (e.kind != kind) continue;
    final itemId = e.subject!;
    named.add(itemId);
    final json = kind == JpEventKind.note
        ? {'type': 'note', 'itemId': itemId, 'note': e.body['note']}
        : {
            'type': 'discuss',
            'itemId': itemId,
            if (e.body['note'] != null) 'note': e.body['note'],
            'atUtc': e.atUtc.toIso8601String(),
            if (e.body['cleared'] == true) 'cleared': true,
          };
    lines.add((
      itemId: itemId,
      order: i,
      json: {
        ...json,
        if (kind == JpEventKind.note) 'atUtc': e.atUtc.toIso8601String(),
        'eventId': e.eventId,
        'deviceId': e.deviceId,
      }
    ));
  }
  if (kind == JpEventKind.note) {
    for (final n in log.notes.entries) {
      if (named.contains(n.key)) continue;
      lines.add((
        itemId: n.key,
        order: -1,
        json: {'type': 'note', 'itemId': n.key, 'note': n.value}
      ));
    }
  } else {
    for (final m in log.discuss.values) {
      if (named.contains(m.itemId)) continue;
      lines.add((
        itemId: m.itemId,
        order: -1,
        json: {'type': 'discuss', ...m.toJson()}
      ));
    }
  }
  lines.sort((a, b) {
    final byItem = a.itemId.compareTo(b.itemId);
    return byItem != 0 ? byItem : a.order.compareTo(b.order);
  });
  return [for (final l in lines) l.json];
}

/// Writes [log] as JSON Lines with a header line.
String encodeStudyExport(StudyLog log, {required DateTime exportedAt}) {
  final notes = _changeLines(log, JpEventKind.note);
  final discuss = _changeLines(log, JpEventKind.discuss);
  final plain = [
    for (final e in [...log.events]..sort(compareEvents))
      if (_plainEventKinds.contains(e.kind))
        {
          'type': e.kind.wire,
          'eventId': e.eventId,
          'deviceId': e.deviceId,
          'atUtc': e.atUtc.toIso8601String(),
          'body': e.body,
        }
  ];
  final lines = <String>[
    jsonEncode({
      'format': kStudyExportFormat,
      'version': kStudyExportVersion,
      'exportedAtUtc': exportedAt.toUtc().toIso8601String(),
      'attempts': log.attempts.length,
      'seeds': log.seeds.length,
      'notes': notes.length,
      'discuss': discuss.length,
      'events': plain.length,
    }),
    for (final s in log.seeds) jsonEncode({'type': 'seed', ...s.toJson()}),
    for (final a in log.attempts)
      jsonEncode({'type': 'attempt', ...a.toJson()}),
    for (final n in notes) jsonEncode(n),
    for (final d in discuss) jsonEncode(d),
    for (final p in plain) jsonEncode(p),
  ];
  return '${lines.join('\n')}\n';
}

/// The event a v3 change or event line carries. [body] is the event's body.
JpEvent _lineEvent(
        Map<String, dynamic> j, JpEventKind kind, Map<String, dynamic> body) =>
    JpEvent.fromFirestore({
      'eventId': j['eventId'],
      'deviceId': j['deviceId'],
      'atUtc': j['atUtc'],
      'kind': kind.wire,
      'body': body,
    });

/// Reads an export written by [encodeStudyExport]. Throws a [FormatException] naming the line
/// for a missing or foreign header, a newer version, an unknown line type, an unreadable line,
/// an attempt whose rating no [SrsRating] has, or counts that disagree with the header. A
/// header with no `discuss` count (version 1) counts no Discuss line, and one with no `events`
/// count (versions 1 and 2) counts no event line. A note or discuss line with an `eventId` is a
/// change event; one without is the item's note or mark from before event ids. A blank line is
/// skipped and still counted, so the named line is the file's own.
StudyLog decodeStudyExport(String text) {
  final all = const LineSplitter().convert(text);
  final lines = <({int no, String text})>[
    for (var i = 0; i < all.length; i++)
      if (all[i].trim().isNotEmpty) (no: i + 1, text: all[i])
  ];
  if (lines.isEmpty) throw const FormatException('study export: empty');
  Map<String, dynamic> parse(int i) {
    try {
      return jsonDecode(lines[i].text) as Map<String, dynamic>;
    } catch (_) {
      throw FormatException(
          'study export: line ${lines[i].no} is not a JSON object');
    }
  }

  final header = parse(0);
  if (header['format'] != kStudyExportFormat) {
    throw FormatException(
        'study export: line ${lines[0].no} is not the header');
  }
  final version = header['version'];
  if (version is! int || version > kStudyExportVersion) {
    throw FormatException('study export: version $version is not readable');
  }
  final attempts = <Attempt>[];
  final seeds = <SeedEvent>[];
  final notes = <String, String>{};
  final discuss = <String, DiscussMark>{};
  final events = <JpEvent>[];
  var noteLines = 0, discussLines = 0, eventLines = 0;
  for (var i = 1; i < lines.length; i++) {
    final j = parse(i);
    try {
      switch (j['type']) {
        case 'attempt':
          final attempt = Attempt.fromJson(j);
          final rating = attempt.rating;
          if (rating != null &&
              !SrsRating.values.any((r) => r.value == rating)) {
            throw FormatException('rating $rating is outside 1 to 4');
          }
          attempts.add(attempt);
        case 'seed':
          seeds.add(SeedEvent.fromJson(j));
        case 'note':
          noteLines++;
          final itemId = j['itemId'] as String;
          if (j.containsKey('eventId')) {
            events.add(_lineEvent(j, JpEventKind.note,
                {'itemId': itemId, 'note': j['note'] as String?}));
          } else {
            notes[itemId] = j['note'] as String;
          }
        case 'discuss':
          discussLines++;
          if (j.containsKey('eventId')) {
            events.add(_lineEvent(j, JpEventKind.discuss, {
              'itemId': j['itemId'] as String,
              if (j['note'] != null) 'note': j['note'] as String,
              if (j['cleared'] == true) 'cleared': true,
            }));
          } else {
            final mark = DiscussMark.fromJson(j);
            discuss[mark.itemId] = mark;
          }
        case 'speak_score':
        case 'last_lesson':
          eventLines++;
          final body = j['body'];
          if (body is! Map) throw const FormatException('no body');
          events.add(_lineEvent(j, JpEventKind.fromWire(j['type']),
              Map<String, dynamic>.from(body)));
        default:
          throw FormatException('unknown type ${j['type']}');
      }
    } catch (e) {
      throw FormatException('study export: line ${lines[i].no}: $e');
    }
  }
  if (header['attempts'] != attempts.length ||
      header['seeds'] != seeds.length ||
      header['notes'] != noteLines ||
      (header['discuss'] ?? 0) != discussLines ||
      (header['events'] ?? 0) != eventLines) {
    throw const FormatException(
        'study export: the line counts disagree with the header');
  }
  return StudyLog.resolved(
      attempts: attempts,
      seeds: seeds,
      legacyNotes: notes,
      legacyDiscuss: discuss,
      events: events);
}

/// The store's log as an export file's text.
Future<String> exportStudy(JpStore store,
        {required DateTime exportedAt}) async =>
    encodeStudyExport(await store.exportLog(), exportedAt: exportedAt);

/// Replaces the store's record with the export [text] and rebuilds every state through the
/// replay. Throws a [FormatException], and changes nothing, when [text] cannot be read.
Future<ReplayResult> importStudy(JpStore store, String text,
    {required ItemLookup lookup, required Scheduler scheduler}) async {
  final log = decodeStudyExport(text);
  return store.importLog(log, lookup, scheduler);
}

// --- the v2 migration ----------------------------------------------------------

/// The store flag set once the v2 keys are imported.
const String kV2MigrationFlag = 'migration.v2';

/// The v2 grammar card's self-check keys: `SelfCheck` in jp_study_kit.dart.
const String kV2SelfCheckPrefix = 'jp.selfcheck.';

/// The v2 self-check values.
const String kV2ReviewNeeded = 'review_needed';
const String kV2CanUseIt = 'can_use_it';

/// The session id of the imported Say-it history.
const String kV2MigrationSession = 'v2-migration';

/// What the v2 migration imported. All zero when it had already run.
class V2MigrationReport {
  const V2MigrationReport({
    this.alreadyRan = false,
    this.dueToday = 0,
    this.notes = 0,
    this.sayIt = 0,
    this.alreadyLogged = 0,
    this.skipped = 0,
  });

  final bool alreadyRan;

  /// Points marked review_needed, now due today.
  final int dueToday;

  /// Points marked can_use_it, kept as notes.
  final int notes;

  /// Spoken attempts imported as Say-it history.
  final int sayIt;

  /// Spoken attempts a run cut short had already logged, left as they are.
  final int alreadyLogged;

  /// Keys or attempts left out: an unknown point, an unknown value, a sentence no point has,
  /// or the whole score log when it cannot be read.
  final int skipped;
}

/// Spoken sentence (its hiragana, as the speak drill logs it) to the grammar point and the
/// probe it came from, built with the drill's own `lessonSentences`. The first point wins
/// where two points share a sentence.
Map<String, ({String itemId, String probeId})> sayItSentences(
    Map<String, dynamic> grammar) {
  final out = <String, ({String itemId, String probeId})>{};
  void add(Map<String, dynamic> point, String key, String probeId,
      Map<String, dynamic> one) {
    final lesson = {
      'points': [
        {
          'id': point['id'],
          key: [one]
        }
      ]
    };
    for (final s in lessonSentences(lesson)) {
      out.putIfAbsent(
          s.kana, () => (itemId: point['id'] as String, probeId: probeId));
    }
  }

  for (final lesson in (grammar['grammar'] as List? ?? const [])) {
    for (final p in ((lesson as Map)['points'] as List? ?? const [])) {
      final point = Map<String, dynamic>.from(p as Map);
      final examples = (point['examples'] as List? ?? const []);
      for (var i = 0; i < examples.length; i++) {
        add(point, 'examples', 'ex$i',
            Map<String, dynamic>.from(examples[i] as Map));
      }
      final practice = (point['practice'] as List? ?? const []);
      for (var i = 0; i < practice.length; i++) {
        add(point, 'practice', 'p$i',
            Map<String, dynamic>.from(practice[i] as Map));
      }
    }
  }
  return out;
}

/// The grade a logged spoken attempt earns. An unverified check is never wrong: Got it on it is
/// a self override, and anything else is unscored.
Grade sayItGrade(SpeakAttempt a) => switch (a.verdict) {
      Judgement.correct =>
        gradeAnswer(outcome: Outcome.right, selfGraded: false),
      Judgement.close => gradeAnswer(outcome: Outcome.close, selfGraded: false),
      Judgement.wrong => gradeAnswer(outcome: Outcome.wrong, selfGraded: false),
      Judgement.unverified => gradeAnswer(
          outcome: Outcome.none,
          selfGraded: false,
          selfOverride: a.selfMark == true),
    };

/// Imports the v2 study keys into [store] once (see the file comment). [known] says whether the
/// catalog has a grammar point id; [grammar] is the decoded `jp_grammar.json`. The keys stay.
Future<V2MigrationReport> migrateV2Keys(
  JpStore store,
  SharedPreferences prefs, {
  required Map<String, dynamic> grammar,
  required bool Function(String itemId) known,
  required int today,
  required DateTime nowUtc,
}) async {
  if (await store.meta(kV2MigrationFlag) != null) {
    return const V2MigrationReport(alreadyRan: true);
  }
  var dueToday = 0, notes = 0, sayIt = 0, alreadyLogged = 0, skipped = 0;

  final seeds = <SeedEvent>[];
  for (final key in prefs.getKeys().toList()..sort()) {
    if (!key.startsWith(kV2SelfCheckPrefix)) continue;
    final id = key.substring(kV2SelfCheckPrefix.length);
    final value = prefs.get(key);
    if (!known(id)) {
      skipped++;
    } else if (value == kV2ReviewNeeded) {
      seeds.add(SeedEvent(itemId: id, dueDay: today, atUtc: nowUtc));
      dueToday++;
    } else if (value == kV2CanUseIt) {
      await store.setNote(id, kNoteCanUseIt);
      notes++;
    } else {
      skipped++;
    }
  }
  if (seeds.isNotEmpty) await store.appendSeeds(seeds);

  final sentences = sayItSentences(grammar);
  final raw = prefs.get(SpeakScoreLog.prefsKey);
  final list = raw == null ? const <Object?>[] : _decodeList(raw);
  if (list == null) {
    // The whole score log is unreadable: counted, never read as empty (S4).
    skipped++;
  }
  // A run cut short before the flag logged some of these already (one transaction each).
  final logged = {
    for (final a in await store.attempts())
      if (a.source == Source.sayIt) _sayItKey(a.itemId, a.probeId, a.atUtc)
  };
  for (final entry in list ?? const <Object?>[]) {
    final a = SpeakAttempt.fromJson(entry);
    final target = a == null ? null : sentences[a.sentence];
    if (a == null ||
        target == null ||
        !known(target.itemId) ||
        a.at.year < 2000) {
      skipped++;
      continue;
    }
    if (logged.contains(_sayItKey(target.itemId, target.probeId, a.at))) {
      alreadyLogged++;
      continue;
    }
    final grade = sayItGrade(a);
    await store.appendAttempt(Attempt(
      itemId: target.itemId,
      probeId: target.probeId,
      template: kSayItTemplate,
      production: true,
      selfGraded: false,
      atUtc: a.at.toUtc(),
      localDay: localDay(a.at),
      grade: grade,
      rating: fsrsRatingFor(grade),
      wasDue: false,
      source: Source.sayIt,
      sessionId: kV2MigrationSession,
    ));
    sayIt++;
  }

  await store.putMeta(kV2MigrationFlag, nowUtc.toUtc().toIso8601String());
  return V2MigrationReport(
      dueToday: dueToday,
      notes: notes,
      sayIt: sayIt,
      alreadyLogged: alreadyLogged,
      skipped: skipped);
}

/// The identity of one imported Say-it attempt: its point, probe and instant.
String _sayItKey(String itemId, String probeId, DateTime at) =>
    '$itemId\u0000$probeId\u0000${at.toUtc().toIso8601String()}';

/// The score log's entries, or null when the blob is not a string, not JSON or not a list.
List<Object?>? _decodeList(Object raw) {
  if (raw is! String) return null;
  try {
    final v = jsonDecode(raw);
    return v is List ? v : null;
  } catch (_) {
    return null;
  }
}
