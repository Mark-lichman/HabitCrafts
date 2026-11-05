// HAND-WRITTEN. Not FlutterFlow output, so S3 has nothing to adopt.
//
// The Review session (plan 2026-11-02, Task 18). [SessionWidget] walks one local day's
// [DayPlan] one entry per screen, under a line naming the section and the position in it
// ("Due · 12 of 42"). Each entry shows a probe widget (probe_widgets.dart); the probe hands on a
// graded draft, and the session writes it through `JpStore.recordAnswer` at answer time, then
// shows the verdict card:
//
// | grade                  | card                                                   |
// |------------------------|--------------------------------------------------------|
// | clear, the 4th that counts, or a Shaky item's regain | Mastered                 |
// | clear                  | Clear, with the new interval                           |
// | hinted                 | Right with a hint, no credit (PIN-3)                   |
// | self                   | Marked as got it, no credit (PIN-3)                    |
// | wrong                  | Not this time; the item comes back in about 10 minutes |
// | unscored               | Not counted; the entry moves to the end of its section |
//
// The attempt copies the entry's `wasDue` (plan_builder.dart): a New or stretch entry is due, so
// its clear is the first of the four (operator ruling ASK-6), and a re-ask is not due. The source
// is the entry's (review or keep-sharp); a Say-it draft is written as `sayIt`.
//
// The budget (PIN-5, PIN-11): the running estimate is the sum of the per-kind estimates of the
// entries answered so far (the plan's own prices, A2). A wrong is re-asked through
// `DayPlan.afterWrong`, about 10 minutes of estimated answers later. When the estimate reaches
// the 15-minute target with entries left, the soft stop offers Stop and Keep going. The session
// ends before an entry that would pass the 20-minute ceiling: what is left stays due, and the
// next plan picks it up tomorrow. Nothing runs past the ceiling except the catch-up block, and
// only on a tap.
//
// After every answer the day's `DayRecord` gets the plan (with its re-asks) and the position,
// so a relaunch resumes where the session stopped (relaunch.dart); a position above 0 also
// makes the day a session day for the days missed (ASK-5). The end marks the record completed.
//
// A resume carries the budget on, never restarts it (PIN-5): the running estimate is rebuilt
// from the stored plan's entries before the position plus each entry skipped once, which
// `afterUnscored` moved past the position (the same entries the live estimate summed), so the
// soft stop and the ceiling fall where they would have without the relaunch. A catch-up block
// found in the stored plan was taken: its ceiling lift and its end come back too, over the
// entries the tap inserted (a re-ask of a block item is not one). The end card's counts come
// from the day's review-session attempts in the store, and the mastered-today list from the
// mastery states dated today, so a resume shows the day, not the sitting. An offer whose
// entries are already in the plan was taken, so it never shows twice.
//
// Every card button leaves its card before its action runs (`_tap`), so a double tap inside
// one store write runs the action once: a second Catch up never ends the block unasked, and a
// second Next at the target never skips the soft stop.
//
// The end card is quiet: the day's counts, the items mastered today, the 14 dots over the days
// whose session completed (`recentDays`), and up to three offers, each only on a tap:
//   * One more (10): the next ten planned entries, while the ceiling leaves room;
//   * Catch up: 10 more: the plan's catch-up block past the ceiling, only when the plan's
//     `catchUpOffer` holds and the session reached the ceiling or finished the plan (PIN-12);
//   * 4 more new: the plan's stretch, only when `stretchOffer` holds, every entry (re-asks
//     included) is answered, and the ceiling leaves room for it (PIN-6).

import 'dart:async';

import 'package:flutter/material.dart';

import '/flutter_flow/quiet_room.dart';
import '../quiet_room_grammar/jp_study_kit.dart';
import '../quiet_room_practice/speech_service.dart';
import '../quiet_room_today/streak.dart';
import 'attempt.dart';
import 'drill_recorder.dart' show DrillAnswer, kAnswerNotSaved;
import 'fsrs.dart';
import 'item_catalog.dart';
import 'jp_store.dart';
import 'local_day.dart';
import 'mastery_rule.dart';
import 'plan_builder.dart';
import 'probe_widgets.dart';
import 'scheduler.dart';

/// Entries one tap of "One more" adds, inside the ceiling.
const int kOneMoreBlock = 10;

