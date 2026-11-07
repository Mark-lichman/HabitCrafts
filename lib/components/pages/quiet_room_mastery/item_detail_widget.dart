// HAND-WRITTEN. Not FlutterFlow output, so S3 has nothing to adopt.
//
// The item page (plan 2026-11-02, Task 24, End state 9). One mastery item, read from its own
// attempts only (PIN-1):
//   * the state pill, "<n> of 4 clears" (D16, probe_widgets.dart `probeStateLabel`), and the
//     next review day (the FSRS due day, else the seeded one; an item with neither is not in
//     the queue yet);
//   * the probes seen clear: the scored probes with at least one clear answer;
//   * what remains to Mastered (the four clears, the 21-day final gap, the second question kind,
//     the production clear, each mode still missing a clear ([kModeLines], plan 2026-11-06,
//     Task 7, PIN-7) and the transfer clause, as mastery_rule.dart counts them), or to regain a
//     Shaky item;
//   * the Say-it counts on a grammar point, which never count toward Mastered (D4); on a word,
//     the practice screen's listens sit under their own heading, "Practice listens, not
//     counted", so they never read as the counting Say the word card (plan 2026-11-06, ASK-4);
//   * "no production probe yet" where the item has no production probe (A8), and "one question
//     kind only" where its scored probes share one template (PIN-15), from [itemNotesOf];
//   * the attempt history, newest first: date, grade (a wrong reads Missed, ASK-9), hint level,
//     probe, and whether the answer counted toward the four clears (or the regain);
//   * the "Discuss with Mari" toggle (discuss_list_widget.dart, PIN-6), which sets or clears
//     the item's Discuss mark and writes nothing else;
//   * Practice now, a one-item [PracticeSessionWidget].
//
// [itemDetailOf] is the pure read the page shows; the state is `masteryFromAttempts` over the
// item's attempts, never the lesson number.
//
// [PracticeSessionWidget] asks each of its items once through the session's probe builder and
// writes the answers through an [AttemptRecorder], so the due rule is the drills' (D23, PIN-14):
// an item whose due day has arrived is answered as a `review`; any other item, a New one
// included, as `early`, where a clear, a hinted or a self answer changes nothing and a wrong
// counts (due tomorrow, the count reset). It never writes the day's `DayRecord`, so practice
// never moves today's session. It follows the session's wrong-answer rule (operator ruling
// 2026-11-05, ASK-9): a wrong shows no result card. When the answer was already on screen
// (`DrillAnswer.answerShown`), practice moves straight on; else the probe stays, showing the
// answer, under one Next. The topic page (Task 23) runs it over a topic's items. Every
// unanswered card carries "Review the lesson" under the session's rule (plan 2026-11-06,
// Task 2, PIN-5): a clear after a review is written hinted. Every card also carries the
// Discuss toggle, as the Review session's cards do; a mark leaves the grade as it was (PIN-6).
// A spoken answer scores through Azure as in the Review session (plan 2026-11-06, Task 5,
// PIN-2): practice hands one [PronunciationService] to the probe builder, built with
// `PronunciationService.counting()` and disposed with it when none is injected.
//
// [openItemDetail] opens the page from any list (the study record page's rows, Topics, a topic
// page, a lesson page, the Discuss with Mari list).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '/flutter_flow/quiet_room.dart';
import '../quiet_room_grammar/jp_study_kit.dart';
import '../quiet_room_practice/pronunciation_service.dart';
import 'attempt.dart';
import 'discuss_list_widget.dart' show DiscussToggle;
import 'drill_recorder.dart';
import 'fsrs.dart';
import 'item_catalog.dart';
import 'jp_store.dart';
import 'jp_store_sqlite.dart' show sharedJpStore;
import 'local_day.dart';
import 'mastery_debug_widget.dart' show dueLabel;
import 'mastery_rule.dart';
import 'probe_widgets.dart';
import 'review_page.dart' show QrLoudButton, qrLoadingOr;
import 'scheduler.dart';
import 'session_widget.dart';

/// The loud action of the page.
const String kPracticeNow = 'Practice now';

/// The line on an item with no production probe (A8).
const String kNoProductionProbeLine = 'No production probe yet.';

