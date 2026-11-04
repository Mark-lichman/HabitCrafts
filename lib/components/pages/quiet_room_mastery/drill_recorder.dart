// HAND-WRITTEN. Not FlutterFlow output, so S3 has nothing to adopt.
//
// Writes the attempts of the free practice screens (Task 11): the speak drill, the
// conjugation drill, the verb pairs and the reference tables. One recorder per screen
// visit, so its attempts share a session id.
//
// Where an answer counts (D23, PIN-14): an item whose due day (its schedule, or its seed when
// it has no schedule yet) has arrived is a `review`. Any other item, a New one included, is
// `early`: a clear changes nothing and a wrong counts, so a free drill never pulls an item
// into the queue ahead of the daily intake (PIN-6). The speak drill is the Say-it track and
// writes `sayIt`, which never moves the schedule or the mastery state (D4).
//
// The screens never wait on a write and never fail because of one: a store that cannot open
// (no SQLite in a widget test, say) or a write that throws drops that attempt silently. The
// writes run one after another, so two quick answers on one item never read the same
// before-state.

import 'dart:async';

import 'attempt.dart';
import 'fsrs.dart';
import 'item_catalog.dart';
import 'jp_store.dart';
import 'jp_store_sqlite.dart' show openJpStore;
import 'local_day.dart';
import 'scheduler.dart';

/// The app's one study store, opened on first use and shared by every screen. A failed open
/// is forgotten, so the next write tries again.
Future<JpStore> sharedJpStore() {
  final open = _shared ??= openJpStore();
  open.then((_) {}, onError: (Object _) => _shared = null);
  return open;
}

Future<JpStore>? _shared;

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

  /// Settles once every write queued so far has landed or been dropped.
  Future<void> get idle => _tail;

  /// Queues one answer. Never throws; the attempt as logged, or null when it was dropped.
  Future<Attempt?> record(DrillAnswer answer) {
    final run = _tail.then((_) => _write(answer)).then<Attempt?>((a) => a,
        onError: (Object _) => null);
    _tail = run.then((_) {});
    return run;
  }

  Future<Attempt?> _write(DrillAnswer a) async {
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