/// Days of dots on the end card.
const int kEndCardDots = 14;

/// The prefix of a session id the session makes for itself. A resume counts the day's
/// attempts under this prefix on the end card.
const String kReviewSessionPrefix = 'review-';

/// The learner-facing name of a plan section.
String sectionLabel(PlanSection s) => switch (s) {
      PlanSection.warmUp => 'Warm-up',
      PlanSection.repair => 'Repair',
      PlanSection.due => 'Due',
      PlanSection.keepSharp => 'Keep-sharp',
      PlanSection.newItems => 'New',
    };

/// The line above an entry: its section and its place in it, "Due · 12 of 42".
String sectionPosition(DayPlan plan, int index) {
  final section = plan.entries[index].section;
  var n = 0, of = 0;
  for (var i = 0; i < plan.entries.length; i++) {
    if (plan.entries[i].section != section) continue;
    of++;
    if (i <= index) n++;
  }
  return '${sectionLabel(section)} · $n of $of';
}

/// "1 day" or "N days".
String _days(int n) => n == 1 ? '1 day' : '$n days';

/// What a probe needs to ask one entry.
class SessionProbeRequest {
  const SessionProbeRequest({
    required this.item,
    required this.state,
    required this.answered,
    required this.onAnswer,
  });

  final ItemDef item;

  /// The item's mastery state before this answer, for the pill.
  final MasteryState state;

  /// The item's attempts so far, so a builder can rotate its probes.
  final int answered;

  final ProbeAnswered onAnswer;
}

/// Builds the probe for one entry. The session keys the result per presentation.
typedef SessionProbeBuilder = Widget Function(
    BuildContext context, SessionProbeRequest request);

/// The probe widgets the app uses: one per item kind, rotating through the item's scored
/// probes. [grammar] is the decoded `jp_grammar.json`, for a grammar item's options, accepted
/// forms and hint.
SessionProbeBuilder standardProbeBuilder(
    {required Map<String, dynamic> grammar, SpeechService? speech}) {
  final practice = <String, List<Map<String, dynamic>>>{};
  for (final lesson in (grammar['grammar'] as List? ?? const [])) {
    for (final point in ((lesson as Map)['points'] as List? ?? const [])) {
      final p = Map<String, dynamic>.from(point as Map);
      practice[p['id'] as String] = [
        for (final x in (p['practice'] as List? ?? const []))
          Map<String, dynamic>.from(x as Map)
      ];
    }
  }
  return (context, r) {
    final item = r.item;
    final probes = item.scoredProbes.toList();
    final probe = probes[r.answered % probes.length];
    switch (item.kind) {
      case ItemKind.grammar:
        final at = int.tryParse(probe.id.substring(1));
        final rows = practice[item.id] ?? const [];
        final raw = at != null && at < rows.length ? rows[at] : null;
        final options = (raw?['options'] as List?)?.cast<String>();
        if (probe.template == 'choose' && options != null) {
          return ChooseProbe(
              item: item,
              probe: probe,
              state: r.state,
              options: options,
              onAnswer: r.onAnswer);
        }
        return TypedFillProbe(
            item: item,
            probe: probe,
            state: r.state,
            checkItem: raw ?? {'answer': probe.answer},
            hint: raw?['hint'] as String?,
            onAnswer: r.onAnswer);
      case ItemKind.particle:
        return TypedFillProbe(
            item: item,
            probe: probe,
            state: r.state,
            checkItem: {'answer': probe.answer},
            onAnswer: r.onAnswer);
      case ItemKind.word:
        return WordRecallProbe(
            item: item,
            probe: probe,
            state: r.state,
            speech: speech ?? SpeechService.instance,
            imageAsset: wordImageAsset(item.id),
            onAnswer: r.onAnswer);
      case ItemKind.conjugation:
        return ConjugationProbe(
            item: item, probe: probe, state: r.state, onAnswer: r.onAnswer);
      case ItemKind.pair:
        return PairProbe(
            item: item, probe: probe, state: r.state, onAnswer: r.onAnswer);
      case ItemKind.tableRow:
        return TableCellProbe(
            item: item, probe: probe, state: r.state, onAnswer: r.onAnswer);
    }
  };
}