/// The line on an item whose scored probes share one template (PIN-15). It drops only the
/// second-kind clause: the transfer clause (different verbs or cells) still binds and shows
/// under Still to do.
const String kOneTemplateLine =
    'One question kind only, so no second kind is needed.';

/// The next-review line of an item with no schedule and no seed.
const String kNotQueuedLine =
    'Not in the queue yet. It arrives with the daily new items.';

/// The history of an item never answered.
const String kNoAnswersLine = 'No answers yet.';

/// What remains of a Mastered item.
const String kMasteredRemains =
    'Nothing. It still comes back to keep it sharp.';

/// The template and production clauses of what remains (D4 clause 4).
const String kNeedSecondKindLine = 'a clear on a second question kind';
const String kNeedProductionLine =
    'a clear where you produce the answer (typed or spoken)';

/// The line for each mode the item still needs a clear in (plan 2026-11-06, Task 7, PIN-7,
/// D18), named the way the cards ask: type it, see it, say it.
const Map<ProbeMode, String> kModeLines = {
  ProbeMode.typed: 'a clear where you type it',
  ProbeMode.recognition: 'a clear where you see it and pick or recall it',
  ProbeMode.spoken: 'a clear where you say it',
};

/// Under the Say-it counts, on a grammar point only.
const String kSayItNeverCounts = 'Saying it never counts toward mastered.';

/// The heading over a word's practice-screen listens (`Source.sayIt`), which never count
/// (ASK-4, operator ruling 2026-11-06).
const String kPracticeListensHeading = 'Practice listens, not counted';

/// The practice verdict on an early clear, hinted or self answer (PIN-14).
const String kEarlyNoChange = 'Not due yet, so this practice changes nothing.';

/// One row of the attempt history.
class HistoryRow {
  const HistoryRow({required this.attempt, required this.counted});

  final Attempt attempt;

  /// Whether the answer added a clear toward Mastered or toward the regain.
  final bool counted;
}

/// What the item page shows, read from the item's own attempts.
class ItemDetail {
  const ItemDetail({
    required this.item,
    required this.state,
    required this.dueDay,
    required this.seenClear,
    required this.remaining,
    required this.sayItTries,
    required this.sayItClear,
    required this.history,
  });

  final ItemDef item;
  final MasteryState state;

  /// The FSRS due day, else the seeded due day; null for neither.
  final int? dueDay;

  /// The ids of the scored probes with a clear answer.
  final Set<String> seenClear;
  final List<String> remaining;
  final int sayItTries;
  final int sayItClear;

  /// Newest first.
  final List<HistoryRow> history;
}

String _n(int n, String one, [String? many]) =>
    '$n ${n == 1 ? one : (many ?? '${one}s')}';

/// The probe word of [kind] for the transfer clause.
String _probeWord(ItemKind kind) => switch (kind) {
      ItemKind.grammar => 'sentence',
      ItemKind.conjugation => 'verb',
      ItemKind.pair => 'direction',
      ItemKind.tableRow => 'cell',
      _ => 'question',
    };

/// What [item] still needs, given its [state] (D4, D16). Pure.
List<String> remainingFor(ItemDef item, MasteryState state) {
  switch (state.status) {
    case MasteryStatus.mastered:
      return const [kMasteredRemains];
    case MasteryStatus.shaky:
      final left = kRegainClears - state.clears.length;
      final n = left < 1 ? 1 : left;
      return [
        '${_n(n, 'more clear')} while due, at least $kRegainGapDays days after the first'
      ];
    case MasteryStatus.neu:
    case MasteryStatus.learning:
      final clears = state.clears;
      final left = kClearsToMaster - clears.length;
      final out = <String>[
        if (left > 0)
          '${_n(left, 'more clear')} while due, each on a different day',
        'the last at least $kFinalGapDays days after the review before it',
      ];
      if (item.templateCount >= kTemplatesNeeded) {
        if ({for (final c in clears) c.template}.length < kTemplatesNeeded) {
          out.add(kNeedSecondKindLine);
        }
        if (item.hasProductionProbe && !clears.any((c) => c.production)) {
          out.add(kNeedProductionLine);
        }
      }
      for (final mode in missingModes(item, clears)) {
        out.add(kModeLines[mode]!);
      }
      final need = transferProbesNeeded(item);
      final have = {for (final c in clears) transferKeyOf(c.probeId)}.length;
      if (have < need) {
        out.add(
            'clears on ${_n(need - have, 'more different ${_probeWord(item.kind)}')}');
      }
      return out;
  }
}

