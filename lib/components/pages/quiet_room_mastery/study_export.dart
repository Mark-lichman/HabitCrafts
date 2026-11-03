// The study record in and out: the JSON Lines export, its import through the replay, and the
// one-time import of the v2 study keys (Task 8).
//
// Export format, one JSON object per line:
//   line 1   the header: {"format": "habitcrafts.jp.study", "version": 1, "exportedAtUtc",
//            "attempts": n, "seeds": n, "notes": n}
//   then     {"type": "seed", ...SeedEvent}, {"type": "attempt", ...Attempt} and
//            {"type": "note", "itemId", "note"}, seeds first, each log kind in log order and
//            the notes by item id, so the same record exports the same bytes from either store.
// Reading it back replaces the store's log and rebuilds every state from it (JpStore.importLog),
// so an export is also a backup and the input for fitting FSRS offline (A1).
//
// The v2 migration reads two SharedPreferences keys and leaves both in place for one release:
//   * `jp.selfcheck.<pointId>`: `review_needed` marks the point due today (a seed event, no
//     attempt); `can_use_it` is kept as the item's note and schedules nothing;
//   * `jp.speak.scores`: each spoken attempt becomes a Say-it attempt on the grammar point whose
//     sentence it was. Say-it never counts toward mastery and never moves the schedule (D4).
// It runs once per store: a flag in the store's meta records it.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../quiet_room_grammar/quiet_room_speak_widget.dart'
    show SpeakAttempt, SpeakScoreLog, lessonSentences;
import '../quiet_room_practice/speech_service.dart' show Judgement;
import 'attempt.dart';
import 'item_catalog.dart' show kSayItTemplate;
import 'jp_store.dart';
import 'local_day.dart';
import 'scheduler.dart';

/// The export header's `format`.
const String kStudyExportFormat = 'habitcrafts.jp.study';

/// The export format version this build writes and reads.
const int kStudyExportVersion = 1;

/// Writes [log] as JSON Lines with a header line.
String encodeStudyExport(StudyLog log, {required DateTime exportedAt}) {
  final lines = <String>[
    jsonEncode({
      'format': kStudyExportFormat,
      'version': kStudyExportVersion,
      'exportedAtUtc': exportedAt.toUtc().toIso8601String(),
      'attempts': log.attempts.length,
      'seeds': log.seeds.length,
      'notes': log.notes.length,
    }),
    for (final s in log.seeds) jsonEncode({'type': 'seed', ...s.toJson()}),
    for (final a in log.attempts)
      jsonEncode({'type': 'attempt', ...a.toJson()}),
    for (final e
        in log.notes.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
      jsonEncode({'type': 'note', 'itemId': e.key, 'note': e.value}),
  ];
  return '${lines.join('\n')}\n';
}

/// Reads an export written by [encodeStudyExport]. Throws a [FormatException] naming the line
/// for a missing or foreign header, a newer version, an unknown line type, an unreadable line,
/// an attempt whose rating no [SrsRating] has, or counts that disagree with the header.
StudyLog decodeStudyExport(String text) {
  final lines = const LineSplitter()
      .convert(text)
      .where((l) => l.trim().isNotEmpty)
      .toList();
  if (lines.isEmpty) throw const FormatException('study export: empty');
  Map<String, dynamic> parse(int i) {
    try {
      return jsonDecode(lines[i]) as Map<String, dynamic>;
    } catch (_) {
      throw FormatException('study export: line ${i + 1} is not a JSON object');
    }
  }

  final header = parse(0);
  if (header['format'] != kStudyExportFormat) {
    throw const FormatException('study export: line 1 is not the header');
  }
  final version = header['version'];
  if (version is! int || version > kStudyExportVersion) {
    throw FormatException('study export: version $version is not readable');
  }
  final attempts = <Attempt>[];
  final seeds = <SeedEvent>[];
  final notes = <String, String>{};
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
          notes[j['itemId'] as String] = j['note'] as String;
        default:
          throw FormatException('unknown type ${j['type']}');
      }
    } catch (e) {
      throw FormatException('study export: line ${i + 1}: $e');
    }
  }
  if (header['attempts'] != attempts.length ||
      header['seeds'] != seeds.length ||
      header['notes'] != notes.length) {
    throw const FormatException(
        'study export: the line counts disagree with the header');
  }
  return StudyLog(attempts: attempts, seeds: seeds, notes: notes);
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
    this.skipped = 0,
  });

  final bool alreadyRan;

  /// Points marked review_needed, now due today.
  final int dueToday;

  /// Points marked can_use_it, kept as notes.
  final int notes;

  /// Spoken attempts imported as Say-it history.
  final int sayIt;

  /// Keys or attempts left out: an unknown point, an unknown value, a sentence no point has.
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
  var dueToday = 0, notes = 0, sayIt = 0, skipped = 0;

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
  final list = raw is String ? _decodeList(raw) : const <Object?>[];
  for (final entry in list) {
    final a = SpeakAttempt.fromJson(entry);
    final target = a == null ? null : sentences[a.sentence];
    if (a == null ||
        target == null ||
        !known(target.itemId) ||
        a.at.year < 2000) {
      skipped++;
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
      dueToday: dueToday, notes: notes, sayIt: sayIt, skipped: skipped);
}

List<Object?> _decodeList(String raw) {
  try {
    final v = jsonDecode(raw);
    return v is List ? v : const [];
  } catch (_) {
    return const [];
  }
}