/// Why the session ended.
enum SessionEnd { finished, stopped, ceiling }

enum _Phase { loading, asking, saving, verdict, softStop, end }

/// The Review session over one day's [plan].
class SessionWidget extends StatefulWidget {
  const SessionWidget({
    super.key,
    required this.plan,
    required this.store,
    required this.clock,
    required this.catalog,
    this.position = 0,
    this.probeBuilder,
    this.scheduler = const FsrsScheduler(),
    this.sessionId,
    this.onClose,
  });

  final DayPlan plan;
  final JpStore store;
  final Clock clock;
  final ItemCatalog catalog;

  /// The entry to start on: the stored `DayRecord.position` on a resume. The budget spent
  /// before it is rebuilt from the plan (`_spentBefore`): the entries before it plus each
  /// entry a skip moved past it.
  final int position;

  /// Null loads [standardProbeBuilder] over the shipped grammar.
  final SessionProbeBuilder? probeBuilder;
  final Scheduler scheduler;

  /// Null makes an id under [kReviewSessionPrefix]. An id outside the prefix is left out of
  /// a resume's end-card counts.
  final String? sessionId;

  /// Called by the end card's Done; null pops the route.
  final VoidCallback? onClose;

  @override
  State<SessionWidget> createState() => _SessionWidgetState();
}

class _SessionWidgetState extends State<SessionWidget> {
  late DayPlan _plan;
  late int _index;
  late final String _sessionId;
  SessionProbeBuilder? _builder;

  _Phase _phase = _Phase.loading;

  /// The estimated seconds answered so far (PIN-5).
  int _spent = 0;

  /// Seconds the catch-up block lifts the ceiling by, once taken (PIN-12).
  int _lift = 0;
  bool _softStopSeen = false;
  bool _completed = false;

  /// One more (10) ends again at this index.
  int? _stopAt;
  SessionEnd? _end;

  // The entry on screen.
  MasteryState? _state;
  int _answered = 0;
  int _presentation = 0;
  DateTime? _shownAt;

  // The verdict on screen.
  Grade? _grade;
  bool _lost = false;
  bool _justMastered = false;

  /// The Mastered just shown is a Shaky item's regain, not the fourth clear.
  bool _regained = false;
  bool _reasked = false;
  int? _interval;

  // The day's counts.
  final Map<Grade, int> _counts = {};

  /// The items mastered today, by id, and their titles in the order found. Two items may
  /// share a title (a word listed twice, PIN-16), so the end card lists each item.
  final Set<String> _masteredIds = {};
  final List<String> _masteredToday = [];
  List<bool> _dots = const [];

  QueueEntry get _entry => _plan.entries[_index];
  int get _ceiling => _plan.ceilingSeconds + _lift;

  @override
  void initState() {
    super.initState();
    _plan = widget.plan;
    _index = widget.position.clamp(0, _plan.entries.length);
    _spent = _spentBefore(_plan.entries.take(_index), _plan.entries);
    _resumeCatchUp();
    _sessionId = widget.sessionId ??
        '$kReviewSessionPrefix${_plan.day}-${widget.clock.now().toUtc().microsecondsSinceEpoch}';
    _start();
  }

  Future<void> _start() async {
    _builder = widget.probeBuilder ??
        standardProbeBuilder(grammar: await JpGrammarData.load());
    await _loadDayTally();
    if (!mounted) return;
    await _next();
  }

  /// Whether the entry can be asked: the catalog knows the item and it has a scored probe.
  bool _askable(QueueEntry e) {
    final item = widget.catalog.byId(e.itemId);
    return item != null && item.scoredProbes.isNotEmpty;
  }

  int _sumCost(Iterable<QueueEntry> entries) =>
      entries.fold(0, (sum, e) => sum + e.costSeconds);

  /// The estimate as the live session summed it over the entries [answered] (those before a
  /// position): every askable one, plus the skip of each `requeued` entry among [candidates].
  /// `requeued` is set on the skipped entry itself and never inherited (`afterWrong` clears
  /// it on a re-ask copy), so every requeued entry, a re-ask included, was answered one more
  /// time than its place says: a skip that `afterUnscored` moved past the position adds its
  /// cost once here, and one moved to a place before the position adds it twice, as the live
  /// session did.
  int _spentBefore(
          Iterable<QueueEntry> answered, Iterable<QueueEntry> candidates) =>
      _sumCost(answered.where(_askable)) +
      _sumCost(candidates.where((e) => e.requeued && _askable(e)));