/// The notes under the next-review line: [kNoProductionProbeLine] where [item] has no
/// production probe (A8) and [kOneTemplateLine] where its scored probes share one template
/// (PIN-15). Every shipped kind has a say card (plan 2026-11-06, Task 6), so neither shows on
/// the shipped catalog today. Pure.
List<String> itemNotesOf(ItemDefLike item) => [
      if (!item.hasProductionProbe) kNoProductionProbeLine,
      if (item.templateCount == 1) kOneTemplateLine,
    ];

/// The item page's read of [item] from its [attempts], oldest first (PIN-1). Pure.
ItemDetail itemDetailOf(ItemDef item, List<Attempt> attempts, {int? dueDay}) {
  final scored = {for (final p in item.scoredProbes) p.id};
  var state = MasteryState.initial(item.id);
  final rows = <HistoryRow>[];
  final seen = <String>{};
  var tries = 0, sayClear = 0;
  for (final a in attempts) {
    if (a.itemId != item.id) continue;
    final next = masteryAfter(state, a, item);
    final counted = next.clears.length > state.clears.length ||
        (next.status == MasteryStatus.mastered &&
            state.status != MasteryStatus.mastered);
    rows.add(HistoryRow(attempt: a, counted: counted));
    state = next;
    if (a.source == Source.sayIt) {
      if (a.grade != Grade.unscored) tries++;
      if (a.grade == Grade.clear) sayClear++;
    } else if (a.grade == Grade.clear && scored.contains(a.probeId)) {
      seen.add(a.probeId);
    }
  }
  return ItemDetail(
    item: item,
    state: state,
    dueDay: dueDay,
    seenClear: seen,
    remaining: remainingFor(item, state),
    sayItTries: tries,
    sayItClear: sayClear,
    history: rows.reversed.toList(),
  );
}

/// The learner-facing name of a probe: the question kind for a word; for another kind its
/// text, prefixed 'Say it: ' on a say card or 'Choose: ' on a particle's choose card, and
/// joined to the answer by an arrow on a pair direction.
String probeLabel(ItemDef item, String probeId) {
  ProbeDef? probe;
  for (final p in item.probes) {
    if (p.id == probeId) probe = p;
  }
  if (probe == null) return probeId;
  return switch (probe.template) {
    'card' => 'Recall card',
    'spoken' => 'Say the word',
    'typed' => 'Type the reading',
    kSayCardTemplate when item.kind == ItemKind.word =>
      'Say it from the picture',
    kSayCardTemplate => 'Say it: ${probe.text}',
    kPairToTransitive => '${probe.text} → ${probe.answer}',
    kPairToIntransitive => '${probe.text} → ${probe.answer}',
    // A particle's choose card shares its cloze's text, so it names its kind.
    'choose' when probe.id == kParticleChooseId => 'Choose: ${probe.text}',
    _ => probe.text.isEmpty ? probe.id : probe.text,
  };
}

String gradeLabel(Grade g) => switch (g) {
      Grade.clear => 'Clear',
      Grade.hinted => 'With a hint',
      Grade.wrong => 'Missed',
      Grade.unscored => 'Not scored',
      Grade.self => 'Marked as got it',
    };

/// Opens the item page over [itemId] from any list, and completes when it closes.
Future<void> openItemDetail(BuildContext context, String itemId,
    {JpStore? store,
    ItemCatalog? catalog,
    Clock clock = const SystemClock(),
    SessionProbeBuilder? probeBuilder}) {
  return Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => ItemDetailWidget(
      itemId: itemId,
      store: store,
      catalog: catalog,
      clock: clock,
      probeBuilder: probeBuilder,
    ),
  ));
}

