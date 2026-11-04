// HAND-WRITTEN. Not FlutterFlow output, so S3 has nothing to adopt.
//
// Writes the attempts of the free practice screens (Task 11): the speak drill, the
// conjugation drill, the verb pairs and the reference tables. One recorder per screen
// visit, so its attempts share a session id.
//
// Where an answer counts (D23, PIN-14): an item whose due day (its schedule, or its seed when
// it has no schedule yet) has arrived is a `review`. Any other item, a New one included, is
// `early`: a clear changes nothing, so a clear never pulls an item into the queue ahead of
// the daily intake, and a wrong counts and makes the item due tomorrow (PIN-14). The speak
// drill is the Say-it track and writes `sayIt`, which never moves the schedule or the
// mastery state (D4).
//
// With no store injected, a recorder writes to the app's one shared store (`sharedJpStore`),
// the same one the grammar and lesson screens use, so the phone holds one SQLite handle.
//
// The screens never wait on a write and never fail because of one. A store that cannot open
// (no SQLite in a unit test, say) or a write that throws loses that attempt: the loss goes
// to FlutterError.reportError, so the app's handler records it (S4), and `record` resolves
// null so the screen can tell the learner. A failed shared open is not kept, so the next
// answer tries the open again. The writes run one after another, so two quick
// answers on one item never read the same before-state.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'attempt.dart';
import 'fsrs.dart';
import 'item_catalog.dart';
import 'jp_store.dart';
import 'jp_store_sqlite.dart' show sharedJpStore;
import 'local_day.dart';
import 'scheduler.dart';

/// What a screen shows when an answer did not reach the study record (S4: the learner
/// sees it). Shared by the drills and the speak drill so a lost answer reads one way.
const String kAnswerNotSaved = 'That answer was not saved.';

/// The catalog's lookup, loaded once per app run.
Future<ItemLookup> catalogLookup() async => (await ItemCatalog.load()).byId;

/// What a screen knows about one answer; [AttemptRecorder] adds the time, the due state and
/// the source.
class DrillAnswer {
  const DrillAnswer({
    required this.itemId,
    required this.probeId,
    required this.template,
    required this.grade,
    this.production = false,
    this.selfGraded = true,
    this.hintLevel = 0,
    this.revealed = false,
    this.sayIt = false,
    this.atUtc,
  });

  final String itemId;
  final String probeId;
  final String template;
  final Grade grade;
  final bool production;
  final bool selfGraded;
  final int hintLevel;
  final bool revealed;

  /// The spoken sentence track (D4): logged as `Source.sayIt`, never counted.
  final bool sayIt;

  /// The answer's instant; null means now.
  final DateTime? atUtc;
}

class AttemptRecorder {
  AttemptRecorder({
    Future<JpStore> Function()? store,
    Future<ItemLookup> Function()? items,
    this.scheduler = const FsrsScheduler(),
    this.clock = const SystemClock(),
    String? sessionId,
  })  : _store = store ?? sharedJpStore,
        _items = items ?? catalogLookup,
        sessionId = sessionId ??
            'drill-${DateTime.now().toUtc().microsecondsSinceEpoch}';

  /// A recorder on [store], with [lookup] for the mastery rule. For tests and the simulator.
  factory AttemptRecorder.on(JpStore store,
          {ItemLookup? lookup, Clock clock = const SystemClock()}) =>
      AttemptRecorder(
        store: () async => store,
        items: () async => lookup ?? (_) => null,
        clock: clock,
        sessionId: 'test',
      );

  final Future<JpStore> Function() _store;
  final Future<ItemLookup> Function() _items;
  final Scheduler scheduler;
  final Clock clock;
  final String sessionId;

  Future<void> _tail = Future<void>.value();

  /// Settles once every write queued so far has landed or been lost.
  Future<void> get idle => _tail;

  /// Queues one answer. Never throws. Resolves to the attempt as logged, or to null when
  /// the write was lost: the loss has gone to [FlutterError.reportError] by then, and the
  /// screen shows the learner that the answer was not saved.
  Future<Attempt?> record(DrillAnswer answer) {
    final run = _tail.then((_) => _write(answer));
    _tail = run.then((_) {});
    return run;
  }

  /// Writes [a]. Catches every failure, so the queue after it still runs (S4: the failure
  /// is reported, never swallowed).
  Future<Attempt?> _write(DrillAnswer a) async {
    try {
      return await _writeOrThrow(a);
    } catch (e, s) {
      FlutterError.reportError(FlutterErrorDetails(
          exception: e,
          stack: s,
          library: 'quiet room drills',
          context:
              ErrorDescription('while logging the attempt on ${a.itemId}')));
      return null;
    }
  }

  Future<Attempt> _writeOrThrow(DrillAnswer a) async {
    final store = await _store();
    final lookup = await _items();
    final at = a.atUtc ?? clock.now();
    final day = localDay(at);
    final due = (await store.srs(a.itemId))?.dueDay ??
        (await store.item(a.itemId))?.seedDueDay;
    final wasDue = due != null && due <= day;
    final outcome = await store.recordAnswer(
      Attempt(
        itemId: a.itemId,
        probeId: a.probeId,
        template: a.template,
        production: a.production,
        selfGraded: a.selfGraded,
        atUtc: at.toUtc(),
        localDay: day,
        grade: a.grade,
        rating: fsrsRatingFor(a.grade),
        hintLevel: a.hintLevel,
        revealed: a.revealed,
        wasDue: wasDue,
        source: a.sayIt
            ? Source.sayIt
            : wasDue
                ? Source.review
                : Source.early,
        sessionId: sessionId,
      ),
      item: lookup(a.itemId),
      scheduler: scheduler,
    );
    return outcome.attempt;
  }
}