  /// The entries of [more] not already in the plan.
  List<QueueEntry> _unplanned(List<QueueEntry> more) {
    final planned = {for (final e in _plan.entries) e.itemId};
    return [
      for (final e in more)
        if (!planned.contains(e.itemId)) e
    ];
  }

  /// Whether any entry of [more] is in the plan: an offer taken.
  bool _anyPlanned(List<QueueEntry> more) =>
      more.length != _unplanned(more).length;

  /// A catch-up block in the stored plan was taken (PIN-12): the ceiling lift and the block's
  /// end come back as `_catchUp` set them, from the entries before the block. The block is
  /// the entries the tap inserted: a re-ask of a block item shares its id and is not one. The
  /// skips counted into the spend before the tap leave out every entry with a block id: a
  /// block item, or its re-ask, was first asked after the tap, so its skip came after it too.
  void _resumeCatchUp() {
    final ids = {for (final e in _plan.catchUpEntries) e.itemId};
    bool inBlock(QueueEntry e) => ids.contains(e.itemId) && !e.reask;
    final entries = _plan.entries;
    final first = entries.indexWhere(inBlock);
    if (first < 0) return;
    final block = entries.where(inBlock).toList();
    final before = _spentBefore(
        entries.take(first), entries.where((e) => !ids.contains(e.itemId)));
    _liftCeiling(spent: before, block: block);
    _stopAt = first + block.length;
  }

  /// Moves the ceiling by the block's cost, from where the session stands.
  void _liftCeiling({required int spent, required List<QueueEntry> block}) {
    final from = spent > _ceiling ? spent : _ceiling;
    _lift = from - _plan.ceilingSeconds + _sumCost(block);
  }

  /// The end card's day: the day's answers written under [kReviewSessionPrefix], and the
  /// items whose mastery is dated today. Empty on a first start.
  Future<void> _loadDayTally() async {
    final day = _plan.day;
    for (final a in await widget.store.attempts()) {
      if (a.localDay != day) continue;
      if (!a.sessionId.startsWith(kReviewSessionPrefix)) continue;
      _counts[a.grade] = (_counts[a.grade] ?? 0) + 1;
    }
    for (final m in (await widget.store.allMastery()).values) {
      if (m.masteredOn != day) continue;
      final item = widget.catalog.byId(m.itemId);
      if (item != null) _noteMastered(item);
    }
  }

  /// Lists [item] on the end card once, by id.
  void _noteMastered(ItemDef item) {
    if (_masteredIds.add(item.id)) _masteredToday.add(item.title);
  }

  /// Shows the entry at [_index], the soft stop, or the end.
  Future<void> _next() async {
    final entries = _plan.entries;
    if (_index >= entries.length) return _finish(SessionEnd.finished);
    if (_stopAt != null && _index >= _stopAt!) {
      return _finish(SessionEnd.stopped);
    }
    if (_spent + entries[_index].costSeconds > _ceiling) {
      return _finish(SessionEnd.ceiling);
    }
    if (!_softStopSeen && _spent >= _plan.targetSeconds) {
      _softStopSeen = true;
      setState(() => _phase = _Phase.softStop);
      return;
    }
    if (!_askable(_entry)) {
      // An id this catalog no longer knows: nothing to ask, so it stays due.
      _index++;
      return _next();
    }
    final item = widget.catalog.byId(_entry.itemId)!;
    final state =
        await widget.store.mastery(item.id) ?? MasteryState.initial(item.id);
    final answered = (await widget.store.attempts(itemId: item.id)).length;
    if (!mounted) return;
    setState(() {
      _state = state;
      _answered = answered;
      _presentation++;
      _shownAt = widget.clock.now();
      _grade = null;
      _phase = _Phase.asking;
    });
  }