class ItemDetailWidget extends StatefulWidget {
  const ItemDetailWidget({
    super.key,
    required this.itemId,
    this.store,
    this.catalog,
    this.clock = const SystemClock(),
    this.probeBuilder,
  });

  static String routeName = 'quietRoomItem';
  static String routePath = '/quietRoomItem';

  final String itemId;

  /// Null uses the app's one shared store (`sharedJpStore`).
  final JpStore? store;

  /// Null loads the shipped catalog.
  final ItemCatalog? catalog;
  final Clock clock;

  /// Null loads the session's [standardProbeBuilder] for Practice now.
  final SessionProbeBuilder? probeBuilder;

  @override
  State<ItemDetailWidget> createState() => _ItemDetailWidgetState();
}

class _ItemDetailWidgetState extends State<ItemDetailWidget> {
  JpStore? _store;
  ItemCatalog? _catalog;
  ItemDetail? _detail;
  Object? _error;

  /// Bumped per load, so a load for an item no longer shown is dropped.
  int _loads = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// A route that reuses this page for another item reads that item, never shows the old one.
  @override
  void didUpdateWidget(ItemDetailWidget old) {
    super.didUpdateWidget(old);
    if (old.itemId != widget.itemId ||
        old.store != widget.store ||
        old.catalog != widget.catalog) {
      _store = null;
      _catalog = null;
      _detail = null;
      _error = null;
      _load();
    }
  }

  Future<void> _load() async {
    final load = ++_loads;
    try {
      final store = _store ??= widget.store ?? await sharedJpStore();
      final catalog = _catalog ??= widget.catalog ?? await ItemCatalog.load();
      final item = catalog.byId(widget.itemId);
      if (item == null) {
        throw StateError('no item ${widget.itemId} in the catalog');
      }
      final attempts = await store.attempts(itemId: item.id);
      final due = (await store.srs(item.id))?.dueDay ??
          (await store.item(item.id))?.seedDueDay;
      if (mounted && load == _loads) {
        setState(() => _detail = itemDetailOf(item, attempts, dueDay: due));
      }
    } catch (e) {
      if (mounted && load == _loads) setState(() => _error = e);
    }
  }

  Future<void> _practice() async {
    final d = _detail;
    if (d == null) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => QrStudyScaffold(
        child: PracticeSessionWidget(
          items: [d.item],
          store: _store!,
          catalog: _catalog!,
          clock: widget.clock,
          probeBuilder: widget.probeBuilder,
        ),
      ),
    ));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final d = _detail;
    if (d == null) {
      return QrStudyScaffold(
          child: qrLoadingOr(context, _error, 'Could not open the item:'));
    }
    final t = QuietRoomTokens.of(context);
    final item = d.item;
    final today = widget.clock.today();
    final scored = item.scoredProbes.toList();
    final hasSayIt = item.probes.any((p) => p.template == kSayItTemplate);
    return QrStudyScaffold(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        children: [
          Text(item.title, style: qrTitle(t, size: 28)),
          if (item.lesson != null) ...[
            const SizedBox(height: 4),
            Text('第${item.lesson}課',
                style: qrText(t, size: 13, color: t.inkMuted)),
          ],
          const SizedBox(height: 12),
          Align(
              alignment: Alignment.centerLeft,
              child: ProbeStatePill(state: d.state)),
          const SizedBox(height: 10),
          Text(
              d.dueDay == null
                  ? kNotQueuedLine
                  : 'Next review: ${dueLabel(d.dueDay!, today)}',
              style: qrText(t, size: 14, color: t.ink)),
          for (final note in itemNotesOf(item)) _note(t, note),
          // Keyed per load, so a return from practice reads a mark changed there.
          DiscussToggle(
              key: ValueKey('discuss-${item.id}-$_loads'),
              itemId: item.id,
              store: _store,
              clock: widget.clock),
          const SizedBox(height: 12),
          QrLoudButton(label: kPracticeNow, onPressed: _practice),
          _heading(t, 'Still to do'),
          for (final line in d.remaining) _line(t, line),
          _heading(t, 'Seen clear: ${d.seenClear.length} of ${scored.length}'),
          for (final p in scored)
            _line(t,
                '${d.seenClear.contains(p.id) ? '✓' : '·'} ${probeLabel(item, p.id)}'),
          // A word's practice listens never read as its counting Say the word card (plan
          // 2026-11-06, ASK-4).
          if (item.kind == ItemKind.word && d.sayItTries > 0) ...[
            _heading(t, kPracticeListensHeading),
            _line(t,
                '${_n(d.sayItTries, 'try', 'tries')} · ${d.sayItClear} clear'),
          ],
          if (item.kind == ItemKind.grammar &&
              (hasSayIt || d.sayItTries > 0)) ...[
            _heading(t,
                'Say it: ${_n(d.sayItTries, 'try', 'tries')} · ${d.sayItClear} clear'),
            _line(t, kSayItNeverCounts),
          ],
          _heading(t, 'History'),
          if (d.history.isEmpty) _line(t, kNoAnswersLine),
          for (final r in d.history) _historyRow(t, item, r),
        ],
      ),
    );
  }

  Widget _note(QuietRoomTokens t, String text) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(text, style: qrText(t, size: 13.5, color: t.inkMuted)),
      );

  Widget _heading(QuietRoomTokens t, String text) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 6),
        child: Text(text,
            style: qrText(t,
                size: 13, weight: FontWeight.w600, color: t.inkStrong)),
      );

  Widget _line(QuietRoomTokens t, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(text, style: qrText(t, size: 13.5, color: t.ink)),
      );

  Widget _historyRow(QuietRoomTokens t, ItemDef item, HistoryRow r) {
    final a = r.attempt;
    final what = [
      // A spoken close is hinted with no hint taken (PIN-10), so it reads Close, as on its
      // verdict card.
      a.spokenClose ? 'Close' : gradeLabel(a.grade),
      if (a.hintLevel > 0) 'hint ${a.hintLevel}',
      if (a.source == Source.early) 'early',
      if (a.source == Source.sayIt) 'say it',
      probeLabel(item, a.probeId),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 92,
          child: Text(DateFormat('EEE d MMM').format(dateOfDay(a.localDay)),
              style: qrText(t, size: 12.5, color: t.inkMuted)),
        ),
        Expanded(
            child: Text(what, style: qrText(t, size: 13, color: t.inkStrong))),
        Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Text(r.counted ? 'counted' : 'not counted',
              style: qrText(t,
                  size: 12.5, color: r.counted ? t.sage700 : t.inkMuted)),
        ),
      ]),
    );
  }
}

/// `held`: a wrong whose answer was not on screen; the probe stays, showing it, under Next.
enum _PracticePhase { loading, asking, saving, verdict, held, end }

/// Asks each of [items] once, in order, as practice outside the day's session (D23, PIN-14):
/// a due item is answered as a review, any other as early practice. See the file comment.
class PracticeSessionWidget extends StatefulWidget {
  const PracticeSessionWidget({
    super.key,
    required this.items,
    required this.store,
    required this.catalog,
    this.clock = const SystemClock(),
    this.probeBuilder,
    this.scheduler = const FsrsScheduler(),
    this.onClose,
    this.openLesson,
    this.pronunciation,
  });

  final List<ItemDef> items;
  final JpStore store;
  final ItemCatalog catalog;
  final Clock clock;

  /// Null loads [standardProbeBuilder] over the shipped grammar.
  final SessionProbeBuilder? probeBuilder;
  final Scheduler scheduler;

  /// Called by Done; null pops the route.
  final VoidCallback? onClose;

  /// Opens a card's lesson for "Review the lesson"; null uses `lessonOpenerFor`.
  final LessonOpener? openLesson;

  /// Scores the spoken answers of [standardProbeBuilder] (PIN-2). The caller owns an injected
  /// one. Null builds `PronunciationService.counting()` when practice loads its own builder,
  /// and practice disposes it.
  final PronunciationService? pronunciation;

  @override
  State<PracticeSessionWidget> createState() => _PracticeSessionWidgetState();
}

class _PracticeSessionWidgetState extends State<PracticeSessionWidget> {
  late final AttemptRecorder _recorder;
  late final List<ItemDef> _items;
  SessionProbeBuilder? _builder;