  Future<void> _onAnswer(DrillAnswer d) async {
    if (_phase != _Phase.asking) return;
    final entry = _entry;
    final item = widget.catalog.byId(entry.itemId)!;
    final before = _state ?? MasteryState.initial(item.id);
    setState(() => _phase = _Phase.saving);
    final now = widget.clock.now();
    final shown = _shownAt ?? now;
    AnswerOutcome? outcome;
    try {
      outcome = await widget.store.recordAnswer(
        Attempt(
          itemId: item.id,
          probeId: d.probeId,
          template: d.template,
          production: d.production,
          selfGraded: d.selfGraded,
          atUtc: now.toUtc(),
          localDay: localDay(now),
          grade: d.grade,
          rating: fsrsRatingFor(d.grade),
          hintLevel: d.hintLevel,
          revealed: d.revealed,
          wasDue: entry.wasDue,
          source: d.sayIt ? Source.sayIt : entry.source,
          durationMs: now.difference(shown).inMilliseconds.clamp(0, 1 << 31),
          sessionId: _sessionId,
        ),
        item: item,
        scheduler: widget.scheduler,
      );
    } catch (e, s) {
      FlutterError.reportError(FlutterErrorDetails(
          exception: e,
          stack: s,
          library: 'quiet room session',
          context: ErrorDescription('while logging the answer on ${item.id}')));
    }

    final grade = d.grade;
    var next = _plan;
    var nextIndex = _index + 1;
    var reasked = false;
    if (outcome != null) {
      if (grade == Grade.wrong) {
        next = _plan.afterWrong(_index);
        reasked = !identical(next, _plan);
      } else if (grade == Grade.unscored) {
        next = _plan.afterUnscored(_index);
        // A moved entry leaves the next one at this index.
        if (!identical(next, _plan)) nextIndex = _index;
      }
      _counts[grade] = (_counts[grade] ?? 0) + 1;
    }
    final mastery = outcome?.mastery;
    final justMastered = mastery != null &&
        mastery.status == MasteryStatus.mastered &&
        before.status != MasteryStatus.mastered;
    if (justMastered) _noteMastered(item);
    final srs = outcome?.srs;
    _spent += entry.costSeconds;
    _plan = next;
    await _saveDay(nextIndex);
    if (!mounted) return;
    setState(() {
      _grade = grade;
      _lost = outcome == null;
      _justMastered = justMastered;
      _regained = justMastered && before.status == MasteryStatus.shaky;
      _reasked = reasked;
      _interval = srs == null ? null : srs.dueDay - localDay(now);
      _index = nextIndex;
      _phase = _Phase.verdict;
    });
  }

  Future<void> _saveDay(int position, {bool completed = false}) async {
    _completed = _completed || completed;
    try {
      await widget.store.putDay(DayRecord(
          day: _plan.day,
          plan: _plan.encode(),
          position: position,
          completed: _completed));
    } catch (e, s) {
      FlutterError.reportError(FlutterErrorDetails(
          exception: e,
          stack: s,
          library: 'quiet room session',
          context: ErrorDescription('while saving the day ${_plan.day}')));
    }
  }

  Future<void> _finish(SessionEnd end) async {
    await _saveDay(_index, completed: true);
    final today = _plan.day;
    final done = <DateTime>[];
    for (var d = today - kEndCardDots + 1; d <= today; d++) {
      final record = await widget.store.day(d);
      if (record != null && record.completed) done.add(dateOfDay(d));
    }
    if (!mounted) return;
    setState(() {
      _end = end;
      _stopAt = null;
      _dots = recentDays(done, today: dateOfDay(today), length: kEndCardDots);
      _phase = _Phase.end;
    });
  }

  /// Runs [go] for a tap on the card of [from], after leaving that card for loading. A tap
  /// while the card is up but its first tap still runs (a double tap inside one store
  /// write) finds the phase gone and does nothing, so no action runs twice. `_onAnswer`
  /// holds the same rule for the probe (asking to saving).
  void _tap(_Phase from, void Function() go) {
    if (_phase != from) return;
    setState(() => _phase = _Phase.loading);
    go();
  }

  void _keepGoing(_Phase from) => _tap(from, _next);

  void _stop() => _tap(_Phase.softStop, () => _finish(SessionEnd.stopped));

  /// The planned entries left after the end, and whether the ceiling leaves room for one.
  bool get _oneMoreFits =>
      _index < _plan.entries.length &&
      _spent + _plan.entries[_index].costSeconds <= _ceiling;