  /// The service this practice built for itself, disposed with it; null when injected.
  PronunciationService? _ownPronunciation;
  _PracticePhase _phase = _PracticePhase.loading;
  int _index = 0;
  int _presentation = 0;
  MasteryState? _state;
  int _answered = 0;

  /// The presentation whose lesson was opened before its answer (PIN-5): its clear is hinted.
  int? _reviewedPresentation;

  // The verdict on screen. A spoken close is `_written.spokenClose` (PIN-10).
  Attempt? _written;
  bool _lost = false;
  bool _justMastered = false;
  int? _interval;

  /// The probe held on screen after a wrong.
  ItemDef? _heldItem;

  @override
  void initState() {
    super.initState();
    _items = [
      for (final i in widget.items)
        if (i.scoredProbes.isNotEmpty) i
    ];
    _recorder = AttemptRecorder(
      store: () async => widget.store,
      items: () async => widget.catalog.byId,
      scheduler: widget.scheduler,
      clock: widget.clock,
      sessionId:
          'practice-${widget.clock.now().toUtc().microsecondsSinceEpoch}',
    );
    _start();
  }

  Future<void> _start() async {
    final grammar =
        widget.probeBuilder == null ? await JpGrammarData.load() : null;
    if (!mounted) return;
    _builder = widget.probeBuilder ??
        standardProbeBuilder(
            grammar: grammar!,
            pronunciation: widget.pronunciation ??
                (_ownPronunciation = PronunciationService.counting()));
    await _show();
  }

  @override
  void dispose() {
    // Only a service this practice built is its to free; its dispose cancels a check still
    // running and releases the recorder.
    final own = _ownPronunciation;
    if (own != null) unawaited(own.dispose());
    super.dispose();
  }

  Future<void> _show() async {
    if (_index >= _items.length) {
      if (mounted) setState(() => _phase = _PracticePhase.end);
      return;
    }
    final item = _items[_index];
    final state =
        await widget.store.mastery(item.id) ?? MasteryState.initial(item.id);
    final answered = (await widget.store.attempts(itemId: item.id)).length;
    if (!mounted) return;
    setState(() {
      _state = state;
      _answered = answered;
      _presentation++;
      _phase = _PracticePhase.asking;
    });
  }

  /// Opens the lesson of the card on screen and marks the card reviewed before the push, as
  /// the Review session does. The card stays mounted underneath. If the opener fails, no
  /// lesson was seen, so the mark goes back to what it was.
  Future<void> _reviewLesson(LessonOpener open, ItemDef item) async {
    if (_phase != _PracticePhase.asking) return;
    final before = _reviewedPresentation;
    setState(() => _reviewedPresentation = _presentation);
    try {
      await open(context, item);
    } catch (e, s) {
      if (mounted) setState(() => _reviewedPresentation = before);
      FlutterError.reportError(FlutterErrorDetails(
          exception: e,
          stack: s,
          library: 'quiet room practice',
          context: ErrorDescription('while opening the lesson of ${item.id}')));
    }
  }

  Future<void> _onAnswer(DrillAnswer answer) async {
    if (_phase != _PracticePhase.asking) return;
    // A lesson review before the answer makes a clear hinted (PIN-5).
    final d = _reviewedPresentation == _presentation
        ? afterLessonReview(answer)
        : answer;
    final item = _items[_index];
    final before = _state ?? MasteryState.initial(item.id);
    setState(() => _phase = _PracticePhase.saving);
    final written = await _recorder.record(d);
    MasteryState? after;
    int? interval;
    if (written != null) {
      after = await widget.store.mastery(item.id);
      final srs = await widget.store.srs(item.id);
      if (srs != null && written.source != Source.early) {
        interval = srs.dueDay - written.localDay;
      }
    }
    if (!mounted) return;
    // A saved wrong shows no card (ASK-9): straight on when the answer was already on
    // screen, else the probe stays with the answer under one Next.
    final wrong = written != null && written.grade == Grade.wrong;
    final moveOn = wrong && d.answerShown;
    final hold = wrong && !d.answerShown;
    setState(() {
      _written = written;
      _lost = written == null;
      _justMastered = after != null &&
          after.status == MasteryStatus.mastered &&
          before.status != MasteryStatus.mastered;
      _interval = interval;
      _heldItem = hold ? item : null;
      _index++;
      _phase = moveOn
          ? _PracticePhase.loading
          : hold
              ? _PracticePhase.held
              : _PracticePhase.verdict;
    });
    if (moveOn) await _show();
  }

  void _next() {
    if (_phase != _PracticePhase.verdict && _phase != _PracticePhase.held) {
      return;
    }
    setState(() => _phase = _PracticePhase.loading);
    _show();
  }

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
      _PracticePhase.loading =>
        const Center(child: CircularProgressIndicator.adaptive()),
      _PracticePhase.asking || _PracticePhase.saving => _asking(context, t),
      _PracticePhase.held => _asking(context, t, held: true),
      _PracticePhase.verdict => _verdictCard(t),
      _PracticePhase.end => _card(t, [
          _title(t, 'Practice done'),
          _action(t, 'Done', _close, primary: true),
        ]),
    };
    return SingleChildScrollView(
      padding: const EdgeInsets.all(QuietRoomMetrics.space16),
      child: body,
    );
  }

  /// The item's probe. [held] keeps the answered probe on screen, in the same place in the
  /// tree so it keeps its state (the answer it shows), and adds one Next under it. `_index`
  /// already moved past a held item (`_onAnswer`), so the header counts the held item at
  /// `_index`, the asked one at `_index + 1`.
  Widget _asking(BuildContext context, QuietRoomTokens t, {bool held = false}) {
    final item = held ? _heldItem! : _items[_index];
    final position = held ? _index : _index + 1;
    final open = held || _phase != _PracticePhase.asking
        ? null
        : lessonOpenerFor(context, widget.openLesson);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
            _items.length == 1
                ? 'Practice'
                : 'Practice · $position of ${_items.length}',
            style: qrText(t,
                size: 13, weight: FontWeight.w600, color: t.inkMuted)),
        const SizedBox(height: QuietRoomMetrics.space8),
        KeyedSubtree(
          key: ValueKey('practice-probe-$_presentation'),
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
        if (open != null)
          ReviewLessonLink(
            item: item,
            reviewed: _reviewedPresentation == _presentation,
            onTap: () => _reviewLesson(open, item),
          ),
        // Keyed: the lesson link above leaves the card on the held phase, and an unkeyed
        // toggle would be rebuilt by position and read the store again.
        DiscussToggle(
            key: ValueKey('discuss-${item.id}'),
            itemId: item.id,
            store: widget.store,
            clock: widget.clock),
        if (held) _action(t, 'Next', _next, primary: true),
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
    final last = _index >= _items.length;
    final List<Widget> lines;
    final w = _written;
    if (_lost || w == null) {
      lines = [_title(t, kAnswerNotSaved)];
    } else if (_justMastered) {
      lines = [
        _title(t, 'Mastered', color: t.sage700),
        _line(t, 'It still comes back to keep it sharp.'),
      ];
    } else {
      final early = w.source == Source.early;
      lines = switch (w.grade) {
        Grade.clear => [
            _title(t, 'Clear', color: t.sage700),
            if (early) _line(t, kEarlyNoChange),
            if (!early && _interval != null)
              _line(t,
                  'Next review in ${_interval == 1 ? '1 day' : '$_interval days'}.'),
          ],
        Grade.hinted => [
            _title(t, w.spokenClose ? 'Close' : 'Right with a hint'),
            _line(t, 'No credit this time.'),
          ],
        Grade.self => [
            _title(t, 'Marked as got it'),
            _line(t, 'No credit this time.'),
          ],
        // Never shown: a saved wrong moves on or holds its probe (`_onAnswer`, ASK-9).
        Grade.wrong => [_title(t, 'Missed')],
        Grade.unscored => [
            _title(t, 'Not counted'),
            _line(t, 'Nothing was scored.'),
          ],
      };
    }
    return _card(t, [
      ...lines,
      if (last)
        _action(t, 'Done', _close, primary: true)
      else
        _action(t, 'Next', _next, primary: true),
    ]);
  }
}