  bool get _catchUpOffered =>
      _plan.catchUpOffer &&
      _plan.catchUpEntries.isNotEmpty &&
      !_anyPlanned(_plan.catchUpEntries) &&
      (_end == SessionEnd.ceiling || _end == SessionEnd.finished);

  bool get _stretchOffered =>
      _plan.stretchOffer &&
      _plan.stretchEntries.isNotEmpty &&
      !_anyPlanned(_plan.stretchEntries) &&
      _index >= _plan.entries.length &&
      _spent + _sumCost(_plan.stretchEntries) <= _ceiling;

  void _oneMore() => _tap(_Phase.end, () {
        _stopAt = _index + kOneMoreBlock;
        _next();
      });

  /// Puts [more] next, skipping items already planned, and runs them. With [only], the
  /// session ends again after them. Called from a `_tap`, so the phase is already loading.
  Future<void> _insert(List<QueueEntry> more, {bool only = false}) async {
    final add = _unplanned(more);
    _plan = DayPlan.fromJson({
      ..._plan.toJson(),
      'entries': [
        for (final e in _plan.entries.take(_index)) e.toJson(),
        for (final e in add) e.toJson(),
        for (final e in _plan.entries.skip(_index)) e.toJson(),
      ],
    });
    _stopAt = only ? _index + add.length : null;
    await _saveDay(_index);
    if (!mounted) return;
    await _next();
  }

  /// The opt-in block past the ceiling (PIN-12): the ceiling moves by the cost of the entries
  /// the block adds, from where the session stands, and the session ends again after them.
  void _catchUp() => _tap(_Phase.end, () {
        final block = _unplanned(_plan.catchUpEntries);
        _liftCeiling(spent: _spent, block: block);
        _insert(block, only: true);
      });

  /// The "4 more new" stretch (PIN-6), inside the ceiling.
  void _stretch() => _tap(_Phase.end, () => _insert(_plan.stretchEntries));

  void _close() {
    final onClose = widget.onClose;
    if (onClose != null) {
      onClose();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = QuietRoomTokens.of(context);
    final Widget body = switch (_phase) {
      _Phase.loading =>
        const Center(child: CircularProgressIndicator.adaptive()),
      _Phase.asking || _Phase.saving => _asking(context, t),
      _Phase.verdict => _verdictCard(t),
      _Phase.softStop => _softStopCard(t),
      _Phase.end => _endCard(t),
    };
    return ColoredBox(
      color: t.canvas,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: QuietRoomMetrics.readMax),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(QuietRoomMetrics.space16),
              child: body,
            ),
          ),
        ),
      ),
    );
  }

  Widget _asking(BuildContext context, QuietRoomTokens t) {
    final item = widget.catalog.byId(_entry.itemId)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(sectionPosition(_plan, _index),
            style: qrText(t,
                size: 13, weight: FontWeight.w600, color: t.inkMuted)),
        const SizedBox(height: QuietRoomMetrics.space8),
        KeyedSubtree(
          key: ValueKey('session-probe-$_presentation'),
          child: _builder!(
            context,
            SessionProbeRequest(
              item: item,
              state: _state ?? MasteryState.initial(item.id),
              answered: _answered,
              onAnswer: _onAnswer,
            ),
          ),
        ),
      ],
    );
  }

  Widget _card(QuietRoomTokens t, List<Widget> children) => Container(
        padding: const EdgeInsets.all(QuietRoomMetrics.space24),
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: t.border),
          borderRadius: BorderRadius.circular(QuietRoomMetrics.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      );

  Widget _title(QuietRoomTokens t, String text, {Color? color}) => Padding(
        padding: const EdgeInsets.only(bottom: QuietRoomMetrics.space8),
        child: Text(text,
            style: qrText(t,
                size: 22,
                weight: FontWeight.w600,
                color: color ?? t.inkStrong)),
      );

  Widget _line(QuietRoomTokens t, String text) => Padding(
        padding: const EdgeInsets.only(bottom: QuietRoomMetrics.space8),
        child: Text(text, style: qrText(t, size: 15, color: t.ink)),
      );

  Widget _action(QuietRoomTokens t, String label, VoidCallback onPressed,
          {bool primary = false}) =>
      Padding(
        padding: const EdgeInsets.only(top: QuietRoomMetrics.space8),
        child: SizedBox(
          height: QuietRoomMetrics.targetMin,
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              backgroundColor: primary ? t.brand600 : t.surface,
              side: BorderSide(color: primary ? t.brand600 : t.borderControl),
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(QuietRoomMetrics.radiusSm)),
            ),
            child: Text(label,
                style: qrText(t,
                    size: 15,
                    weight: FontWeight.w600,
                    color: primary ? t.onBrand : t.ink)),
          ),
        ),
      );

  Widget _verdictCard(QuietRoomTokens t) {
    final grade = _grade!;
    final List<Widget> lines;
    if (_lost) {
      lines = [_title(t, kAnswerNotSaved), _line(t, 'It stays in the queue.')];
    } else if (_justMastered) {
      lines = [
        _title(t, 'Mastered', color: t.sage700),
        _line(
            t,
            _regained
                ? 'Back to mastered. It still comes back to keep it sharp.'
                : 'Four clears over time. It still comes back to keep it sharp.'),
      ];
    } else {
      lines = switch (grade) {
        Grade.clear => [
            _title(t, 'Clear', color: t.sage700),
            if (_interval != null)
              _line(t, 'Next review in ${_days(_interval!)}.'),
          ],
        Grade.hinted => [
            _title(t, 'Right with a hint'),
            _line(t, 'No credit this time.'),
          ],
        Grade.self => [
            _title(t, 'Marked as got it'),
            _line(t, 'No credit this time.'),
          ],
        Grade.wrong => [
            _title(t, 'Not this time'),
            _line(
                t,
                _reasked
                    ? 'It comes back in about 10 minutes, and again tomorrow.'
                    : 'It comes back tomorrow.'),
          ],
        Grade.unscored => [
            _title(t, 'Not counted'),
            _line(t, 'It comes back later in this part.'),
          ],
      };
    }
    return _card(t, [
      ...lines,
      _action(t, 'Next', () => _keepGoing(_Phase.verdict), primary: true),
    ]);
  }

  Widget _softStopCard(QuietRoomTokens t) => _card(t, [
        _title(t, 'About ${_plan.targetSeconds ~/ 60} minutes'),
        _line(t, 'That is today\'s target. You can stop here, or keep going.'),
        _action(t, 'Stop', _stop),
        _action(t, 'Keep going', () => _keepGoing(_Phase.softStop),
            primary: true),
      ]);

  Widget _endCard(QuietRoomTokens t) {
    final answered = _counts.values.fold<int>(0, (s, n) => s + n);
    final clear = _counts[Grade.clear] ?? 0;
    final hinted = (_counts[Grade.hinted] ?? 0) + (_counts[Grade.self] ?? 0);
    final wrong = _counts[Grade.wrong] ?? 0;
    final kept = _dots.where((k) => k).length;
    final left = _plan.entries.length - _index;
    return _card(t, [
      _title(
          t,
          _end == SessionEnd.ceiling
              ? "That is today's ${_plan.ceilingSeconds ~/ 60} minutes"
              : 'Done for today'),
      if (_end == SessionEnd.ceiling && left > 0)
        _line(t, 'The rest is due tomorrow.'),
      _line(t,
          '$answered answered · $clear clear · $hinted with help · $wrong not this time'),
      if (_masteredToday.isNotEmpty) ...[
        _line(t, 'Mastered today'),
        for (final title in _masteredToday) _line(t, title),
      ],
      Padding(
        padding: const EdgeInsets.symmetric(vertical: QuietRoomMetrics.space8),
        child: Row(children: [
          for (final k in _dots)
            Padding(
              padding: const EdgeInsets.only(right: 5),
              child: Container(
                width: k ? 9 : 5,
                height: k ? 9 : 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: k ? t.sage600 : t.border,
                ),
              ),
            ),
          const SizedBox(width: 6),
          Text('$kept of $kEndCardDots days',
              style: qrText(t, size: 12.5, color: t.inkMuted)),
        ]),
      ),
      if (_oneMoreFits) _action(t, 'One more (10)', _oneMore),
      if (_catchUpOffered) _action(t, 'Catch up: 10 more', _catchUp),
      if (_stretchOffered) _action(t, '4 more new', _stretch),
      _action(t, 'Done', _close, primary: true),
    ]);
  }
}
